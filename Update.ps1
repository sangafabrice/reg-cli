[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Tor",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\firefox.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = $(
        Try {
            $UriBase = 'https://dist.torproject.org/torbrowser'
            (Invoke-WebRequest $UriBase -Verbose:$False).Links.href |
            Where-Object { $_ -match '(\d+\.)+\d+/$' } |
            Select-Object @{Name = 'Version'; Expression = { [version] ($_ -replace '/$') }},@{Name = 'Path'; Expression = { $_ }} |
            Sort-Object -Descending -Property Version|
            Select-Object @{
                Name = 'Link'
                Expression = {
                    $UriBase = "$UriBase/$($_.Path)"
                    $Culture = Get-Culture
                    $Lang = $Culture.TwoLetterISOLanguageName
                    $OSArch = $(Switch (Get-ExecutableType $NameLocation) { 'x64' { 'win64-' } 'x86' { '' } })
                    $LangInstallers = (Invoke-WebRequest $UriBase -Verbose:$False).Links.href
                    $GroupInstaller = $LangInstallers | Where-Object { $_ -like "torbrowser-install-$OSArch*_$Lang*.exe" }
                    Switch ($GroupInstaller.Count) {
                        0 { $GroupInstaller = $LangInstallers | Where-Object { $_ -like "torbrowser-install-$OSArch*_en-US.exe" } }
                        { $_ -gt 1 } {
                            [void] ($Culture.Name -match '\-(?<Country>[A-Z]{2})$')
                            $TempLine = $GroupInstaller | Where-Object { $_ -like "torbrowser-install-$OSArch*_$Lang-$($Matches.Country).exe" }
                            If ([string]::IsNullOrEmpty($TempLine)) {
                                If ($Lang -ieq 'en') { $TempLine = $GroupInstaller | Where-Object { $_ -like "torbrowser-install-$OSArch*_en-US.exe" } }
                                Else { $TempLine = $GroupInstaller[0] }
                            }
                            $GroupInstaller = $TempLine
                        }
                    }
                    Return "$UriBase$GroupInstaller"
                }
            } -First 1 | Select-Object Link,@{
                Name = 'Version'
                Expression = { [datetime] "$((Invoke-WebRequest $_.Link -Method Head -Verbose:$False).Headers.'Last-Modified')" }
            }
        }
        Catch { }
    ) | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $InstallerDescription = 'CN="The Tor Project, Inc."'
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerLastModified $SaveTo $InstallerDescription -UseSignature }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription -UseSignature |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -UseSignature -Verbose:$VerbosePreferenceBool
        Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect 'tor' $NameLocation
        If (!(Test-InstallOutdated -CompareInstalls)) { Write-Verbose "Tor $(Get-ExecutableVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Tor browser software.
.DESCRIPTION
    The script installs or updates Tor browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Tor.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Tor -ErrorAction SilentlyContinue

    PS > .\UpdateTor.ps1 -InstallLocation C:\ProgramData\Tor -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Tor | Select-Object Name -First 5
    Name
    ----
    browser
    defaults
    fonts
    TorBrowser
    Accessible.tlb

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    2022.204.654.83.exe
    UpdateTor.ps1

    Install Tor browser to 'C:\ProgramData\Tor' and save its setup installer to the current directory.
#>
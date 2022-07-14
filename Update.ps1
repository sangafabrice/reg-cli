[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (& {
            Param($Path)
            $Pattern = '(?<Drive>^.+):'
            If ($Path -match $Pattern -or $PWD -match $Pattern) {
                Return $Matches.Drive -iin @((Get-PSDrive -PSProvider FileSystem).Name)
            }
            Return $False
        } $_) -and
        $(
            @{
                LiteralPath = $_
                ErrorAction = 'SilentlyContinue'
            } | ForEach-Object { Get-Item @_ }
        ).FullName -ine $PSScriptRoot
    })] [string]
    $InstallLocation = "${Env:ProgramData}\Firefox",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (Get-Item -LiteralPath $_).PSDrive.Name -iin 
        @((Get-PSDrive -PSProvider FileSystem).Name)
    })] [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\firefox.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        $(Try {
            $UriBase = 'https://releases.mozilla.org/pub/firefox/releases/'
            (Invoke-WebRequest $UriBase -Verbose:$False).Links.href |
            ForEach-Object {
                [void] ($_ -match '/(?<Version>[0-9\.]+)/$')
                [version] $Matches.Version
            } |
            Sort-Object -Descending |
            Select-Object @{
                Name = 'Link'
                Expression = {
                    $Culture = Get-Culture
                    $Lang = $Culture.TwoLetterISOLanguageName
                    $UriBase = "$UriBase$_"
                    $OSArch = $(Switch (Get-ExecutableType $NameLocation) { 'x64' { 'win64' } 'x86' { 'win32' } })
                    $LangInstallers = 
                        "$(Invoke-WebRequest "$UriBase/SHA512SUMS" -Verbose:$False)" -split "`n" |
                        ForEach-Object {
                            ,@($_ -split ' ',2) |
                            ForEach-Object {
                                [pscustomobject] @{
                                    Checksum = $_[0]
                                    Resource = "$($_[1])".Trim()
                                }
                            } |
                            Where-Object Resource -Like "$OSArch/*.exe"
                        }
                    $GroupInstaller = $LangInstallers | Where-Object Resource -Like "$OSArch/$Lang*.exe"
                    Switch ($GroupInstaller.Count) {
                        0 { $GroupInstaller = $LangInstallers | Where-Object Resource -Like "$OSArch/en-US/*" }
                        { $_ -gt 1 } {
                            [void] ($Culture.Name -match '\-(?<Country>[A-Z]{2})$')
                            $TempLine = $GroupInstaller | Where-Object Resource -Like "$OSArch/$Lang-$($Matches.Country)/*"
                            If ([string]::IsNullOrEmpty($TempLine)) {
                                If ($Lang -ieq 'en') { $TempLine = $GroupInstaller | Where-Object Resource -Like "$OSArch/en-US/*" }
                                Else { $TempLine = $GroupInstaller[0] }
                            }
                            $GroupInstaller = $TempLine
                        }
                    }
                    $GroupInstaller.Resource = "$UriBase/$($GroupInstaller.Resource)"
                    $GroupInstaller 
                } 
            },@{
                Name = 'Version'
                Expression = { $_ }
            } |
            Select-Object Version,@{
                Name = 'Link'
                Expression = { $_.Link.Resource }
            },@{
                Name = 'Checksum'
                Expression = { $_.Link.Checksum }
            } -First 1
        } Catch { }) |
        Where-Object {
            @($_.Version,$_.Link,$_.Checksum) |
            ForEach-Object { $_ -notin @($Null, '') }
        }
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Firefox'
    If ($UpdateInfo.Count -le 0) {
        $InstallerVersion = "$(
            Get-ChildItem $SaveTo |
            Select-Object VersionInfo -ExpandProperty VersionInfo |
            Where-Object { $_.FileDescription -ieq $SoftwareName } |
            ForEach-Object { [version] $_.ProductVersion } |
            Sort-Object -Descending |
            Select-Object -First 1
        )"
    }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $SoftwareName |
        Import-Module -Verbose:$False -Force
        If ($UpdateInfo.Count -gt 0) { Start-InstallerDownload $UpdateInfo.Link $UpdateInfo.Checksum -Verbose:$VerbosePreferenceBool }
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        If (Test-InstallOutdated) {
            Write-Verbose 'Current install is outdated or not installed...'
            Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation
        }
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect 'firefox' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $InstallerVersion installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Opera browser software.
.DESCRIPTION
    The script installs or updates Opera browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Opera.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Opera -ErrorAction SilentlyContinue

    PS > .\UpdateOpera.ps1 -InstallLocation C:\ProgramData\Opera -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Opera | Select-Object Name -First 5
    Name
    ----
    Assets
    localization
    MEIPreload
    resources
    89.0.4447.38.manifest

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    89.0.4447.38.exe
    UpdateOpera.ps1

    Install Opera browser to 'C:\ProgramData\Opera' and save its setup installer to the current directory.
#>
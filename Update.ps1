[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Firefox",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\firefox.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        Get-DownloadInfo -PropertyList @{ OSArch = (Get-ExecutableType $NameLocation) } -From FirefoxDev |
        Where-Object {
            @($_.Version,$_.Link,$_.Checksum) |
            ForEach-Object { $_ -notin @($Null, '') }
        }
    $InstallerVersion = $UpdateInfo.Version
    $InstallerDescription = 'Firefox'
    $SoftwareName = "$InstallerDescription Developer Edition"
    $UpdateInfoCountZero = $UpdateInfo.Count -le 0
    If ($UpdateInfoCountZero) {
        $InstallerVersion = "$((
            Get-ChildItem $SaveTo |
            Where-Object { $_.VersionInfo.FileDescription -ieq $InstallerDescription } |
            Get-AuthenticodeSignatureEx |
            Sort-Object -Descending -Property SigningTime |
            Select-Object -First 1
        ).SigningTime)"
    }
    Try {
        $GetExeVersion = { (Get-Item -LiteralPath $NameLocation -ErrorAction SilentlyContinue).VersionInfo.FileVersionRaw }
        $VersionPreInstall = & $GetExeVersion
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription -UseTimeStamp:$UpdateInfoCountZero |
        Import-Module -Verbose:$False -Force
        If ($UpdateInfo.Count -gt 0) { Start-InstallerDownload $UpdateInfo.Link $UpdateInfo.Checksum -Verbose:$VerbosePreferenceBool }
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect 'firefoxdev' $NameLocation
        $VersionPostInstall = & $GetExeVersion
        If ($VersionPostInstall -gt $VersionPreInstall) {
            $CurrentVersion = ("$(Get-InstallerVersion)" -replace '\.([0-9]+)$','b$1').Trim()
            If ([string]::IsNullOrEmpty($CurrentVersion)) { $CurrentVersion = $VersionPostInstall }
            Write-Verbose "$SoftwareName $CurrentVersion installation complete."
        }
    } 
    Catch { $_ }
}

<#
.SYNOPSIS
    Updates Mozilla Firefox Developer Edition browser software.
.DESCRIPTION
    The script installs or updates Mozilla Firefox Developer Edition browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\FirefoxDevEdition.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\FirefoxDevEdition -ErrorAction SilentlyContinue

    PS > .\UpdateFirefoxDevEdition.ps1 -InstallLocation C:\ProgramData\FirefoxDevEdition -SaveTo .

    PS > Get-ChildItem C:\ProgramData\FirefoxDevEdition | Select-Object Name -First 5
    Name
    ----
    browser
    defaults
    fonts
    gmp-clearkey
    uninstall

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    103.0.9.exe
    UpdateFirefoxDevEdition.ps1

    Install Mozilla Firefox Developer Edition browser to 'C:\ProgramData\FirefoxDevEdition' and save its setup installer to the current directory.
#>
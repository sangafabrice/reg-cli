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
        Get-DownloadInfo -PropertyList @{
            RepositoryId = 'firefox'
            OSArch = (Get-ExecutableType $NameLocation)
            VersionDelim = $Null
        } -From Mozilla | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Firefox'
    If (!$UpdateInfo) { $InstallerVersion = "$(Get-SavedInstallerPublishDate $SaveTo $SoftwareName)" }
    Try {
        $GetExeVersion = { (Get-Item -LiteralPath $NameLocation -ErrorAction SilentlyContinue).VersionInfo.FileVersionRaw }
        $VersionPreInstall = & $GetExeVersion
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $SoftwareName -UseTimeStamp:$(!$UpdateInfo) |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect 'firefox' $NameLocation
        $VersionPostInstall = & $GetExeVersion
        If ($VersionPostInstall -gt $VersionPreInstall) {
            Write-Verbose "$SoftwareName $((Get-InstallerVersion) ?? $VersionPostInstall) installation complete."
        }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Mozilla Firefox browser software.
.DESCRIPTION
    The script installs or updates Mozilla Firefox browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\MozillaFirefox.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\MozillaFirefox -ErrorAction SilentlyContinue

    PS > .\UpdateMozillaFirefox.ps1 -InstallLocation C:\ProgramData\MozillaFirefox -SaveTo .

    PS > Get-ChildItem C:\ProgramData\MozillaFirefox | Select-Object Name -First 5
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
    102.0.1.exe
    UpdateMozillaFirefox.ps1

    Install Mozilla Firefox browser to 'C:\ProgramData\MozillaFirefox' and save its setup installer to the current directory.
#>
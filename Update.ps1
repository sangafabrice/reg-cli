[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Opera",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\launcher.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        Get-DownloadInfo -PropertyList @{
            RepositoryID = 'opera/desktop'
            OSArch = (Get-ExecutableType $NameLocation)
            FormatedName = 'Opera'
        } -From Opera | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Opera'
    $InstallerDescription = "$SoftwareName Installer"
    If (!$UpdateInfo) { $InstallerVersion = "$(Get-SavedInstallerVersion $SaveTo $InstallerDescription)" }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect 'opera' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $(Get-InstallerVersion) installation complete." }
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
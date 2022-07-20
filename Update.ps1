[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Vivaldi",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $BaseNameLocation = "$InstallLocation\vivaldi"
    $NameLocation = "$BaseNameLocation.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        Get-DownloadInfo -PropertyList @{ OSArch = (Get-ExecutableType $NameLocation) } -From Vivaldi |
        Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Vivaldi'
    $InstallerDescription = "$SoftwareName Installer"
    If (!$UpdateInfo) { $InstallerVersion = "$(Get-SavedInstallerVersion $SaveTo $InstallerDescription)" }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-ChromiumVisualElementsManifest "$BaseNameLocation.VisualElementsManifest.xml" '#EF3939'
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect 'vivaldi' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $(Get-InstallerVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Vivaldi browser software.
.DESCRIPTION
    The script installs or updates Vivaldi browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Vivaldi.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Vivaldi -ErrorAction SilentlyContinue

    PS > .\UpdateVivaldi.ps1 -InstallLocation C:\ProgramData\Vivaldi -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Vivaldi | Select-Object Name
    Name
    ----
    5.3.2679.68
    update_notifier.exe
    vivaldi.exe
    vivaldi.VisualElementsManifest.xml
    vivaldi_proxy.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    5.3.2679.68.exe
    UpdateVivaldi.ps1

    Install Vivaldi browser to 'C:\ProgramData\Vivaldi' and save its setup installer to the current directory.
#>
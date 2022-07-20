[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Brave",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\brave.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        Get-DownloadInfo -PropertyList @{
            UpdateServiceURL = 'https://updates.bravesoftware.com/service/update2'
            ApplicationID    = '{AFE6A462-C574-4B8A-AF43-4CC60DF4563B}'
            ApplicationSpec  = "$(Get-ExecutableType $NameLocation)-rel"
            Protocol         = '3.0'
        } -From Omaha | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Brave'
    $InstallerDescription = "$SoftwareName Installer"
    If (!$UpdateInfo) { $InstallerVersion = "$(Get-SavedInstallerVersion $SaveTo $InstallerDescription)" }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-ChromiumVisualElementsManifest "$InstallLocation\chrome.VisualElementsManifest.xml" '#5F6368'
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect 'brave' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $(Get-InstallerVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Brave browser software.
.DESCRIPTION
    The script installs or updates Brave browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Brave.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Brave -ErrorAction SilentlyContinue

    PS > .\UpdateBrave.ps1 -InstallLocation C:\ProgramData\Brave -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Brave | Select-Object Name
    Name
    ----
    103.1.40.109
    brave.exe
    chrome_proxy.exe
    chrome.VisualElementsManifest.xml

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    103.1.40.109.exe
    UpdateBrave.ps1

    Install Brave browser to 'C:\ProgramData\Brave' and save its setup installer to the current directory.
#>
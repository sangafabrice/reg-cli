[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\YouTube Music Desktop",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\YouTube Music Desktop App.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        Get-DownloadInfo -PropertyList @{ 
            RepositoryId = 'ytmdesktop/ytmdesktop'
            AssetPattern = 'YouTube\-Music\-Desktop\-App\-Setup\-(\d+\.)+exe$' 
        } | Select-Object Version,@{
            Name = 'Link'
            Expression = { "$($_.Link.Url)" }
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $InstallerDescription = 'YouTube Music Desktop App'
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerVersion $SaveTo $InstallerDescription }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-NsisInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-NsisShortcut $NameLocation
        Set-BatchRedirect 'ytmdesktop' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$InstallerDescription $(Get-InstallerVersion) installation complete." }
    } 
    Catch { $_ }
}

<#
.SYNOPSIS
    Updates YouTube Music Desktop App software.
.DESCRIPTION
    The script installs or updates YouTube Music Desktop App on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\YouTube Music Desktop".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\YouTube Music Desktop' -ErrorAction SilentlyContinue

    PS > .\UpdateYouTubeMusicDesktop.ps1 -InstallLocation 'C:\ProgramData\YouTube Music Desktop' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\YouTube Music Desktop' | Select-Object Name -First 5
    Name
    ----
    locales
    resources
    swiftshader
    chrome_100_percent.pak
    chrome_200_percent.pak

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    v1.13.0.exe
    UpdateYouTubeMusicDesktop.ps1

    Install YouTube Music Desktop App to 'C:\ProgramData\YouTube Music Desktop' and save its setup installer to the current directory.
#>
[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\WordPress.com",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\WordPress.com.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        Get-DownloadInfo -PropertyList @{ 
            RepositoryId = 'Automattic/wp-desktop'
            AssetPattern = 'wordpress\.com\-win32\-setup\-(\d+\.)+exe$' 
        } | Select-Object Version,@{
            Name = 'Link'
            Expression = { "$($_.Link.Url)" }
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $InstallerDescription = 'Desktop version of WordPress.com'
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerVersion $SaveTo $InstallerDescription }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-NsisInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-NsisShortcut $NameLocation
        Set-BatchRedirect 'wordpresscom' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$InstallerDescription $(Get-InstallerVersion) installation complete." }
    } 
    Catch { $_ }
}

<#
.SYNOPSIS
    Updates WordPress.com software.
.DESCRIPTION
    The script installs or updates WordPress.com on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\WordPress.com".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\WordPress.com' -ErrorAction SilentlyContinue

    PS > .\UpdateWordPressCom.ps1 -InstallLocation 'C:\ProgramData\WordPress.com' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\WordPress.com' | Select-Object Name -First 5
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
    UpdateWordPressCom.ps1

    Install WordPress.com to 'C:\ProgramData\WordPress.com' and save its setup installer to the current directory.
#>
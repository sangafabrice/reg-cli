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
    $UpdateInfo =
        Try {
            Write-Verbose 'Retrieve install or update information...'
            Get-DownloadInfo -PropertyList @{ 
                RepositoryId = 'Automattic/wp-desktop'
                AssetPattern = 'wordpress\.com\-win32\-setup\-(\d+\.)+exe$' 
            }
        }
        Catch { }
    $InstallerDescription = 'Desktop version of WordPress.com'
    $LocalVersion = "$(Get-SavedInstallerVersion $SaveTo $InstallerDescription)"
    If (
        ![string]::IsNullOrEmpty($UpdateInfo.Version) -and
        $LocalVersion -like "$($UpdateInfo.Version -replace 'v')*"
    ) { $UpdateInfo.Version = $LocalVersion }
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $UpdateInfo
            NameLocation = "$InstallLocation\WordPress.com.exe"
            SaveTo = $SaveTo
            SoftwareName = 'WordPress.com'
            InstallerDescription = $InstallerDescription
            InstallerType = 'NSIS'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
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
    wordpress.com_v7.2.0.exe
    UpdateWordPressCom.ps1

    Install WordPress.com to 'C:\ProgramData\WordPress.com' and save its setup installer to the current directory.
#>
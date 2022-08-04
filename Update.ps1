[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Tabby",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Tabby.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
    $UpdateInfo = 
        Get-DownloadInfo -PropertyList @{
            RepositoryId = 'Eugeny/tabby'
            AssetPattern = "setup\-x64\.exe$"
        } | Select-Object Version,@{
            Name = 'Link'
            Expression = { $_.Link.Url }
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $InstallerDescription = 'A terminal for a modern age'
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerVersion $SaveTo $InstallerDescription }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-NsisInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-NsisShortcut $NameLocation
        Set-BatchRedirect 'Tabby' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "Tabby $(Get-InstallerVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Tabby software.
.DESCRIPTION
    The script installs or updates Tabby on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Tabby".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Tabby' -ErrorAction SilentlyContinue

    PS > .\UpdateTabby.ps1 -InstallLocation 'C:\ProgramData\Tabby' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Tabby' | Select-Object Name -First 5
    Name
    ----
    Tabbyes
    resources
    swiftshader
    chrome_100_percent.pak
    chrome_200_percent.pak

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    1.24.0.exe
    UpdateTabby.ps1

    Install Tabby to 'C:\ProgramData\Tabby' and save its setup installer to the current directory.
#>
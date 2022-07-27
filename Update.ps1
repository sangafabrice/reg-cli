[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Teams",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Teams.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        [uri] "$(Invoke-WebRequest "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=$(Get-ExecutableType $NameLocation)&download=false" -Verbose:$False)" |
        Select-Object @{
            Name = 'Version'
            Expression = { $_.Segments?[-2] -replace '/$' }
        },@{
            Name = 'Link'
            Expression = { "$_" }
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Microsoft Teams'
    If (!$UpdateInfo) { $InstallerVersion = "$(Get-SavedInstallerVersion $SaveTo $SoftwareName)" }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $SoftwareName |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-SquirrelInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-SquirrelShortcut $NameLocation
        Set-BatchRedirect 'teams' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $(Get-InstallerVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Microsoft Teams software.
.DESCRIPTION
    The script installs or updates Microsoft Teams on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Teams.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Teams -ErrorAction SilentlyContinue

    PS > .\UpdateTeams.ps1 -InstallLocation C:\ProgramData\Teams -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Teams | Select-Object Name -First 5
    Name
    ----
    locales
    resources
    swiftshader
    api-ms-win-core-console-l1-1-0.dll
    api-ms-win-core-console-l1-2-0.dll

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    1.5.00.17656.exe
    UpdateTeams.ps1

    Install Teams to 'C:\ProgramData\Teams' and save its setup installer to the current directory.
#>
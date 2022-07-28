[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\GitHub Desktop",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\GithubDesktop.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        @{
            Uri = 'https://central.github.com/deployments/desktop/desktop/latest/win32'
            Method = 'HEAD'
            MaximumRedirection = 0
            ErrorAction = 'SilentlyContinue'
            SkipHttpErrorCheck = $True
        } | ForEach-Object {
            [uri] "$((Invoke-WebRequest @_ -Verbose:$False).Headers.Location)"
        } |
        Select-Object @{
            Name = 'Version'
            Expression = { ($_.Segments?[-2] -replace '/$' -split '-')?[0] }
        },@{
            Name = 'Link'
            Expression = { "$_" }
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $InstallerDescription = 'Simple collaboration from your desktop'
    If (!$UpdateInfo) { $InstallerVersion = "$(Get-SavedInstallerVersion $SaveTo $InstallerDescription)" }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-SquirrelInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-SquirrelShortcut $NameLocation
        Set-BatchRedirect 'githubdesktop' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "Github Desktop $(Get-InstallerVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates GitHub Desktop software.
.DESCRIPTION
    The script installs or updates GitHub Desktop on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\GitHub Desktop".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\GitHub Desktop' -ErrorAction SilentlyContinue

    PS > .\UpdateGithubDesktop.ps1 -InstallLocation 'C:\ProgramData\GitHub Desktop' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\GitHub Desktop' | Select-Object Name -First 5
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
    3.0.5.exe
    UpdateGithubDesktop.ps1

    Install GitHub Desktop to 'C:\ProgramData\GitHub Desktop' and save its setup installer to the current directory.
#>
[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\SourceTree",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\SourceTree.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        (Invoke-WebRequest "https://www.sourcetreeapp.com/download-archives" -Verbose:$False).Links.href |
        Where-Object { $_ -like '*.exe' } |
        Select-Object @{
            Name = 'Version'
            Expression = {
                [void] ($_ -match '(?<Version>(\d+\.)+\d+)\.exe$')
                [version] $Matches.Version
            }
        },@{
            Name = 'Link'
            Expression = { $_ }
        } -First 1 | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $InstallerDescription = 'SourceTree'
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerVersion $SaveTo $InstallerDescription }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-SquirrelInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-SquirrelShortcut $NameLocation
        Set-BatchRedirect 'sourcetree' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$InstallerDescription $(Get-InstallerVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates SourceTree software.
.DESCRIPTION
    The script installs or updates SourceTree on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\SourceTree".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\SourceTree' -ErrorAction SilentlyContinue

    PS > .\UpdateSourceTree.ps1 -InstallLocation 'C:\ProgramData\SourceTree' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\SourceTree' | Select-Object Name -First 5
    Name
    ----
    locales
    resources
    SourceTree_ExecutionStub.exe
    SourceTree.exe
    chrome_100_percent.pak

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    v1.60.0.exe
    UpdateSourceTree.ps1

    Install SourceTree to 'C:\ProgramData\SourceTree' and save its setup installer to the current directory.
#>
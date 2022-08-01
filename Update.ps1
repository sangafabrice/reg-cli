[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Prepros",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Prepros.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        @{
            Uri = 'https://prepros.io/downloads/stable/windows'
            Method  = 'HEAD'
            MaximumRedirection = 0
            SkipHttpErrorCheck = $True
            ErrorAction = 'SilentlyContinue'
            Verbose = $False
        } | ForEach-Object { (Invoke-WebRequest @_).Headers.Location } |
        Select-Object @{
            Name = 'Version'
            Expression = { [version] (([uri] $_).Segments?[-2] -replace '/$') }
        },@{
            Name = 'Link'
            Expression = { $_ }
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $InstallerDescription = 'Prepros'
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerVersion $SaveTo $InstallerDescription }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-SquirrelInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-SquirrelShortcut $NameLocation
        Set-BatchRedirect 'prepros' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$InstallerDescription $(Get-InstallerVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Prepros software.
.DESCRIPTION
    The script installs or updates Prepros on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Prepros".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Prepros' -ErrorAction SilentlyContinue

    PS > .\UpdatePrepros.ps1 -InstallLocation 'C:\ProgramData\Prepros' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Prepros' | Select-Object Name -First 5
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
    7.6.0.exe
    UpdatePrepros.ps1

    Install Prepros to 'C:\ProgramData\Prepros' and save its setup installer to the current directory.
#>
[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\TuneIn",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\TuneIn.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        @{
            Uri = 'https://tunein.com/download/windows/'
            Method  = 'HEAD'
            MaximumRedirection = 0
            SkipHttpErrorCheck = $True
            ErrorAction = 'SilentlyContinue'
            Verbose = $False
        } | ForEach-Object { (Invoke-WebRequest @_).Headers.Location } |
        Select-Object @{
            Name = 'Version'
            Expression = {
                [void] ($_ -match '(?<Version>(\d+\.)+\d+)\.exe$')
                [version] $Matches.Version
            }
        },@{
            Name = 'Link'
            Expression = { $_ }
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $InstallerDescription = 'TuneIn Desktop app - an electron wrapper for tunein.com'
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerVersion $SaveTo $InstallerDescription }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-NsisInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-NsisShortcut $NameLocation
        Set-BatchRedirect 'TuneIn' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "TuneIn $(Get-InstallerVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates TuneIn software.
.DESCRIPTION
    The script installs or updates TuneIn on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\TuneIn".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\TuneIn' -ErrorAction SilentlyContinue

    PS > .\UpdateTuneIn.ps1 -InstallLocation 'C:\ProgramData\TuneIn' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\TuneIn' | Select-Object Name -First 5
    Name
    ----
    TuneInes
    resources
    swiftshader
    chrome_100_percent.pak
    chrome_200_percent.pak

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    1.24.0.exe
    UpdateTuneIn.ps1

    Install TuneIn to 'C:\ProgramData\TuneIn' and save its setup installer to the current directory.
#>
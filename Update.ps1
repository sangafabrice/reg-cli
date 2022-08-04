[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Local",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Local.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        @{
            Uri = 'https://cdn.localwp.com/stable/latest/windows'
            Method  = 'HEAD'
            MaximumRedirection = 0
            SkipHttpErrorCheck = $True
            ErrorAction = 'SilentlyContinue'
            Verbose = $False
        } | ForEach-Object { (Invoke-WebRequest @_).Headers.Location } |
        Select-Object @{
            Name = 'Version'
            Expression = { [version] (([uri] $_).Segments?[-2] -split '\+')?[0] }
        },@{
            Name = 'Link'
            Expression = { $_ }
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $InstallerDescription = 'Create local WordPress sites with ease.'
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerVersion $SaveTo $InstallerDescription }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-NsisInstaller (Get-InstallerPath) $NameLocation 32 -Verbose:$VerbosePreferenceBool
        Set-NsisShortcut $NameLocation
        Set-BatchRedirect 'local' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "Local $(Get-InstallerVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Local software.
.DESCRIPTION
    The script installs or updates Local on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Local".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Local' -ErrorAction SilentlyContinue

    PS > .\UpdateLocal.ps1 -InstallLocation 'C:\ProgramData\Local' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Local' | Select-Object Name -First 5
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
    6.4.2.exe
    UpdateLocal.ps1

    Install Local to 'C:\ProgramData\Local' and save its setup installer to the current directory.
#>
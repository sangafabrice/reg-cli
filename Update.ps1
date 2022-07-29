[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Figma",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Figma.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        'https://desktop.figma.com/win/FigmaSetup.exe' |
        Select-Object @{
            Name = 'Version'
            Expression = { [datetime] "$((Invoke-WebRequest $_ -Method Head -Verbose:$False).Headers.'Last-Modified')" }
        },@{
            Name = 'Link'
            Expression = { $_ }
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Figma'
    $InstallerDescription = "$SoftwareName Desktop"
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerVersion $SaveTo $InstallerDescription }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-SquirrelInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-SquirrelShortcut $NameLocation
        Set-BatchRedirect 'figma' $NameLocation
        If (!(Test-InstallOutdated -UseInstaller)) { 
            Write-Verbose "$SoftwareName $((Get-Item -LiteralPath (Get-InstallerPath) -ErrorAction SilentlyContinue).VersionInfo.FileVersionRaw) installation complete." 
        }
    } 
    Catch { $_ }
}

<#
.SYNOPSIS
    Updates Figma software.
.DESCRIPTION
    The script installs or updates Figma on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Figma".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Figma' -ErrorAction SilentlyContinue

    PS > .\UpdateFigma.ps1 -InstallLocation 'C:\ProgramData\Figma' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Figma' | Select-Object Name -First 5
    Name
    ----
    locales
    resources
    chrome_100_percent.pak
    chrome_200_percent.pak
    d3dcompiler_47.dll

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    2022.208.69.68.exe
    UpdateFigma.ps1

    Install Figma to 'C:\ProgramData\Figma' and save its setup installer to the current directory.
#>
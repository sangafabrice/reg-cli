[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Grammarly",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Grammarly.Desktop.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        'https://download-windows.grammarly.com/GrammarlyInstaller.exe' |
        Select-Object @{
            Name = 'Version'
            Expression = { [datetime] "$((Invoke-WebRequest $_ -Method Head -Verbose:$False).Headers.'Last-Modified')" }
        },@{
            Name = 'Link'
            Expression = { $_ }
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Grammarly'
    $InstallerDescription = "$SoftwareName for Windows"
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerVersion $SaveTo $InstallerDescription }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-SquirrelInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-SquirrelShortcut $NameLocation
        Set-BatchRedirect 'grammarly' $NameLocation
        If (!(Test-InstallOutdated -UseInstaller)) { 
            Write-Verbose "$SoftwareName $((Get-Item -LiteralPath (Get-InstallerPath) -ErrorAction SilentlyContinue).VersionInfo.FileVersionRaw) installation complete." 
        }
    } 
    Catch { $_ }
}

<#
.SYNOPSIS
    Updates Grammarly software.
.DESCRIPTION
    The script installs or updates Grammarly on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Grammarly".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Grammarly' -ErrorAction SilentlyContinue

    PS > .\UpdateGrammarly.ps1 -InstallLocation 'C:\ProgramData\Grammarly' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Grammarly' | Select-Object Name -First 5
    Name
    ----
    $PLUGINSDIR
    cs
    de
    es
    fr

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    2022.210.766.77.exe
    UpdateGrammarly.ps1

    Install Grammarly to 'C:\ProgramData\Grammarly' and save its setup installer to the current directory.
#>
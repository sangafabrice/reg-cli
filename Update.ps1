[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\GitKraken",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\gitkraken.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        "https://release.gitkraken.com/win$(Switch (Get-ExecutableType $NameLocation) { 'x64' { '64' } 'x86' { '32' } })/GitKrakenSetup.exe" |
        Select-Object @{
            Name = 'Version'
            Expression = { [datetime] "$((Invoke-WebRequest $_ -Method Head -Verbose:$False).Headers.'Last-Modified')" }
        },@{
            Name = 'Link'
            Expression = { $_ }
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'GitKraken'
    $InstallerDescription = 'Unleash your repo'
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerLastModified $SaveTo $InstallerDescription }
    Try {
        $GetExeVersion = { (Get-Item -LiteralPath $NameLocation -ErrorAction SilentlyContinue).VersionInfo.FileVersionRaw }
        $VersionPreInstall = & $GetExeVersion
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-SquirrelInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-SquirrelShortcut $NameLocation
        Set-BatchRedirect 'gitkraken' $NameLocation
        $VersionPostInstall = & $GetExeVersion
        If ($VersionPostInstall -gt $VersionPreInstall) { Write-Verbose "$SoftwareName $VersionPostInstall installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates GitKraken software.
.DESCRIPTION
    The script installs or updates GitKraken on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\GitKraken".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\GitKraken' -ErrorAction SilentlyContinue

    PS > .\UpdateGitKraken.ps1 -InstallLocation 'C:\ProgramData\GitKraken' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\GitKraken' | Select-Object Name -First 5
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
    2022.193.1434.83.exe
    UpdateGitKraken.ps1

    Install GitKraken to 'C:\ProgramData\GitKraken' and save its setup installer to the current directory.
#>
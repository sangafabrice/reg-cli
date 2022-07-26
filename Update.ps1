[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Insomnia",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\insomnia.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        @{
            Uri = 'https://updates.insomnia.rest/downloads/windows/latest'
            MaximumRedirection = 0
            SkipHttpErrorCheck = $True
            ErrorAction = 'SilentlyContinue'
        } | ForEach-Object { Invoke-WebRequest @_ -Verbose:$False } |
        Where-Object StatusCode -EQ 302 |
        ForEach-Object { $_.Headers.Location } |
        Select-Object @{
            Name = 'Version'
            Expression = { ([uri] $_).Segments?[-2] -replace '/$' }
        },@{
            Name = 'Link'
            Expression = { $_ }
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Insomnia'
    If (!$UpdateInfo) { $InstallerVersion = "$(Get-SavedInstallerVersion $SaveTo $SoftwareName)" }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $SoftwareName |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-SquirrelInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-SquirrelShortcut $NameLocation
        Set-BatchRedirect 'insomnia' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $(Get-InstallerVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Insomnia software.
.DESCRIPTION
    The script installs or updates Insomnia on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Insomnia.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Insomnia -ErrorAction SilentlyContinue

    PS > .\UpdateInsomnia.ps1 -InstallLocation C:\ProgramData\Insomnia -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Insomnia | Select-Object Name
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
    core@2022.4.2.exe
    UpdateInsomnia.ps1

    Install Insomnia to 'C:\ProgramData\Insomnia' and save its setup installer to the current directory.
#>
[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Postman",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\postman.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        @{
            Uri = "https://dl.pstmn.io/download/latest/win$(Switch (Get-ExecutableType $NameLocation) { 'x64' { '64' } 'x86' { '32' } })"
            Method = 'HEAD'
            ErrorAction = 'SilentlyContinue'
        } | Select-Object @{
            Name = 'Link'
            Expression = { $_.Uri }
        },@{
            Name = 'Resource'
            Expression = {
                Invoke-WebRequest @_ -Verbose:$False |
                ForEach-Object { ($_.Headers.'Content-Disposition' -split '=')[-1] } |
                Select-Object @{
                    Name = 'Version'
                    Expression = { 
                        [void] ($_ -match '\-(?<Version>(\d+\.)+\d+)\-')
                        $Matches.Version
                    }
                },@{
                    Name = 'Name'
                    Expression = { $_ }
                }
            }
        } | Select-Object Link -ExpandProperty Resource |
        Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Postman'
    If (!$UpdateInfo) { $InstallerVersion = "$(Get-SavedInstallerVersion $SaveTo $SoftwareName)" }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $SoftwareName |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-SquirrelInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-SquirrelShortcut $NameLocation
        Set-BatchRedirect 'postman' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $(Get-InstallerVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Postman software.
.DESCRIPTION
    The script installs or updates Postman on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Postman.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Postman -ErrorAction SilentlyContinue

    PS > .\UpdatePostman.ps1 -InstallLocation C:\ProgramData\Postman -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Postman | Select-Object Name -First 5
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
    9.25.2.exe
    UpdatePostman.ps1

    Install Postman to 'C:\ProgramData\Postman' and save its setup installer to the current directory.
#>
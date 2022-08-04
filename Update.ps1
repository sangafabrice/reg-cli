[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Messenger",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Messenger.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        'https://www.messenger.com/messenger/desktop/downloadV2/?platform=win' |
        Select-Object @{
            Name = 'Resource'
            Expression = {
                $ResponseHeader = (Invoke-WebRequest $_ -Method Head -Verbose:$False).Headers
                [pscustomobject] @{
                    Version = [datetime] "$($ResponseHeader.'Last-Modified')"
                    Name = ($ResponseHeader.'Content-Disposition' -split '=')?[-1]
                }
            }
        },@{
            Name = 'Link'
            Expression = { $_ }
        } | Select-Object Link -ExpandProperty Resource | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Messenger'
    $InstallerDescription = "$SoftwareName by Facebook"
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerVersion $SaveTo $InstallerDescription }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-NsisInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-NsisShortcut $NameLocation
        Set-BatchRedirect 'messenger' $NameLocation
        If (!(Test-InstallOutdated -UseInstaller)) {
            Write-Verbose "$SoftwareName $((Get-Item -LiteralPath (Get-InstallerPath) -ErrorAction SilentlyContinue).VersionInfo.FileVersionRaw) installation complete."
        }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Messenger software.
.DESCRIPTION
    The script installs or updates Messenger on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Messenger".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Messenger' -ErrorAction SilentlyContinue

    PS > .\UpdateMessenger.ps1 -InstallLocation 'C:\ProgramData\Messenger' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Messenger' | Select-Object Name -First 5
    Name
    ----
    resources
    CrashpadHandlerWindows.exe
    libEGL.dll
    libGLESv2.dll
    Messenger.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    v1.0.183.exe
    UpdateMessenger.ps1

    Install Messenger to 'C:\ProgramData\Messenger' and save its setup installer to the current directory.
#>
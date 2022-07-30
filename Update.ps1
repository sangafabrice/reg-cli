[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\WhatsApp",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\WhatsApp.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        "https://web.whatsapp.com/desktop/windows/release/$(Switch (Get-ExecutableType $NameLocation) { 'x64' { 'x64' } 'x86' { 'ia32' } })/WhatsAppSetup.exe" |
        Select-Object @{
            Name = 'Version'
            Expression = { [datetime] "$((Invoke-WebRequest $_ -Method Head -Verbose:$False).Headers.'Last-Modified')" }
        },@{
            Name = 'Link'
            Expression = { $_ }
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $InstallerDescription = 'WhatsApp'
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerVersion $SaveTo $InstallerDescription }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-SquirrelInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-SquirrelShortcut $NameLocation
        Set-BatchRedirect 'whatsapp' $NameLocation
        If (!(Test-InstallOutdated -UseInstaller)) { 
            Write-Verbose "$InstallerDescription $((Get-Item -LiteralPath (Get-InstallerPath) -ErrorAction SilentlyContinue).VersionInfo.FileVersionRaw) installation complete." 
        }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates WhatsApp software.
.DESCRIPTION
    The script installs or updates WhatsApp on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\WhatsApp".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\WhatsApp' -ErrorAction SilentlyContinue

    PS > .\UpdateWhatsApp.ps1 -InstallLocation 'C:\ProgramData\WhatsApp' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\WhatsApp' | Select-Object Name -First 5
    Name
    ----
    locales
    resources
    whatsapp_ExecutionStub.exe
    whatsapp.exe
    chrome_100_percent.pak

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    v1.60.0.exe
    UpdateWhatsApp.ps1

    Install WhatsApp to 'C:\ProgramData\WhatsApp' and save its setup installer to the current directory.
#>
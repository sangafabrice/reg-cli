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
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try {
                    Get-DownloadInfo -PropertyList @{
                        OSArch = Get-ExecutableType $NameLocation
                    } -From WhatsApp
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'WhatsApp'
            InstallerType = 'Squirrel'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
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
    whatsapp_2.2232.8.exe
    UpdateWhatsApp.ps1

    Install WhatsApp to 'C:\ProgramData\WhatsApp' and save its setup installer to the current directory.
#>
[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Yandex",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $BaseNameLocation = "$InstallLocation\browser"
    $NameLocation = "$BaseNameLocation.exe"
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
                    } -From Yandex | Select-NonEmptyObject
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Yandex'
            InstallerDescription = 'Yandex'
            BatchRedirectName = 'yandex'
            VisualElementManifest = @{
                BaseNameLocation = $BaseNameLocation
                HexColor = '#5f6368'
            }
            Extension = '.msi'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Vivaldi browser software.
.DESCRIPTION
    The script installs or updates Vivaldi browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Vivaldi.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Vivaldi -ErrorAction SilentlyContinue

    PS > .\UpdateVivaldi.ps1 -InstallLocation C:\ProgramData\Vivaldi -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Vivaldi | Select-Object Name
    Name
    ----
    5.3.2679.68
    update_notifier.exe
    vivaldi.exe
    vivaldi.VisualElementsManifest.xml
    vivaldi_proxy.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    5.3.2679.68.exe
    UpdateVivaldi.ps1

    Install Vivaldi browser to 'C:\ProgramData\Vivaldi' and save its setup installer to the current directory.
#>
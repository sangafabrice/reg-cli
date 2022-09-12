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
    Updates Yandex browser software.
.DESCRIPTION
    The script installs or updates Yandex browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Yandex.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Yandex -ErrorAction SilentlyContinue

    PS > .\UpdateYandex.ps1 -InstallLocation C:\ProgramData\Yandex -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Yandex | Select-Object Name
    Name
    ----
    22.7.0.1907
    browser_proxy.exe
    browser.exe
    browser.VisualElementsManifest.xml
    clidmgr.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    yandex_22.7.0.1907.msi
    UpdateYandex.ps1

    Install Yandex browser to 'C:\ProgramData\Yandex' and save its setup installer to the current directory.
#>
[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\AvastSecure",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $BaseNameLocation = "$InstallLocation\AvastBrowser"
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
                        UpdateServiceURL = 'https://update.avastbrowser.com/service/update2'
                        ApplicationID    = '{A8504530-742B-42BC-895D-2BAD6406F698}'
                        OwnerBrand       = '2101'
                        OSArch           = Get-ExecutableType $NameLocation
                    } -From Omaha | Select-NonEmptyObject
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Avast Secure'
            InstallerDescription = 'Avast Secure Browser Installer'
            BatchRedirectName = 'secure'
            VisualElementManifest = @{
                BaseNameLocation = $BaseNameLocation
                HexColor = '#2D364C'
            }
            SkipSslValidation = $True
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Avast Secure browser software.
.DESCRIPTION
    The script installs or updates Avast Secure browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\AvastSecure.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\AvastSecure -ErrorAction SilentlyContinue

    PS > .\UpdateAvastSecure.ps1 -InstallLocation C:\ProgramData\AvastSecure -SaveTo .

    PS > Get-ChildItem C:\ProgramData\AvastSecure | Select-Object Name
    Name
    ----
    102.1.17190.115
    AvastBrowser.exe
    AvastBrowser.VisualElementsManifest.xml
    AvastBrowserQHelper.exe
    browser_proxy.exe
    master_preferences

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    102.1.17190.115.exe
    UpdateAvastSecure.ps1

    Install Avast Secure browser to 'C:\ProgramData\AvastSecure' and save its setup installer to the current directory.
#>
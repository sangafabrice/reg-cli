[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\MSEdge",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $BaseNameLocation = "$InstallLocation\msedge"
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
                    } -From MSEdge | Select-NonEmptyObject
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Microsoft Edge'
            InstallerDescription = 'Microsoft Edge Installer'
            BatchRedirectName = 'msedge'
            VisualElementManifest = @{
                BaseNameLocation = $BaseNameLocation
                HexColor = '#173A73'
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
    Updates Microsoft Edge browser software.
.DESCRIPTION
    The script installs or updates Microsoft Edge browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\MSEdge.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\MSEdge -ErrorAction SilentlyContinue

    PS > .\UpdateMSEdge.ps1 -InstallLocation C:\ProgramData\MSEdge -SaveTo .

    PS > Get-ChildItem C:\ProgramData\MSEdge | Select-Object Name -First 5
    Name
    ----
    BHO
    EBWebView
    edge_feedback
    Extensions
    identity_proxy
    Locales

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    103.0.1264.49.exe
    UpdateMSEdge.ps1

    Install MSEdge browser to 'C:\ProgramData\MSEdge' and save its setup installer to the current directory.
#>
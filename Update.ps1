[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Brave",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\brave.exe"
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try {
                    Get-DownloadInfo -PropertyList @{
                        UpdateServiceURL = 'https://updates.bravesoftware.com/service/update2'
                        ApplicationID    = '{AFE6A462-C574-4B8A-AF43-4CC60DF4563B}'
                        ApplicationSpec  = "$(Get-ExecutableType $NameLocation)-rel"
                        Protocol         = '3.0'
                    } -From Omaha
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Brave'
            InstallerDescription = 'Brave Installer'
            VisualElementManifest = @{
                BaseNameLocation = "$InstallLocation\chrome"
                HexColor = '#5F6368'
            }
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Brave browser software.
.DESCRIPTION
    The script installs or updates Brave browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Brave.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Brave -ErrorAction SilentlyContinue

    PS > .\UpdateBrave.ps1 -InstallLocation C:\ProgramData\Brave -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Brave | Select-Object Name
    Name
    ----
    105.1.43.89
    brave.exe
    chrome_proxy.exe
    chrome.VisualElementsManifest.xml

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    brave_105.1.43.89.exe
    UpdateBrave.ps1

    Install Brave browser to 'C:\ProgramData\Brave' and save its setup installer to the current directory.
#>
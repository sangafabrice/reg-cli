[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Blisk",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try { Get-DownloadInfo -From Blisk }
                Catch { }
            )
            NameLocation = "$InstallLocation\blisk.exe"
            SaveTo = $SaveTo
            SoftwareName = 'Blisk'
            InstallerDescription = 'Blisk Installer'
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
    Updates Blisk browser software.
.DESCRIPTION
    The script installs or updates Blisk browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Blisk.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Blisk -ErrorAction SilentlyContinue

    PS > .\UpdateBlisk.ps1 -InstallLocation C:\ProgramData\Blisk -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Blisk | Select-Object Name
    Name
    ----
    19.0.60.43
    blisk.exe
    chrome.VisualElementsManifest.xml
    chrome_proxy.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    blisk_19.0.60.43.exe
    UpdateBlisk.ps1

    Install Blisk browser to 'C:\ProgramData\Blisk' and save its setup installer to the current directory.
#>
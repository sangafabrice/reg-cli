[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Tor",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\firefox.exe"
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo =
        Try {
            Get-DownloadInfo -PropertyList @{
                OSArch = Get-ExecutableType $NameLocation
            } -From TorProject | Select-NonEmptyObject
        }
        Catch { }
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $UpdateInfo
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Tor'
            InstallerDescription = 'CN="The Tor Project, Inc."'
            UseTimestamp = $True
            TimestampType = 'SigningTime'
            Checksum = $UpdateInfo.Checksum
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Tor browser software.
.DESCRIPTION
    The script installs or updates Tor browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Tor.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Tor -ErrorAction SilentlyContinue

    PS > .\UpdateTor.ps1 -InstallLocation C:\ProgramData\Tor -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Tor | Select-Object Name -First 5
    Name
    ----
    browser
    defaults
    fonts
    TorBrowser
    Accessible.tlb

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    tor_11.5.2.exe
    UpdateTor.ps1

    Install Tor browser to 'C:\ProgramData\Tor' and save its setup installer to the current directory.
#>
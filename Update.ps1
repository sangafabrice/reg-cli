[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\VideoLAN",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\vlc.exe"
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo =
        Try {
            Get-DownloadInfo -PropertyList @{
                OSArch = Get-ExecutableType $NameLocation
            } -From VideoLAN
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
            SoftwareName = 'VLC'
            InstallerDescription = 'CN=VideoLAN'
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
    Updates VLC media player software.
.DESCRIPTION
    The script installs or updates VLC media editor on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\VLC.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\VLC -ErrorAction SilentlyContinue

    PS > .\UpdateVLC.ps1 -InstallLocation C:\ProgramData\VLC -SaveTo .

    PS > Get-ChildItem C:\ProgramData\VLC | Select-Object Name -First 5
    Name
    ----
    $PLUGINSDIR
    hrtfs
    locale
    lua
    plugins

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    vlc_3.0.17.4.exe
    UpdateVLC.ps1

    Install VLC browser to 'C:\ProgramData\VLC' and save its setup installer to the current directory.
#>
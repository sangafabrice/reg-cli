[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\CodeBlocks",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo =
        Try { Get-DownloadInfo -From CodeBlocks }
        Catch { }
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $UpdateInfo
            NameLocation = "$InstallLocation\codeblocks.exe"
            SaveTo = $SaveTo
            SoftwareName = 'CodeBlocks'
            InstallerDescription = 'Code::Blocks cross-platform IDE'
            ShortcutName = 'CodeBlocks IDE'
            UseTimestamp = $True
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
    The script installs or updates VLC media player on Windows.
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
    MinGW
    share
    Addr2LineUI.exe
    cb_console_runner.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    codeblocks_20.3.exe
    UpdateVLC.ps1

    Install VLC browser to 'C:\ProgramData\VLC' and save its setup installer to the current directory.
#>
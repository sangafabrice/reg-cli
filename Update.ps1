[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\GhostScript",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\bin\gswin64.exe"
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo =
        Try {
            Get-DownloadInfo -PropertyList @{
                OSArch = Get-ExecutableType $NameLocation
            } -From GhostScript
        }
        Catch { }
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $UpdateInfo
            InstallLocation = $InstallLocation
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'GhostScript'
            ShortcutName = 'GhostScript'
            InstallerDescription = 'CN="Artifex Software, Inc."'
            UseTimestamp = $True
            TimestampType = 'SigningTime'
            Checksum = $UpdateInfo.Checksum
            CompareInstalls = $True
            InstallerType = 'BasicNSIS'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates GhostScript interpreter software.
.DESCRIPTION
    The script installs or updates GhostScript interpreter on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\GhostScript".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\GhostScript' -ErrorAction SilentlyContinue

    PS > .\UpdateGhostScript.ps1 -InstallLocation 'C:\ProgramData\GhostScript' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\GhostScript\bin' | Select-Object Name
    Name
    ----
    gsdll64.dll
    gsdll64.lib
    gswin64.exe
    gswin64c.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    ghostscript_10.0.0.exe
    UpdateGhostScript.ps1

    Install GhostScript to 'C:\ProgramData\GhostScript' and save its setup installer to the current directory.
#>
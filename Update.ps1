[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Shotcut",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo =
        Try { Get-DownloadInfo -From Shotcut }
        Catch { }
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $UpdateInfo
            NameLocation = "$InstallLocation\shotcut.exe"
            SaveTo = $SaveTo
            SoftwareName = 'Shotcut'
            InstallerDescription = 'CN="Meltytech, LLC"'
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
    Updates Shotcut media editor software.
.DESCRIPTION
    The script installs or updates Shotcut media editor on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Shotcut.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Shotcut -ErrorAction SilentlyContinue

    PS > .\UpdateShotcut.ps1 -InstallLocation C:\ProgramData\Shotcut -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Shotcut | Select-Object Name -First 5
    Name
    ----
    lib
    share
    avcodec-59.dll
    avdevice-59.dll
    avfilter-8.dll

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    shotcut_v22.09.23.exe
    UpdateShotcut.ps1

    Install Shotcut browser to 'C:\ProgramData\Shotcut' and save its setup installer to the current directory.
#>
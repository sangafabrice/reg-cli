[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\HandBrake",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo =
        Try { Get-DownloadInfo -From Handbrake }
        Catch { }
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $UpdateInfo
            NameLocation = "$InstallLocation\HandBrake.exe"
            SaveTo = $SaveTo
            SoftwareName = 'HandBrake'
            InstallerDescription = 'E=sr55.hb@outlook.com, CN="Open Source Developer, Scott Rae"'
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
    Updates HandBrake transcoder for digital video software.
.DESCRIPTION
    The script installs or updates HandBrake transcoder for digital video on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\HandBrake.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\HandBrake -ErrorAction SilentlyContinue

    PS > .\UpdateHandBrake.ps1 -InstallLocation C:\ProgramData\HandBrake -SaveTo .

    PS > Get-ChildItem C:\ProgramData\HandBrake | Select-Object Name -First 5
    Name
    ----
    doc
    HandBrake.exe
    HandBrake.Worker.exe
    hb.dll
    portable.ini.template

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    handbrake_1.5.1.exe
    UpdateHandBrake.ps1

    Install HandBrake to 'C:\ProgramData\HandBrake' and save its setup installer to the current directory.
#>
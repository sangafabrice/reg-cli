[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Wireshark",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Wireshark.exe"
    $MachineType = Get-ExecutableType $NameLocation
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try { Get-DownloadInfo -PropertyList @{ OSArch = $MachineType } -From Wireshark }
                Catch { }
            )
            InstallLocation = $InstallLocation
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Wireshark'
            InstallerDescription = "Wireshark installer for $($MachineType -replace 'x' -replace '86','32')-bit Windows"
            InstallerType = 'BasicNSIS'
            CompareInstalls = $True
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { $_ }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Wireshark software.
.DESCRIPTION
    The script installs or updates Wireshark on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Wireshark".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Wireshark' -ErrorAction SilentlyContinue

    PS > .\UpdateWireshark.ps1 -InstallLocation 'C:\ProgramData\Wireshark' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Wireshark' | Select-Object Name -First 5
    Name
    ----
    diameter
    dtds
    extcap
    iconengines
    imageformats

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    UpdateWireshark.ps1
    wireshark_4.0.0.exe

    Install Wireshark to 'C:\ProgramData\Wireshark' and save its setup installer to the current directory.
#>
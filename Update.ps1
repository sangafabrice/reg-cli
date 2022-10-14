[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Krita",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\bin\Krita.exe"
    $MachineType = Get-ExecutableType $NameLocation
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try { Get-DownloadInfo -PropertyList @{ OSArch = $MachineType } -From Krita }
                Catch { }
            )
            InstallLocation = $InstallLocation
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Krita'
            InstallerDescription = "Krita ($MachineType) * Setup"
            InstallerType = 'BasicNSIS'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { $_ }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Krita software.
.DESCRIPTION
    The script installs or updates Krita image editor on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Krita".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Krita\bin' -ErrorAction SilentlyContinue

    PS > .\UpdateKrita.ps1 -InstallLocation 'C:\ProgramData\Krita\bin' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Krita\bin' | Where-Object Name -Like 'krita*' | Select-Object Name
    Name
    ----
    krita.com
    krita.dll
    krita.exe
    kritarunner.com
    kritarunner.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    krita_5.1.1.exe
    UpdateKrita.ps1

    Install Krita to 'C:\ProgramData\Krita\bin' and save its setup installer to the current directory.
#>
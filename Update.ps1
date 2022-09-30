[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\PotPlayer",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $Is64BitOS = [Environment]::Is64BitOperatingSystem
    $NameLocation = "$InstallLocation\PotPlayer$(If($Is64BitOS){ '64' }).exe"
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try {
                    Get-DownloadInfo -PropertyList @{
                        OSArch = $Is64BitOS ? 'x64':'x86'
                    } -From PotPlayer
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'PotPlayer'
            InstallerDescription = 'PotPlayer Setup File'
            ForceReinstall = $True
            CompareInstalls = $True
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates PotPlayer software.
.DESCRIPTION
    The script installs or updates PotPlayer on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\PotPlayer".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\PotPlayer' -ErrorAction SilentlyContinue

    PS > .\UpdatePotPlayer.ps1 -InstallLocation 'C:\ProgramData\PotPlayer' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\PotPlayer' | Select-Object Name -First 5
    Name
    ----
    $0
    $PLUGINSDIR
    AviSynth
    Extension
    History

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    potplayer_2022.258.261.85.exe
    UpdatePotPlayer.ps1

    Install PotPlayer to 'C:\ProgramData\PotPlayer' and save its setup installer to the current directory.
#>
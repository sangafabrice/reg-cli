[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\TeamViewer",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\TeamViewer.exe"
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try {
                    Get-DownloadInfo -PropertyList @{
                        OSArch = Get-ExecutableType $NameLocation
                    } -From TeamViewer 
                }
                Catch { }
            )
            InstallLocation = $InstallLocation
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'TeamViewer'
            InstallerDescription = 'CN=TeamViewer Germany GmbH'
            InstallerType = 'BasicNSIS'
            CompareInstalls = $True
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates TeamViewer software.
.DESCRIPTION
    The script installs or updates TeamViewer on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\TeamViewer".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\TeamViewer' -ErrorAction SilentlyContinue

    PS > .\UpdateTeamViewer.ps1 -InstallLocation 'C:\ProgramData\TeamViewer' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\TeamViewer' | Where-Object Name -Like 'TeamViewer*' | Select-Object Name -First 5
    Name
    ----
    TeamViewer_Desktop.exe
    TeamViewer_Note.exe
    TeamViewer_Resource_ar.dll
    TeamViewer_Resource_bg.dll
    TeamViewer_Resource_cs.dll

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    teamviewer_15.34.4.exe
    UpdateTeamViewer.ps1

    Install TeamViewer to 'C:\ProgramData\TeamViewer' and save its setup installer to the current directory.
#>
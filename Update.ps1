[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Teams",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Teams.exe"
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
                    } -From Teams
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Microsoft Teams'
            InstallerType = 'Squirrel'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Microsoft Teams software.
.DESCRIPTION
    The script installs or updates Microsoft Teams on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Teams.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Teams -ErrorAction SilentlyContinue

    PS > .\UpdateTeams.ps1 -InstallLocation C:\ProgramData\Teams -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Teams | Select-Object Name -First 5
    Name
    ----
    locales
    resources
    swiftshader
    api-ms-win-core-console-l1-1-0.dll
    api-ms-win-core-console-l1-2-0.dll

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    microsoft_teams_1.5.0.21668.exe
    UpdateTeams.ps1

    Install Teams to 'C:\ProgramData\Teams' and save its setup installer to the current directory.
#>
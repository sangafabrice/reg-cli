[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Waterfox",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\waterfox.exe"
    Write-Verbose 'Retrieve install or update information...'
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Try {
                    Get-DownloadInfo -PropertyList @{
                        RepositoryId = 'WaterfoxCo/Waterfox'
                        AssetPattern = 'Setup\.exe$'
                    } | Select-Object Version,@{
                        Name = 'Link'
                        Expression = { $_.Link.Url }
                    } | Select-NonEmptyObject
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Waterfox'
            InstallerDescription = 'Waterfox'
            BatchRedirectName = 'waterfox'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Waterfox browser software.
.DESCRIPTION
    The script installs or updates Waterfox browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Waterfox.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Waterfox -ErrorAction SilentlyContinue

    PS > .\UpdateWaterfox.ps1 -InstallLocation C:\ProgramData\Waterfox -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Waterfox | Select-Object Name -First 5
    Name
    ----
    browser
    defaults
    fonts
    gmp-clearkey
    uninstall

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    G4.1.5.exe
    UpdateWaterfox.ps1

    Install Waterfox browser to 'C:\ProgramData\Waterfox' and save its setup installer to the current directory.
#>
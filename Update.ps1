[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Firefox",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\firefox.exe"
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo =
        Try {
            Get-DownloadInfo -PropertyList @{
                RepositoryId = 'firefox'
                OSArch = (Get-ExecutableType $NameLocation)
                VersionDelim = $Null
            } -From Mozilla | Select-NonEmptyObject
        }
        Catch { }
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $UpdateInfo
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Firefox'
            InstallerDescription = 'Firefox'
            BatchRedirectName = 'firefox'
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
    Updates Mozilla Firefox browser software.
.DESCRIPTION
    The script installs or updates Mozilla Firefox browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\MozillaFirefox.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\MozillaFirefox -ErrorAction SilentlyContinue

    PS > .\UpdateMozillaFirefox.ps1 -InstallLocation C:\ProgramData\MozillaFirefox -SaveTo .

    PS > Get-ChildItem C:\ProgramData\MozillaFirefox | Select-Object Name -First 5
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
    102.0.1.exe
    UpdateMozillaFirefox.ps1

    Install Mozilla Firefox browser to 'C:\ProgramData\MozillaFirefox' and save its setup installer to the current directory.
#>
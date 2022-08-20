[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\FirefoxDevEdition",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\firefox.exe"
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try {
                    Get-DownloadInfo -PropertyList @{
                        RepositoryId = 'devedition'
                        OSArch = Get-ExecutableType $NameLocation
                        VersionDelim = 'b'
                    } -From Mozilla | Select-NonEmptyObject
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Firefox Developer Edition'
            InstallerDescription = 'Firefox'
            BatchRedirectName = 'firefoxdev'
            UseTimestamp = $True
            TimestampType = 'SigningTime'
            Checksum = '60fb6bee2787c5fbcf3d6c1176a3f74f36b1529949b6456e73f289656df4d471dda487596945ea9fda5e33f48f43f09690ae49e65cf6066be9db7d3ddab0b42d'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { $_ }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Mozilla Firefox Developer Edition browser software.
.DESCRIPTION
    The script installs or updates Mozilla Firefox Developer Edition browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\FirefoxDevEdition.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\FirefoxDevEdition -ErrorAction SilentlyContinue

    PS > .\UpdateFirefoxDevEdition.ps1 -InstallLocation C:\ProgramData\FirefoxDevEdition -SaveTo .

    PS > Get-ChildItem C:\ProgramData\FirefoxDevEdition | Select-Object Name -First 5
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
    103.0.9.exe
    UpdateFirefoxDevEdition.ps1

    Install Mozilla Firefox Developer Edition browser to 'C:\ProgramData\FirefoxDevEdition' and save its setup installer to the current directory.
#>
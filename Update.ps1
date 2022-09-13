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
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo =
        Try {
            Get-DownloadInfo -PropertyList @{
                RepositoryId = 'devedition'
                OSArch = Get-ExecutableType $NameLocation
                VersionDelim = 'b'
            } -From Mozilla
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
            SoftwareName = 'Firefox Developer Edition'
            InstallerDescription = 'Firefox'
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
    firefox_developer_edition_105.0b7.exe
    UpdateFirefoxDevEdition.ps1

    Install Mozilla Firefox Developer Edition browser to 'C:\ProgramData\FirefoxDevEdition' and save its setup installer to the current directory.
#>
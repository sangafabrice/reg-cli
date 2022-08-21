[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Thunderbird",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\thunderbird.exe"
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo =
        Try {
            Get-DownloadInfo -PropertyList @{
                RepositoryId = 'thunderbird'
                OSArch = Get-ExecutableType $NameLocation
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
            SoftwareName = 'Thunderbird'
            InstallerDescription = 'Thunderbird'
            BatchRedirectName = 'thunderbird'
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
    Updates Mozilla Thunderbird software.
.DESCRIPTION
    The script installs or updates Mozilla Thunderbird on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Thunderbird.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Thunderbird -ErrorAction SilentlyContinue

    PS > .\UpdateThunderbird.ps1 -InstallLocation C:\ProgramData\Thunderbird -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Thunderbird | Select-Object Name -First 5
    Name
    ----
    chrome
    defaults
    fonts
    isp
    uninstall

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    102.1.2.exe
    UpdateThunderbird.ps1

    Install Mozilla Thunderbird to 'C:\ProgramData\Thunderbird' and save its setup installer to the current directory.
#>
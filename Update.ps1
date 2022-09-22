[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Librewolf",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo =
        Try { Get-DownloadInfo -From Librewolf }
        Catch { }
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $UpdateInfo
            NameLocation = "$InstallLocation\librewolf.exe"
            SaveTo = $SaveTo
            SoftwareName = 'Librewolf'
            UseTimestamp = $True
            Checksum = $UpdateInfo.Checksum
            UsePrefix = $True
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Librewolf browser software.
.DESCRIPTION
    The script installs or updates Librewolf browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Librewolf.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Librewolf -ErrorAction SilentlyContinue

    PS > .\UpdateLibrewolf.ps1 -InstallLocation C:\ProgramData\Librewolf -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Librewolf | Select-Object Name -First 5
    Name
    ----
    $PLUGINSDIR
    browser
    defaults
    distribution
    fonts

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    librewolf_v104.0-1.exe
    UpdateLibrewolf.ps1

    Install Librewolf browser to 'C:\ProgramData\Librewolf' and save its setup installer to the current directory.
#>
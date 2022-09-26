[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\TuneIn",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try { Get-DownloadInfo -From TuneIn }
                Catch { }
            )
            NameLocation = "$InstallLocation\TuneIn.exe"
            SaveTo = $SaveTo
            SoftwareName = 'TuneIn'
            InstallerDescription = 'TuneIn Desktop app - an electron wrapper for tunein.com'
            InstallerType = 'NSIS'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates TuneIn software.
.DESCRIPTION
    The script installs or updates TuneIn on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\TuneIn".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\TuneIn' -ErrorAction SilentlyContinue

    PS > .\UpdateTuneIn.ps1 -InstallLocation 'C:\ProgramData\TuneIn' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\TuneIn' | Select-Object Name -First 5
    Name
    ----
    TuneInes
    resources
    swiftshader
    chrome_100_percent.pak
    chrome_200_percent.pak

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    tunein_1.24.0.exe
    UpdateTuneIn.ps1

    Install TuneIn to 'C:\ProgramData\TuneIn' and save its setup installer to the current directory.
#>
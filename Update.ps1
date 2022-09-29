[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Grammarly",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Grammarly.Desktop.exe"
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try { Get-DownloadInfo -From Grammarly }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Grammarly'
            InstallerDescription = 'Grammarly for Windows'
            InstallerType = 'NSIS'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Grammarly software.
.DESCRIPTION
    The script installs or updates Grammarly on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Grammarly".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Grammarly' -ErrorAction SilentlyContinue

    PS > .\UpdateGrammarly.ps1 -InstallLocation 'C:\ProgramData\Grammarly' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Grammarly' | Select-Object Name -First 5
    Name
    ----
    $PLUGINSDIR
    cs
    de
    es
    fr

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    2022.210.766.77.exe
    UpdateGrammarly.ps1

    Install Grammarly to 'C:\ProgramData\Grammarly' and save its setup installer to the current directory.
#>
[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\SourceTree",
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
                Try { Get-DownloadInfo -From SourceTree }
                Catch { }
            )
            NameLocation = "$InstallLocation\SourceTree.exe"
            SaveTo = $SaveTo
            SoftwareName = 'SourceTree'
            InstallerType = 'Squirrel'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates SourceTree software.
.DESCRIPTION
    The script installs or updates SourceTree on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\SourceTree".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\SourceTree' -ErrorAction SilentlyContinue

    PS > .\UpdateSourceTree.ps1 -InstallLocation 'C:\ProgramData\SourceTree' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\SourceTree' | Select-Object Name -First 5
    Name
    ----
    de
    es
    extras
    fr
    icons

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    sourcetree_3.4.9.exe
    UpdateSourceTree.ps1

    Install SourceTree to 'C:\ProgramData\SourceTree' and save its setup installer to the current directory.
#>
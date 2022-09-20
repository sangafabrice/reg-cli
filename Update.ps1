[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Figma",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Figma.exe"
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try { Get-DownloadInfo -From Figma }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Figma Desktop'
            InstallerType = 'Squirrel'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Figma software.
.DESCRIPTION
    The script installs or updates Figma on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Figma".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Figma' -ErrorAction SilentlyContinue

    PS > .\UpdateFigma.ps1 -InstallLocation 'C:\ProgramData\Figma' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Figma' | Select-Object Name -First 5
    Name
    ----
    locales
    resources
    chrome_100_percent.pak
    chrome_200_percent.pak
    d3dcompiler_47.dll

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    figma_desktop_116.3.8.exe
    UpdateFigma.ps1

    Install Figma to 'C:\ProgramData\Figma' and save its setup installer to the current directory.
#>
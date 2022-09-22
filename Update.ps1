[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Insomnia",
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
                Try { Get-DownloadInfo -From Insomnia }
                Catch { }
            )
            NameLocation = "$InstallLocation\insomnia.exe"
            SaveTo = $SaveTo
            SoftwareName = 'Insomnia'
            InstallerType = 'Squirrel'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Insomnia software.
.DESCRIPTION
    The script installs or updates Insomnia on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Insomnia.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Insomnia -ErrorAction SilentlyContinue

    PS > .\UpdateInsomnia.ps1 -InstallLocation C:\ProgramData\Insomnia -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Insomnia | Select-Object Name
    Name
    ----
    locales
    resources
    swiftshader
    chrome_100_percent.pak
    chrome_200_percent.pak

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    insomnia_core@2022.5.1.exe
    UpdateInsomnia.ps1

    Install Insomnia to 'C:\ProgramData\Insomnia' and save its setup installer to the current directory.
#>
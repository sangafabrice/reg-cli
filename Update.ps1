[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Tabby",
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
                Try {
                    Get-DownloadInfo -PropertyList @{
                        RepositoryId = 'Eugeny/tabby'
                        AssetPattern = "setup\-x64\.exe$"
                    }
                }
                Catch { }
            )
            NameLocation = "$InstallLocation\Tabby.exe"
            SaveTo = $SaveTo
            SoftwareName = 'Tabby'
            InstallerDescription = 'A terminal for a modern age'
            InstallerType = 'NSIS'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Tabby software.
.DESCRIPTION
    The script installs or updates Tabby on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Tabby".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Tabby' -ErrorAction SilentlyContinue

    PS > .\UpdateTabby.ps1 -InstallLocation 'C:\ProgramData\Tabby' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Tabby' | Select-Object Name -First 5
    Name
    ----
    Tabbyes
    resources
    chrome_100_percent.pak
    chrome_200_percent.pak
    d3dcompiler_47.dll

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    tabby_v1.0.183.exe
    UpdateTabby.ps1

    Install Tabby to 'C:\ProgramData\Tabby' and save its setup installer to the current directory.
#>
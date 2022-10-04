[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Hyper",
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
                        RepositoryId='vercel/hyper'
                        AssetPattern= '\.exe$'
                    }
                }
                Catch { }
            )
            NameLocation = "$InstallLocation\Hyper.exe"
            SaveTo = $SaveTo
            SoftwareName = 'Hyper'
            InstallerDescription = 'A terminal built on web technologies'
            InstallerType = 'NSIS'
            NsisType = 64
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Hyper software.
.DESCRIPTION
    The script installs or updates Hyper terminal on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Hyper".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Hyper' -ErrorAction SilentlyContinue

    PS > .\UpdateHyper.ps1 -InstallLocation 'C:\ProgramData\Hyper' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Hyper' | Select-Object Name -First 5
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
    hyper_v3.3.0.exe
    UpdateHyper.ps1

    Install Hyper to 'C:\ProgramData\Hyper' and save its setup installer to the current directory.
#>
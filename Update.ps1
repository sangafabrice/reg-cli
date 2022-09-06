[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\OperaGX",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\launcher.exe"
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try {
                    Get-DownloadInfo -PropertyList @{
                        RepositoryID = 'opera_gx'
                        OSArch = (Get-ExecutableType $NameLocation)
                        FormatedName = 'Opera_GX'
                    } -From Opera | Select-NonEmptyObject
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Opera GX'
            InstallerDescription = 'Opera GX Installer'
            BatchRedirectName = 'operagx'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Opera GX browser software.
.DESCRIPTION
    The script installs or updates Opera GX browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\OperaGX.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\OperaGX -ErrorAction SilentlyContinue

    PS > .\UpdateOperaGX.ps1 -InstallLocation C:\ProgramData\OperaGX -SaveTo .

    PS > Get-ChildItem C:\ProgramData\OperaGX | Select-Object Name -First 5
    Name
    ----
    Assets
    localization
    MEIPreload
    resources
    90.0.4480.86.manifest

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    opera_gx_90.0.4480.86.exe
    UpdateOperaGX.ps1

    Install Opera GX browser to 'C:\ProgramData\OperaGX' and save its setup installer to the current directory.
#>
[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\OBS-Studio",
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
                        RepositoryId = 'obsproject/obs-studio'
                        AssetPattern = 'Full\-Installer\-x64\.exe$'
                    }
                }
                Catch { }
            )
            InstallLocation = $InstallLocation
            NameLocation = "$InstallLocation\bin\64bit\obs64.exe"
            SaveTo = $SaveTo
            SoftwareName = 'OBS Studio'
            InstallerDescription = 'OBS Studio Installer'
            InstallerType = 'BasicNSIS'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates OBS Studio software.
.DESCRIPTION
    The script installs or updates OBS Studio on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\OBS-Studio.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\OBS-Studio -ErrorAction SilentlyContinue

    PS > .\UpdateOBSStudio.ps1 -InstallLocation C:\ProgramData\OBS-Studio -SaveTo .

    PS > Get-ChildItem C:\ProgramData\OBS-Studio\bin\64bit | Where-Object Name -Like 'obs*' | Select-Object Name
    Name
    ----
    obs-amf-test.exe
    obs-amf-test.pdb
    obs-ffmpeg-mux.exe
    obs-ffmpeg-mux.pdb
    obs-frontend-api.dll
    obs-frontend-api.pdb
    obs-scripting.dll
    obs-scripting.pdb
    obs.dll
    obs.pdb
    obs64.exe
    obs64.pdb
    obsglad.dll
    obsglad.pdb

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    obs_studio_28.0.3.exe
    UpdateOBSStudio.ps1

    Install OBS Studio to 'C:\ProgramData\OBS-Studio' and save its setup installer to the current directory.
#>
[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\FileZillaServer",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\filezilla-server-gui.exe"
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try {
                    Get-DownloadInfo -PropertyList @{
                        Type = 'server'
                        OSArch = 'x64'
                    } -From FileZilla 
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'FileZilla Server'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates FileZilla Server software.
.DESCRIPTION
    The script installs or updates FileZilla Server on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\FileZillaServer".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\FileZillaServer' -ErrorAction SilentlyContinue

    PS > .\UpdateFileZillaServer.ps1 -InstallLocation 'C:\ProgramData\FileZillaServer' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\FileZillaServer' | Select-Object Name -First 5
    Name
    ----
    COPYING
    filezilla-server-config-converter.exe
    filezilla-server-crypt.exe
    filezilla-server-gui.exe
    filezilla-server-impersonator.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    filezilla_server_1.5.1.exe
    UpdateFileZillaServer.ps1

    Install FileZilla Server to 'C:\ProgramData\FileZillaServer' and save its setup installer to the current directory.
#>
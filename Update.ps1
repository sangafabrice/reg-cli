[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\FileZillaClient",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\filezilla.exe"
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try {
                    Get-DownloadInfo -PropertyList @{
                        Type = 'client'
                        OSArch = Get-ExecutableType $NameLocation
                    } -From FileZilla 
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'FileZilla FTP Client'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates FileZilla FTP Client software.
.DESCRIPTION
    The script installs or updates FileZilla FTP Client on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\FileZillaClient".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\FileZillaClient' -ErrorAction SilentlyContinue

    PS > .\UpdateFileZillaClient.ps1 -InstallLocation 'C:\ProgramData\FileZillaClient' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\FileZillaClient' | Select-Object Name -First 5
    Name
    ----
    docs
    locales
    resources
    AUTHORS
    filezilla.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    filezilla_ftp_client_3.61.0.exe
    UpdateFileZillaClient.ps1

    Install FileZilla FTP Client to 'C:\ProgramData\FileZillaClient' and save its setup installer to the current directory.
#>
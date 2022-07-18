[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Firefox",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\firefox.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        Get-DownloadInfo -PropertyList @{
            RepositoryId = 'firefox'
            OSArch = (Get-ExecutableType $NameLocation)
            VersionDelim = $Null
        } -From Mozilla |
        Where-Object {
            @($_.Version,$_.Link,$_.Checksum) |
            ForEach-Object { $_ -notin @($Null, '') }
        }
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Firefox'
    $UpdateInfoCountZero = $UpdateInfo.Count -le 0
    If ($UpdateInfoCountZero) {
        $InstallerVersion = "$((
            Get-ChildItem $SaveTo |
            Where-Object { $_.VersionInfo.FileDescription -ieq $SoftwareName } |
            Get-AuthenticodeSignatureEx |
            Sort-Object -Descending -Property SigningTime |
            Select-Object -First 1
        ).SigningTime)"
    }
    Try {
        $GetExeVersion = { (Get-Item -LiteralPath $NameLocation -ErrorAction SilentlyContinue).VersionInfo.FileVersionRaw }
        $VersionPreInstall = & $GetExeVersion
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $SoftwareName -UseTimeStamp:$UpdateInfoCountZero |
        Import-Module -Verbose:$False -Force
        Switch ($UpdateInfo) { {$_.Count -gt 0} { Start-InstallerDownload $_.Link $_.Checksum -Verbose:$VerbosePreferenceBool } }
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect 'firefox' $NameLocation
        $VersionPostInstall = & $GetExeVersion
        If ($VersionPostInstall -gt $VersionPreInstall) {
            Write-Verbose "$SoftwareName $((Get-InstallerVersion) ?? $VersionPostInstall) installation complete."
        }
    } 
    Catch { $_ }
}

<#
.SYNOPSIS
    Updates Mozilla Firefox browser software.
.DESCRIPTION
    The script installs or updates Mozilla Firefox browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\MozillaFirefox.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\MozillaFirefox -ErrorAction SilentlyContinue

    PS > .\UpdateMozillaFirefox.ps1 -InstallLocation C:\ProgramData\MozillaFirefox -SaveTo .

    PS > Get-ChildItem C:\ProgramData\MozillaFirefox | Select-Object Name -First 5
    Name
    ----
    browser
    defaults
    fonts
    gmp-clearkey
    uninstall

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    102.0.1.exe
    UpdateMozillaFirefox.ps1

    Install Mozilla Firefox browser to 'C:\ProgramData\MozillaFirefox' and save its setup installer to the current directory.
#>
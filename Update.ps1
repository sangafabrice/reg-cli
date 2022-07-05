[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (& {
            Param($Path)
            $Pattern = '(?<Drive>^.+):'
            If ($Path -match $Pattern -or $PWD -match $Pattern) {
                Return $Matches.Drive -iin @((Get-PSDrive -PSProvider FileSystem).Name)
            }
            Return $False
        } $_) -and
        $(
            @{
                LiteralPath = $_
                ErrorAction = 'SilentlyContinue'
            } | ForEach-Object { Get-Item @_ }
        ).FullName -ine $PSScriptRoot
    })] [string]
    $InstallLocation = "${Env:ProgramData}\AvastSecure",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (Get-Item -LiteralPath $_).PSDrive.Name -iin 
        @((Get-PSDrive -PSProvider FileSystem).Name)
    })] [string]
    $SaveTo = $PSScriptRoot
)

& {
    $BaseNameLocation = "$InstallLocation\AvastBrowser"
    $NameLocation = "$BaseNameLocation.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        Get-DownloadInfo -PropertyList @{
            UpdateServiceURL = 'https://update.avastbrowser.com/service/update2'
            ApplicationID    = '{A8504530-742B-42BC-895D-2BAD6406F698}'
            OwnerBrand       = '2101'
            OSArch           = Get-ExecutableType $NameLocation
        } -From Omaha |
        Where-Object {
            @($_.Version,$_.Link,$_.Checksum) |
            ForEach-Object { $_ -notin @($Null, '') }
        }
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Avast Secure Browser'
    $InstallerDescription = "$SoftwareName Installer"
    If ($UpdateInfo.Count -le 0) {
        $InstallerVersion = "$(
            Get-ChildItem $SaveTo |
            Select-Object VersionInfo -ExpandProperty VersionInfo |
            Where-Object { $_.FileDescription -ieq $InstallerDescription } |
            ForEach-Object { [version] $_.ProductVersion } |
            Sort-Object -Descending |
            Select-Object -First 1
        )"
    }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        If ($UpdateInfo.Count -gt 0) { Start-InstallerDownload "$($UpdateInfo.Link)" $UpdateInfo.Checksum -Verbose:$VerbosePreferenceBool }
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        If (Test-InstallOutdated) {
            Write-Verbose 'Current install is outdated or not installed...'
            Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation
            Remove-Item "${BaseNameLocation}Uninstall.exe" -Force
        }
        Set-ChromiumVisualElementsManifest "$BaseNameLocation.VisualElementsManifest.xml" '#2D364C'
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect 'secure' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $InstallerVersion installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Avast Secure browser software.
.DESCRIPTION
    The script installs or updates Avast Secure browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\AvastSecure.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\AvastSecure -ErrorAction SilentlyContinue

    PS > .\UpdateAvastSecure.ps1 -InstallLocation C:\ProgramData\AvastSecure -SaveTo .

    PS > Get-ChildItem C:\ProgramData\AvastSecure | Select-Object Name
    Name
    ----
    102.1.17190.115
    AvastBrowser.exe
    AvastBrowser.VisualElementsManifest.xml
    AvastBrowserQHelper.exe
    browser_proxy.exe
    master_preferences

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    102.1.17190.115.exe
    UpdateAvastSecure.ps1

    Install Avast Secure browser to 'C:\ProgramData\AvastSecure' and save its setup installer to the current directory.
#>
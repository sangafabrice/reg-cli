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

$BaseNameLocation = "$InstallLocation\AvastBrowser"
Write-Verbose 'Retrieve install or update information...'
Switch (
    Get-DownloadInfo -PropertyList @{
        UpdateServiceURL = 'https://update.avastbrowser.com/service/update2'
        ApplicationID    = '{A8504530-742B-42BC-895D-2BAD6406F698}'
        OwnerBrand       = '2101'
        OSArch           = Get-ExecutableType "$BaseNameLocation.exe"
    } -From Omaha
) {
    {
        @($_.Version,$_.Link,$_.Checksum) |
        ForEach-Object { $_ -notin @($Null, '') }
    } {
        $Version = [version]$_.Version
        Write-Verbose "Avast Secure browser $Version installation starts..."
        $SaveToContent = (Get-ChildItem $SaveTo).Where({ $_.VersionInfo.FileDescription -ieq 'Avast Secure Browser Installer' })
        $Installer = $SaveToContent.Where({ [version]$_.VersionInfo.ProductVersion -eq $Version }).FullName ??
            "$SaveTo\$($_.Version).exe"
        $Checksum = $_.Checksum
        If (!(Test-Path $Installer)) {
            Write-Verbose 'Download Avast Secure browser installer...'
            Save-Installer "$($_.Link)" |
            ForEach-Object {
                If ($Checksum -ieq (Get-FileHash $_ SHA256).Hash) {
                    Write-Verbose 'Hashes match...'
                    Move-Item $_ -Destination $Installer
                }
            }
        }
        If (Test-Path $Installer) {
            Write-Verbose 'Delete outdated installers...'
            $SaveToContent | Remove-Item -Exclude (Get-Item $Installer).Name
        }
        $IsCurrentInstallOutdated = {
            $Version -gt $(Try { [version] $(
                @{
                    LiteralPath = "$BaseNameLocation.exe"
                    ErrorAction = 'SilentlyContinue'
                } | ForEach-Object { Get-Item @_ }
            ).VersionInfo.ProductVersion } Catch { })
        }
        If (& $IsCurrentInstallOutdated) {
            Write-Verbose 'Current Secure install is outdated or it is not installed...'
            Expand-ChromiumInstaller $Installer "$BaseNameLocation.exe"
            Remove-Item "${BaseNameLocation}Uninstall.exe" -Force
        }
    }
}
Set-ChromiumVisualElementsManifest "$BaseNameLocation.VisualElementsManifest.xml" '#2D364C'
Set-ChromiumShortcut "$BaseNameLocation.exe"
Set-BatchRedirect 'secure' "$BaseNameLocation.exe"
If (!(& $IsCurrentInstallOutdated)) { Write-Verbose "Avast Secure browser $Version installation complete." }

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

    PS > Get-ChildItem C:\ProgramData\AvastSecure | Select-Object Name
    Name
    ----
    102.1.17190.115.exe
    UpdateAvastSecure.ps1

    Install Avast Secure browser to 'C:\ProgramData\AvastSecure' and save its setup installer to the current directory.
#>
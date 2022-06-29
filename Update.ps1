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
        $Installer = "$SaveTo\$($_.Version).exe"
        $Checksum = $_.Checksum
        If (!(Test-Path $Installer)) {
            Save-Installer "$($_.Link)" |
            ForEach-Object {
                If ($Checksum -ieq (Get-FileHash $_ SHA256).Hash) {
                    (Get-Item "$SaveTo\*").Where({ $_.VersionInfo.FileDescription -ieq 'Avast Secure Browser Installer' }) |
                    Remove-Item
                    Move-Item $_ -Destination $Installer
                }
            }
        }
        If (([version] $_.Version) -gt $(Try { [version] $(
            @{
                LiteralPath = "$BaseNameLocation.exe"
                ErrorAction = 'SilentlyContinue'
            } | ForEach-Object { Get-ChildItem @_ }
        ).VersionInfo.ProductVersion } Catch { })) {
            Expand-ChromiumInstaller $Installer "$BaseNameLocation.exe"
            Remove-Item "${BaseNameLocation}Uninstall.exe" -Force
        }
    }
}
Set-ChromiumVisualElementsManifest "$BaseNameLocation.VisualElementsManifest.xml" '#2D364C'
Set-ChromiumShortcut "$BaseNameLocation.exe"
Set-BatchRedirect 'secure' "$BaseNameLocation.exe"
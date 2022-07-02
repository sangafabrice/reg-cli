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
    $InstallLocation = "${Env:ProgramData}\Brave",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (Get-Item -LiteralPath $_).PSDrive.Name -iin 
        @((Get-PSDrive -PSProvider FileSystem).Name)
    })] [string]
    $SaveTo = $PSScriptRoot
)

$ExecutablePath = "$InstallLocation\brave.exe"
Switch (
    Get-DownloadInfo -PropertyList @{
        UpdateServiceURL = 'https://updates.bravesoftware.com/service/update2'
        ApplicationID    = '{AFE6A462-C574-4B8A-AF43-4CC60DF4563B}'
        ApplicationSpec  = "$(Get-ExecutableType "$ExecutablePath")-rel"
        Protocol         = '3.0'
    } -From Omaha
) {
    {
        @($_.Version,$_.Link,$_.Checksum) |
        ForEach-Object { $_ -notin @($Null, '') }
    } {
        $SaveToContent = Get-Item "$SaveTo\*"
        $Version = [version]$_.Version
        $Installer = $SaveToContent.Where({ [version]$_.VersionInfo.ProductVersion -eq $Version }).FullName ??
            "$SaveTo\$($_.Version).exe"
        $Checksum = $_.Checksum
        If (!(Test-Path $Installer)) {
            Save-Installer "$($_.Link)" |
            ForEach-Object {
                If ($Checksum -ieq (Get-FileHash $_ SHA256).Hash) {
                    $SaveToContent.Where({ $_.VersionInfo.FileDescription -ieq 'Brave Installer' }) |
                    Remove-Item
                    Move-Item $_ -Destination $Installer
                }
            }
        }
        If (([version] $_.Version) -gt $(Try { [version] $(
            @{
                LiteralPath = "$ExecutablePath"
                ErrorAction = 'SilentlyContinue'
            } | ForEach-Object { Get-ChildItem @_ }
        ).VersionInfo.ProductVersion } Catch { })) { Expand-ChromiumInstaller $Installer "$ExecutablePath" }
    }
}
Set-ChromiumVisualElementsManifest "$InstallLocation\chrome.VisualElementsManifest.xml" '#5F6368'
Set-ChromiumShortcut "$ExecutablePath"
Set-BatchRedirect 'brave' "$ExecutablePath"

<#
.SYNOPSIS
    Updates Brave browser software.
.DESCRIPTION
    The script installs or updates Brave browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Brave.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Brave -ErrorAction SilentlyContinue

    PS > .\UpdateBrave.ps1 -InstallLocation C:\ProgramData\Brave -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Brave | Select-Object Name
    Name
    ----
    103.1.40.109
    brave.exe
    chrome_proxy.exe
    chrome.VisualElementsManifest.xml

    PS > Get-ChildItem C:\ProgramData\Brave | Select-Object Name
    Name
    ----
    103.1.40.109.exe
    UpdateBrave.ps1

    Install Brave browser to 'C:\ProgramData\Brave' and save its setup installer to the current directory.
#>
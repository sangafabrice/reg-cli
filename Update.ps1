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
    $InstallLocation = "${Env:ProgramData}\GoogleChrome",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (Get-Item -LiteralPath $_).PSDrive.Name -iin 
        @((Get-PSDrive -PSProvider FileSystem).Name)
    })] [string]
    $SaveTo = $PSScriptRoot
)

& {
    $BaseNameLocation = "$InstallLocation\chrome"
    $NameLocation = "$BaseNameLocation.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $MachineType = "$(Get-ExecutableType $NameLocation)"
    $UpdateInfo = 
        Get-DownloadInfo -PropertyList @{
            UpdateServiceURL = 'https://update.googleapis.com/service/update2'
            ApplicationID    = '{8A69D345-D564-463c-AFF1-A69D9E530F96}'
            OwnerBrand       = "$(Switch ($MachineType) { 'x64' { 'YTUH' } Default { 'GGLS' } })"
            ApplicationSpec  = "$(Switch ($MachineType) { 'x64' { 'x64-stable-statsdef_1' } Default { 'stable-arch_x86-statsdef_1' } })"
        } -From Omaha |
        Where-Object {
            @($_.Version,$_.Link,$_.Checksum) |
            ForEach-Object { $_ -notin @($Null, '') }
        }
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Google Chrome'
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
        If ($UpdateInfo.Count -gt 0) { Start-InstallerDownload "$($UpdateInfo.Link.Where({ "$_" -like 'https://*' }, 'First'))" $UpdateInfo.Checksum -Verbose:$VerbosePreferenceBool }
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        If (Test-InstallOutdated) {
            Write-Verbose 'Current install is outdated or not installed...'
            Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation
        }
        Set-ChromiumVisualElementsManifest "$BaseNameLocation.VisualElementsManifest.xml" '#2D364C'
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect 'chrome' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $InstallerVersion installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Google Chrome browser software.
.DESCRIPTION
    The script installs or updates Google Chrome browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\GoogleChrome.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\GoogleChrome -ErrorAction SilentlyContinue

    PS > .\UpdateGoogleChrome.ps1 -InstallLocation C:\ProgramData\GoogleChrome -SaveTo .

    PS > Get-ChildItem C:\ProgramData\GoogleChrome | Select-Object Name
    Name
    ----
    103.0.5060.66
    chrome_proxy.exe
    chrome.exe
    chrome.VisualElementsManifest.xml

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    103.0.5060.66.exe
    UpdateGoogleChrome.ps1

    Install Google Chrome browser to 'C:\ProgramData\GoogleChrome' and save its setup installer to the current directory.
#>
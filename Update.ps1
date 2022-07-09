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
    $InstallLocation = "${Env:ProgramData}\Blisk",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (Get-Item -LiteralPath $_).PSDrive.Name -iin 
        @((Get-PSDrive -PSProvider FileSystem).Name)
    })] [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\blisk.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        $(Try {
            @{
                Uri = 'https://blisk.io/download/?os=win'
                UserAgent = 'NSISDL/1.2 (Mozilla)'
                MaximumRedirection = 0
                SkipHttpErrorCheck = $True
                ErrorAction = 'SilentlyContinue'
                Verbose = $False
            } | ForEach-Object { (Invoke-WebRequest @_).Headers.Location } |
            Select-Object @{
                Name = 'Version'
                Expression = {
                    [void] ($_ -match "BliskInstaller_(?<Version>(\d+\.){3}\d+)\.exe$")
                    [version] $Matches.Version
                }
            },@{
                Name = 'Link'
                Expression = { $_ }
            } -Unique |
            Where-Object { ![string]::IsNullOrEmpty($_.Version) } |
            Sort-Object -Descending -Property Version |
            Select-Object -First 1
        } Catch { }) |
        Where-Object {
            @($_.Version,$_.Link) |
            ForEach-Object { $_ -notin @($Null, '') }
        }
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Blisk'
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
        If ($UpdateInfo.Count -gt 0) { Start-InstallerDownload "$($UpdateInfo.Link)" -Verbose:$VerbosePreferenceBool }
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        If (Test-InstallOutdated) {
            Write-Verbose 'Current install is outdated or not installed...'
            Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation
        }
        Set-ChromiumVisualElementsManifest "$InstallLocation\chrome.VisualElementsManifest.xml" '#5F6368'
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect 'blisk' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $InstallerVersion installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Blisk browser software.
.DESCRIPTION
    The script installs or updates Blisk browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Blisk.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Blisk -ErrorAction SilentlyContinue

    PS > .\UpdateBlisk.ps1 -InstallLocation C:\ProgramData\Blisk -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Blisk | Select-Object Name
    Name
    ----
    18.0.193.167
    blisk.exe
    chrome.VisualElementsManifest.xml
    chrome_proxy.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    18.0.193.167.exe
    UpdateBlisk.ps1

    Install Blisk browser to 'C:\ProgramData\Blisk' and save its setup installer to the current directory.
#>
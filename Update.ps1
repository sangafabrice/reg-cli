[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:LOCALAPPDATA}\Microsoft\WindowsApps\youtube-dl.exe",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        Get-DownloadInfo -PropertyList @{
            RepositoryId = 'ytdl-org/youtube-dl'
            AssetPattern = 'youtube-dl.exe$|SHA2-512SUMS$'
        } | Select-NonEmptyObject
    $InstallerVersion = $UpdateInfo.Version
    $InstallerDescription = 'YouTube video downloader'
    If (!$UpdateInfo) { $InstallerVersion = "$(Get-SavedInstallerVersion $SaveTo $InstallerDescription)" }
    Else {
        $GetURL = {
            Param($Pattern)
            "$($UpdateInfo.Link.Where({ $_.Url -like $Pattern }).Url)"
        }
        $UpdateInfo = Add-Member -InputObject $UpdateInfo -MemberType NoteProperty -Name Checksum -Value "$(
            (((Invoke-WebRequest (& $GetURL '*512SUMS') -Verbose:$False).Content |
            ForEach-Object { [char] $_ }) -join '' -split "`n" |
            ConvertFrom-String).Where({$_.P2 -ieq 'youtube-dl.exe'}).P1
        )" -Passthru
        $UpdateInfo.Link = & $GetURL '*.exe'
    }
    Try {
        New-RegCliUpdate $InstallLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        $UpdateInfo | Start-InstallerDownload -Verbose:$VerbosePreferenceBool
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        $TestInstall = $False
        Set-ConsoleSymlink ([ref] $TestInstall)
        If ($TestInstall) { Write-Verbose "$InstallerDescription $InstallerVersion installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Youtube video downloader command line tool.
.DESCRIPTION
    The script installs or updates Youtube video downloader command line tool on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the console app.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %LOCALAPPDATA%\Microsoft\WindowsApps\youtube-dl.exe.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\YoutubeDl -ErrorAction SilentlyContinue

    PS > .\UpdateYoutubeDl.ps1 -InstallLocation C:\ProgramData\YoutubeDl\youtube-dl.exe -SaveTo .

    PS > Get-ChildItem C:\ProgramData\YoutubeDl | Select-Object Name
    Name
    ----
    youtube-dl.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    2021.12.17.exe
    UpdateYoutubeDl.ps1

    Install Youtube video downloader to 'C:\ProgramData\YoutubeDl' and save its setup installer to the current directory.
#>
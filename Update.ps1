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
        } |
        Where-Object {
            @($_.Version,$_.Link) |
            ForEach-Object { $_ -notin @($Null, '') }
        }
    $InstallerVersion = $UpdateInfo.Version
    $InstallerDescription = 'YouTube video downloader'
    If ($UpdateInfo.Count -le 0) {
        $InstallerVersion = "$(
            Get-ChildItem $SaveTo |
            Where-Object { $_ -isnot [System.IO.DirectoryInfo] } |
            Select-Object -ExpandProperty VersionInfo |
            Where-Object FileDescription -IEQ $InstallerDescription |
            ForEach-Object { $_.FileVersionRaw } |
            Sort-Object -Descending |
            Select-Object -First 1
        )"
    }
    Try {
        New-RegCliUpdate $InstallLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        Switch ($UpdateInfo) {
        {$_.Count -gt 0} {
            Start-InstallerDownload "$($_.Link.Where({ $_.Url -like '*.exe' }).Url)" "$(
                (((Invoke-WebRequest "$($_.Link.Where({$_.Url -like '*512SUMS'}).Url)" -Verbose:$False).Content |
                ForEach-Object { [char] $_ }) -join '' -split "`n" |
                ConvertFrom-String).Where({$_.P2 -ieq 'youtube-dl.exe'}).P1
            )" -Verbose:$VerbosePreferenceBool
        } }
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        $TestInstall = $False
        $InstallDirectory = $InstallLocation -replace '(\\|/)[^\\/]+$'
        If ([string]::IsNullOrEmpty($InstallDirectory)) { $InstallDirectory = $PWD }
        If ("$((Get-Item $InstallDirectory -ErrorAction SilentlyContinue).FullName)" -ieq (Get-Item $SaveTo).FullName) {
            # If $InstallLocation directory is equal to $SaveTo
            @{
                NewName = & {
                    [void] ($InstallLocation -match '(?<ExeName>[^\\/]+$)')
                    $Matches.ExeName
                }
                LiteralPath = Get-InstallerPath
                ErrorAction = 'SilentlyContinue'
                Force = $True
            } | ForEach-Object { Rename-Item @_ }
            $TestInstall = Test-Path $InstallLocation
        } Else {
            New-Item $InstallDirectory -ItemType Directory -Force | Out-Null
            @{
                Path = $InstallLocation
                ItemType = 'SymbolicLink'
                Value = Get-InstallerPath
                ErrorAction = 'SilentlyContinue'
                Force = $True
            } | ForEach-Object { New-Item @_ | Out-Null }
            $TestInstall = (Get-Item (Get-Item $InstallLocation).Target).FullName -ieq (Get-Item (Get-InstallerPath)).FullName
        }
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
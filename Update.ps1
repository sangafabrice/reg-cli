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
    $InstallLocation = "${Env:ProgramData}\Opera",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (Get-Item -LiteralPath $_).PSDrive.Name -iin 
        @((Get-PSDrive -PSProvider FileSystem).Name)
    })] [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\launcher.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        $(Try {
            $UriBase = 'https://get.geo.opera.com/pub/opera/desktop/'
            (Invoke-WebRequest $UriBase -Verbose:$False).Links.href -notlike '../' |
            ForEach-Object { [version]($_ -replace '/') } |
            Sort-Object -Descending -Unique |
            Select-Object @{
                Name = 'Version'
                Expression = { "$_" }
            },@{
                Name = 'Link'
                Expression = { "$UriBase$_/win/Opera_$($_)_Setup$(If((Get-ExecutableType $NameLocation) -eq 'x64'){ '_x64' }).exe" }
            } -First 1 |
            Select-Object Version,Link,@{
                Name = 'Checksum';
                Expression = { "$(Invoke-WebRequest "$($_.Link).sha256sum" -Verbose:$False)" }
            }
        } Catch { }) |
        Where-Object {
            @($_.Version,$_.Link,$_.Checksum) |
            ForEach-Object { $_ -notin @($Null, '') }
        }
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Opera'
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
        If ($UpdateInfo.Count -gt 0) { Start-InstallerDownload $UpdateInfo.Link $UpdateInfo.Checksum -Force -Verbose:$VerbosePreferenceBool }
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        If (Test-InstallOutdated) {
            Write-Verbose 'Current install is outdated or not installed...'
            Expand-Installer (Get-InstallerPath) $InstallLocation
        }
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect 'opera' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $InstallerVersion installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Opera browser software.
.DESCRIPTION
    The script installs or updates Opera browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Opera.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Opera -ErrorAction SilentlyContinue

    PS > .\UpdateOpera.ps1 -InstallLocation C:\ProgramData\Opera -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Opera | Select-Object Name -First 5
    Name
    ----
    Assets
    localization
    MEIPreload
    resources
    89.0.4447.38.manifest

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    89.0.4447.38.exe
    UpdateOpera.ps1

    Install Opera browser to 'C:\ProgramData\Opera' and save its setup installer to the current directory.
#>
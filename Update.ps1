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
    $InstallLocation = "${Env:ProgramData}\Vivaldi",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (Get-Item -LiteralPath $_).PSDrive.Name -iin 
        @((Get-PSDrive -PSProvider FileSystem).Name)
    })] [string]
    $SaveTo = $PSScriptRoot
)

& {
    $BaseNameLocation = "$InstallLocation\vivaldi"
    $NameLocation = "$BaseNameLocation.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        $(Try {
            (Invoke-WebRequest 'https://vivaldi.com/download/' -Verbose:$False).Links.href -like '*.exe' | 
            Select-Object @{
                Name = 'Version'
                Expression = {
                    [void] ($_ -match "Vivaldi\.(?<Version>(\d+\.){3}\d+)$(If((Get-ExecutableType $NameLocation) -eq 'x64'){ '\.x64' })\.exe$")
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
    $SoftwareName = 'Vivaldi'
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
        Set-ChromiumVisualElementsManifest "$BaseNameLocation.VisualElementsManifest.xml" '#EF3939'
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect 'vivaldi' $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $InstallerVersion installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Vivaldi browser software.
.DESCRIPTION
    The script installs or updates Vivaldi browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Vivaldi.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Vivaldi -ErrorAction SilentlyContinue

    PS > .\UpdateVivaldi.ps1 -InstallLocation C:\ProgramData\Vivaldi -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Vivaldi | Select-Object Name
    Name
    ----
    5.3.2679.68
    update_notifier.exe
    vivaldi.exe
    vivaldi.VisualElementsManifest.xml
    vivaldi_proxy.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    5.3.2679.68.exe
    UpdateVivaldi.ps1

    Install Vivaldi browser to 'C:\ProgramData\Vivaldi' and save its setup installer to the current directory.
#>
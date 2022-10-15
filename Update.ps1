[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Umbrello",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $IsVerbose = $VerbosePreference -ine 'SilentlyContinue'
    $NameLocation = "$InstallLocation\bin\umbrello.exe"
    $SoftwareName = "Umbrello"
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        Try {
            Get-DownloadInfo -PropertyList @{
                OSArch = Get-ExecutableType $NameLocation
            } -From Umbrello 
        }
        Catch { }
    $InstallerVersion = ($UpdateInfo ?? $(
        (Get-ChildItem $SaveTo).Name.Where({ $_ }) |
        ForEach-Object {
            If ($_ -match '^umbrello_(?<Version>(\d+\.){2}\d+-\d+)\.exe$') {
                [pscustomobject] @{
                    RawVersion = [version] ($Matches.Version -replace '-','.')
                    Version = $Matches.Version
                }
            }
        } | Sort-Object RawVersion -Descending -Top 1
    )).Version
    Try {
        $UpdateModule =
            @{
                Path = $NameLocation
                SaveTo = $SaveTo
                Version = $InstallerVersion
                Description = $SoftwareName
                SoftwareName = $SoftwareName
            } | ForEach-Object { New-RegCliUpdate @_ }
        & $UpdateModule {
            Function Script:Get-ExecutableVersion {
                [CmdletBinding()]
                [OutputType([version])]
                Param ()
                Return ([version] ((Test-Path $Script:InstallPath) ? 
                (Invoke-Expression "((. $Script:InstallPath --version | Where-Object { `$_ -like 'Umbrello*'}) -replace ' ' -split ':')[-1]"):$Null))
            }
            Remove-Variable -Name 'VERSION_PREINSTALL' -Force -Scope Script
            Set-Variable -Name 'VERSION_PREINSTALL' -Value (Get-ExecutableVersion) -Option ReadOnly -Scope Script
        }
        $UpdateModule | Import-Module -Verbose:$False -Force
        $UpdateInfo.Where({ $_ }) | Start-InstallerDownload -Verbose:$IsVerbose
        Remove-InstallerOutdated -UsePrefix -Verbose:$IsVerbose
        New-Item $InstallLocation -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        If ((Get-ExecutableVersion) -lt (Get-InstallerVersion)) {
            Compress-Archive $InstallLocation -DestinationPath "${Env:TEMP}\Umbrello_$(Get-Date -Format 'yyMMddHHmm').zip" 2>&1 | Out-Null
            Get-ChildItem $InstallLocation -ErrorAction SilentlyContinue |
            Remove-Item -Recurse
            Expand-Installer (Get-InstallerPath) $InstallLocation
        }
        Set-ChromiumShortcut $NameLocation $SoftwareName
        If (!(Test-InstallOutdated -CompareInstalls)) { Write-Verbose "$SoftwareName $(Get-ExecutableVersion) installation complete." }
    } 
    Catch { }
    Finally { $UpdateModule.Where({ $_ }) | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Umbrello UML Modeller.
.DESCRIPTION
    The script installs or updates Umbrello UML Modeller on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the console app.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Umbrello.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Umbrello -ErrorAction SilentlyContinue

    PS > .\UpdateUmbrello.ps1 -InstallLocation C:\ProgramData\Umbrello\ -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Umbrello\bin\ | Where-Object Name -Like 'umbrello*' | Select-Object Name
    Name
    ----
    umbrello.exe

    PS > Get-ChildItem -Recurse | Select-Object Name
    Name
    ----
    umbrello_2.32.0.exe
    UpdateUmbrello.ps1

    Install Umbrello to 'C:\ProgramData\Umbrello' and save its setup installer to the current directory.
#>
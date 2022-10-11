[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\SWI-Prolog",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $IsVerbose = $VerbosePreference -ine 'SilentlyContinue'
    $NameLocation = "$InstallLocation\bin\swipl.exe"
    $SoftwareName = "SWI Prolog"
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        Try {
            Get-DownloadInfo -PropertyList @{
                OSArch = Get-ExecutableType $NameLocation
            } -From SWIProlog 
        }
        Catch { }
    $InstallerVersion = ($UpdateInfo ?? $(
        (Get-ChildItem $SaveTo).Name.Where({ $_ }) |
        ForEach-Object {
            If ($_ -match '^swi_prolog_(?<Version>(\d+\.){2}\d+-\d+)\.exe$') {
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
                "$(((. $Script:InstallPath --version) -split ' ')[2]).1":$Null))
            }
            Remove-Variable -Name 'VERSION_PREINSTALL' -Force -Scope Script
            Set-Variable -Name 'VERSION_PREINSTALL' -Value (Get-ExecutableVersion) -Option ReadOnly -Scope Script
        }
        $UpdateModule | Import-Module -Verbose:$False -Force
        $UpdateInfo.Where({ $_ }) | Start-InstallerDownload -Verbose:$IsVerbose
        Remove-InstallerOutdated -UsePrefix -Verbose:$IsVerbose
        New-Item $InstallLocation -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        If ((Get-ExecutableVersion) -lt (Get-InstallerVersion)) {
            Compress-Archive $InstallLocation -DestinationPath "${Env:TEMP}\SWIProlog_$(Get-Date -Format 'yyMMddHHmm').zip" 2>&1 | Out-Null
            Get-ChildItem $InstallLocation -ErrorAction SilentlyContinue |
            Remove-Item -Recurse
            Expand-Installer (Get-InstallerPath) $InstallLocation
        }
        Set-ChromiumShortcut ($NameLocation -replace '.exe','-win.exe') $SoftwareName
        If (!(Test-InstallOutdated -CompareInstalls)) { Write-Verbose "$SoftwareName $(Get-ExecutableVersion) installation complete." }
    } 
    Catch { }
    Finally { $UpdateModule.Where({ $_ }) | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates SWI Prolog for programming logic.
.DESCRIPTION
    The script installs or updates SWI Prolog for programming logic on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the console app.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\SWI-Prolog.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\SWI-Prolog -ErrorAction SilentlyContinue

    PS > .\UpdateSWIProlog.ps1 -InstallLocation C:\ProgramData\SWI-Prolog\ -SaveTo .

    PS > Get-ChildItem C:\ProgramData\SWI-Prolog\bin\ | Where-Object Name -Like 'swipl*' | Select-Object Name
    Name
    ----
    swipl-ld.exe
    swipl-win.exe
    swipl.exe
    swipl.home

    PS > Get-ChildItem -Recurse | Select-Object Name
    Name
    ----
    SWI-Prolog
    UpdateSWIProlog.ps1
    swi_prolog_8.4.3-1.exe

    Install SWI Prolog to 'C:\ProgramData\SWI-Prolog' and save its setup installer to the current directory.
#>
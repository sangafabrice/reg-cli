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
    $SaveTo = "$SaveTo\SWI-Prolog"
    $SoftwareName = "SWI Prolog"
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        Try {
            Get-DownloadInfo -PropertyList @{
                OSArch = Get-ExecutableType $NameLocation
            } -From SWIProlog 
        }
        Catch { }
    New-Item $SaveTo -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
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
                Path = $InstallLocation
                SaveTo = $SaveTo
                Version = $InstallerVersion
                Description = $SoftwareName
                SoftwareName = $SoftwareName
            } | ForEach-Object { New-RegCliUpdate @_ }
        & $UpdateModule {
            Param($NameLocation)
            Set-Variable NameLocation $NameLocation -Scope Script
            Function Script:Get-ExecutableVersion {
                [CmdletBinding()]
                [OutputType([version])]
                Param ()
                Return ([version] ((Test-Path $NameLocation) ? 
                "$(((. $NameLocation --version) -split ' ')[2]).1":$Null))
            }
                            
        } $NameLocation
        $UpdateModule | Import-Module -Verbose:$False -Force
        $UpdateInfo.Where({ $_ }) | Start-InstallerDownload -Verbose:$IsVerbose
        Write-Verbose 'Delete outdated installers...'
        Get-ChildItem $SaveTo |
        Remove-Item -Exclude (Get-Item (Get-InstallerPath)).Name
        New-Item $InstallLocation -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        $VERSION_PREINSTALL = Get-ExecutableVersion
        If ($VERSION_PREINSTALL -lt (Get-InstallerVersion)) {
            Compress-Archive $InstallLocation -DestinationPath "${Env:TEMP}\SWIProlog_$(Get-Date -Format 'yyMMddHHmm').zip" 2>&1 | Out-Null
            Get-ChildItem $InstallLocation -ErrorAction SilentlyContinue |
            Remove-Item -Recurse
            Expand-Installer (Get-InstallerPath) $InstallLocation
        }
        Set-ChromiumShortcut ($NameLocation -replace '.exe','-win.exe') $SoftwareName
        If ($VERSION_PREINSTALL -le (Get-ExecutableVersion)) { Write-Verbose "$SoftwareName $InstallerVersion installation complete." }
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
[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\MSEdge",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $BaseNameLocation = "$InstallLocation\msedge"
    $NameLocation = "$BaseNameLocation.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        Get-DownloadInfo -PropertyList @{ OSArch = (Get-ExecutableType $NameLocation) } -From MSEdge |
        Where-Object {
            @($_.Version,$_.Link,$_.Name) |
            ForEach-Object { $_ -notin @($Null, '') }
        }
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Microsoft Edge'
    $InstallerDescription = "$SoftwareName Installer"
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
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        Switch ($UpdateInfo) { {$_.Count -gt 0}
        { Start-InstallerDownload $_.Link -Name $_.Name -Force -Verbose:$VerbosePreferenceBool } }
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation -Verbose:$VerbosePreferenceBool
        Set-ChromiumVisualElementsManifest "$BaseNameLocation.VisualElementsManifest.xml" '#173A73'
        Set-ChromiumShortcut $NameLocation
        Edit-TaskbarShortcut $NameLocation
        Set-BatchRedirect 'msedge' $NameLocation
        #Region: Set shell verb to open a PDF file as an MSEdge app
        @{
            Path = 'Registry::HKEY_CLASSES_ROOT\MSEdgePDF\shell\open\command'
            Name = '(default)'
            Value = '"' + $NameLocation + '" --app="%1"'
            Force = $True
        } | ForEach-Object { Set-ItemProperty @_ }
        #EndRegion
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $(Get-InstallerVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Microsoft Edge browser software.
.DESCRIPTION
    The script installs or updates Microsoft Edge browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\MSEdge.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\MSEdge -ErrorAction SilentlyContinue

    PS > .\UpdateMSEdge.ps1 -InstallLocation C:\ProgramData\MSEdge -SaveTo .

    PS > Get-ChildItem C:\ProgramData\MSEdge | Select-Object Name -First 5
    Name
    ----
    BHO
    EBWebView
    edge_feedback
    Extensions
    identity_proxy
    Locales

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    103.0.1264.49.exe
    UpdateMSEdge.ps1

    Install MSEdge browser to 'C:\ProgramData\MSEdge' and save its setup installer to the current directory.
#>
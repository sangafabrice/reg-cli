[CmdletBinding()]
param (
    [AllowNull()]
    [psobject] $UpdateInfo,
    [string] $NameLocation,
    [string] $SaveTo,
    [string] $SoftwareName,
    [string] $InstallerDescription,
    [string] $BatchRedirectName,
    [hashtable] $VisualElementManifest,
    [switch] $SkipSslValidation
)

& {
    $IsVerbose = $VerbosePreference -ine 'SilentlyContinue'
    $InstallerVersion = [version] $UpdateInfo.Version
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerVersion $SaveTo $InstallerDescription }
    Try {
        $UpdateModule =
            New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
            Import-Module -Verbose:$False -Force -PassThru
        $UpdateInfo | Start-InstallerDownload -Verbose:$IsVerbose -Force:$SkipSslValidation
        Remove-InstallerOutdated -Verbose:$IsVerbose
        Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation -Verbose:$IsVerbose
        Set-ChromiumVisualElementsManifest "$($VisualElementManifest.Name).VisualElementsManifest.xml" $VisualElementManifest.RGBColor
        Set-ChromiumShortcut $NameLocation
        Set-BatchRedirect $BatchRedirectName $NameLocation
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $(Get-ExecutableVersion) installation complete." }
    } 
    Finally { Remove-Module $UpdateModule -Verbose:$False }
}
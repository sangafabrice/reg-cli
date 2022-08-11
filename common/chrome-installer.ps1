[CmdletBinding()]
param (
    [AllowNull()]
    [psobject] $UpdateInfo,
    [string] $NameLocation,
    [string] $SaveTo,
    [string] $SoftwareName,
    [string] $InstallerDescription,
    [string] $BatchRedirectName,
    [ValidateScript({ ForEach ($key in @('BaseNameLocation','HexColor')) { $_.ContainsKey($key) } })]
    [hashtable] $VisualElementManifest,
    [switch] $SkipSslValidation
)

& {
    $IsVerbose = $VerbosePreference -ine 'SilentlyContinue'
    $InstallerVersion = [version] $UpdateInfo.Version
    If (!$UpdateInfo) { $InstallerVersion = Get-SavedInstallerVersion $SaveTo $InstallerDescription }
    Try {
        Switch ($NameLocation) {
            Default {
                $UpdateModule =
                    New-RegCliUpdate $_ $SaveTo $InstallerVersion $InstallerDescription |
                    Import-Module -Verbose:$False -Force -PassThru
                $UpdateInfo | Start-InstallerDownload -Verbose:$IsVerbose -Force:$SkipSslValidation
                Remove-InstallerOutdated -Verbose:$IsVerbose
                Expand-ChromiumInstaller (Get-InstallerPath) $_ -Verbose:$IsVerbose
                $VisualElementManifest |
                ForEach-Object { Set-ChromiumVisualElementsManifest "$($_.BaseNameLocation).VisualElementsManifest.xml" $_.HexColor }
                Set-ChromiumShortcut $_
                Set-BatchRedirect $BatchRedirectName $_
            }
        }
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $(Get-ExecutableVersion) installation complete." }
    } 
    Finally { Remove-Module $UpdateModule -Verbose:$False }
}
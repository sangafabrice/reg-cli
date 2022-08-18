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
    $UpdateInfo = $UpdateInfo.Where({ $_ })
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
                Set-ChromiumShortcut $_
                Set-BatchRedirect $BatchRedirectName $_
            }
        }
        $VisualElementManifest.Where({ $_ }) |
        ForEach-Object { Set-ChromiumVisualElementsManifest "$($_.BaseNameLocation).VisualElementsManifest.xml" $_.HexColor }
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $(Get-ExecutableVersion) installation complete." }
    }
    Catch { }
    Finally { Remove-Module $UpdateModule -Verbose:$False }
}
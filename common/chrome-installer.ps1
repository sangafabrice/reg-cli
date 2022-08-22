[CmdletBinding()]
Param (
    [AllowNull()]
    [psobject] $UpdateInfo,
    [string] $NameLocation,
    [string] $SaveTo,
    [string] $SoftwareName,
    [string] $InstallerDescription,
    [string] $BatchRedirectName,
    [ValidateScript({ ForEach ($key in @('BaseNameLocation','HexColor')) { $_.ContainsKey($key) } })]
    [hashtable] $VisualElementManifest,
    [switch] $SkipSslValidation,
    [switch] $UseTimestamp,
    [string] $Checksum
)

DynamicParam {
    If ($UseTimestamp) {
        $AttributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::New()
        $AttributeCollection.Add([System.Management.Automation.ParameterAttribute] @{ Mandatory = $False })
        $AttributeCollection.Add([System.Management.Automation.ValidateSetAttribute]::New('DateTime','SigningTime'))
        $ParamDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::New()
        $ParamDictionary.Add('TimestampType',[System.Management.Automation.RuntimeDefinedParameter]::New('TimestampType',[string],$AttributeCollection))
        $PSBoundParameters.TimestampType = 'DateTime'
        $ParamDictionary
    }
}
Process {
    $IsVerbose = $VerbosePreference -ine 'SilentlyContinue'
    $UpdateInfo = $UpdateInfo.Where({ $_ })
    $InstallerVersion = Try { [version] $UpdateInfo.Version } Catch { "$($UpdateInfo.Version)" }
    If (!$UpdateInfo) {
        $InstallerVersion = $(
            $InfoArguments = @{
                Path = $SaveTo
                Description = $InstallerDescription
            }
            If ($UseTimestamp) {
                Switch ($PSBoundParameters.TimestampType) {
                    'DateTime'    { Get-SavedInstallerLastModified @InfoArguments }
                    'SigningTime' { Get-SavedInstallerSigningTime @InfoArguments }
                }
                
            }
            Else { Get-SavedInstallerVersion @InfoArguments }
        )
    }
    Try {
        Switch ($NameLocation) {
            Default {
                $UpdateModule =
                    @{
                        Path = $_
                        SaveTo = $SaveTo
                        Version = $InstallerVersion
                        Description = $InstallerDescription
                        UseSigningTime = !$UpdateInfo -and $PSBoundParameters.TimestampType -ieq 'SigningTime'
                        Checksum = $(
                            If ($PSBoundParameters.ContainsKey('Checksum')) { $Checksum = $Null }
                            $Checksum
                        )
                    } | ForEach-Object { New-RegCliUpdate @_ } |
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
        If (!(Test-InstallOutdated -CompareInstalls:$UseTimestamp)) {
            Write-Verbose "$SoftwareName $(Get-ExecutableVersion) installation complete."
        }
    }
    Catch { }
    Finally { Remove-Module $UpdateModule -Verbose:$False }
}
End { }
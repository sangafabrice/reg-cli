[CmdletBinding()]
Param (
    [AllowNull()]
    [pscustomobject] $UpdateInfo,
    [string] $NameLocation,
    [string] $SaveTo,
    [string] $SoftwareName,
    [string] $InstallerDescription,
    [ValidateScript({ ForEach ($key in @('BaseNameLocation','HexColor')) { $_.ContainsKey($key) } })]
    [hashtable] $VisualElementManifest,
    [switch] $SkipSslValidation,
    [switch] $UseTimestamp,
    [string] $Checksum,
    [string] $Extension = '.exe',
    [switch] $UsePrefix,
    [ValidateSet('Chromium','Squirrel','NSIS')]
    [string] $InstallerType = 'Chromium',
    [switch] $ForceReinstall,
    [switch] $CompareInstalls
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
    If ($InstallerType -ieq 'NSIS') {
        $AttributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::New()
        $AttributeCollection.Add([System.Management.Automation.ParameterAttribute] @{ Mandatory = $False })
        $AttributeCollection.Add([System.Management.Automation.ValidateSetAttribute]::New(32,64))
        $ParamDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::New()
        $ParamDictionary.Add('NsisType',[System.Management.Automation.RuntimeDefinedParameter]::New('NsisType',[Int16],$AttributeCollection))
        $ParamDictionary
    }
}
Process {
    $IsVerbose = $VerbosePreference -ine 'SilentlyContinue'
    If (!$InstallerDescription) {
        If ($UsePrefix) {
            $InstallerDescription = "$(${SoftwareName}?.ToLower().Trim() -replace ' ','_')$(If(!!$SoftwareName){'_'})"
        }
        Else { $InstallerDescription = $SoftwareName }
    }
    $InstallerVersion =
        Try {
            $UpdateInfo.LastModified ?? ([version] $UpdateInfo.Version)
        } Catch { "$($UpdateInfo.Version)" }
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
                        SoftwareName = $SoftwareName
                        Extension = $Extension
                    } | ForEach-Object { New-RegCliUpdate @_ } |
                    Import-Module -Verbose:$False -Force -PassThru
                $UpdateInfo.Where({ $_ }) | Start-InstallerDownload -Verbose:$IsVerbose -Force:$SkipSslValidation
                Remove-InstallerOutdated -UsePrefix:$UsePrefix -Verbose:$IsVerbose
                $ExpandArgument = @{
                    Path = Get-InstallerPath
                    ApplicationPath = $_
                    Verbose = $IsVerbose
                } + ($ForceReinstall ? @{ ForceReinstall = $ForceReinstall }:@{})
                Switch ($InstallerType) {
                    'NSIS'  {
                        If ($PSBoundParameters.ContainsKey('NsisType')) 
                        { $ExpandArgument.ForceApp = $PSBoundParameters.NsisType }
                        Expand-NsisInstaller @ExpandArgument
                    }
                    'Squirrel'  { Expand-SquirrelInstaller @ExpandArgument }
                    Default { Expand-ChromiumInstaller @ExpandArgument }
                }
                Set-ChromiumShortcut $_
            }
        }
        $VisualElementManifest.Where({ $_ }) |
        ForEach-Object { Set-ChromiumVisualElementsManifest "$($_.BaseNameLocation).VisualElementsManifest.xml" $_.HexColor }
        If (!(Test-InstallOutdated -CompareInstalls:($CompareInstalls -or $UseTimestamp))) {
            Write-Verbose ("$SoftwareName $(Get-ExecutableVersion) installation complete." -replace ' 0\.0\.0\.0')
        }
    }
    Catch { }
    Finally { Remove-Module $UpdateModule -Verbose:$False }
}
End { }
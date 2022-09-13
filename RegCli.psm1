using module ".\class\RegCli.psm1"
using module ".\class\ValidationUtility.psm1"

Function Expand-Installer {
    [CmdletBinding()]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path,
        [AllowEmptyString()]
        [AllowNull()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $Destination
    )
    If (!$PSBoundParameters.ContainsKey('Destination')) { $Destination = $Null }
    [RegCli]::ExpandInstaller($Path, $Destination)
}

Function Expand-ChromiumInstaller {
    [CmdletBinding(PositionalBinding=$True)]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $ApplicationPath
    )
    [RegCli]::ExpandTypeInstaller($Path, $ApplicationPath, '*.7z')
}

Function Expand-SquirrelInstaller {
    [CmdletBinding(PositionalBinding=$True)]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $ApplicationPath
    )
    [RegCli]::ExpandTypeInstaller($Path, $ApplicationPath, '*.nupkg')
}

Function Expand-NsisInstaller {
    [CmdletBinding(PositionalBinding=$True)]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $ApplicationPath,
        [ValidateSet(32,64)]
        [Int16] $ForceApp
    )
    [RegCli]::ExpandTypeInstaller($Path, $ApplicationPath,
    '$PLUGINSDIR\app-{0}.*' -f ($PSBoundParameters.ContainsKey('ForceApp') ?
    ($ForceApp):([Environment]::Is64BitOperatingSystem ? '64':'32')))
}

Filter Get-ExecutableType {
    [CmdletBinding()]
    [OutputType([MachineType])]
    Param(
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $Path
    )
    [RegCli]::GetExeMachineType($Path)
}

Function Save-Installer {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [uri] $Url,
        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [AllowEmptyString()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $FileName
    )
    DynamicParam {
        If (![ValidationUtility]::ValidateSsl($Url)) {
            $AttributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::New()
            $AttributeCollection.Add([System.Management.Automation.ParameterAttribute] @{ Mandatory = $False })
            $ParamDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::New()
            $ParamDictionary.Add('SkipSslValidation',[System.Management.Automation.RuntimeDefinedParameter]::New('SkipSslValidation','switch',$AttributeCollection))
            $ParamDictionary
        }
    }
    Process {
        If (!($PSBoundParameters.ContainsKey('SkipSslValidation') -or
        [ValidationUtility]::ValidateSsl($Url))) { Throw 'The URL is not allowed.' }
        If ($PSBoundParameters.ContainsKey('FileName') -and
            ![string]::IsNullOrEmpty($FileName)) {
            [RegCli]::DownloadInstaller($Url, $FileName)
        } Else { [RegCli]::DownloadInstaller($Url) }
    }
    End { }
}

Filter Set-ChromiumShortcut {
    [CmdletBinding()]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path
    )
    [RegCli]::SetChromiumShortcut($Path)
}
Set-Alias -Name Set-SquirrelShortcut -Value Set-ChromiumShortcut
Set-Alias -Name Set-NsisShortcut -Value Set-ChromiumShortcut

Filter Edit-TaskbarShortcut {
    [CmdletBinding()]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path
    )
    [RegCli]::ResetTaskbarShortcutTargetPath($Path)
}

Filter Set-ChromiumVisualElementsManifest {
    [CmdletBinding(PositionalBinding=$True)]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $Path,
        [AllowEmptyString()]
        [AllowNull()]
        [string] $BackgroundColor
    )
    [RegCli]::SetChromiumVisualElementsManifest($Path, $BackgroundColor)
}

Function New-RegCliUpdate {
    [CmdletBinding(PositionalBinding=$True)]
    [OutputType([System.Management.Automation.PSModuleInfo])]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $Path,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $SaveTo,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateVersion($_) })]
        [psobject] $Version,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Description,
        [switch] $UseSigningTime,
        [AllowNull()]
        [string] $Checksum,
        [AllowNull()]
        [string] $SoftwareName,
        [ValidateNotNullOrEmpty()]
        [string] $Extension = '.exe'
    )
    If (!$PSBoundParameters.ContainsKey('Checksum')) { $Checksum = $Null }
    [RegCli]::NewUpdate($Path, $SaveTo, $Version, $Description, $UseSigningTime, $Checksum, $SoftwareName, $Extension)
}

Filter Test-InstallLocation {
    [CmdletBinding()]
    [OutputType([bool])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $Path,
        [ValidateScript({ $_ | ForEach-Object { [ValidationUtility]::ValidatePathString($_) } })]
        [string[]] $Exclude
    )
    If($Exclude.Count -le 0) { Return $True }
    (Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue).FullName -inotin $Exclude
}

Filter Test-InstallerLocation {
    [CmdletBinding()]
    [OutputType([bool])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path
    )
    Return $True
}

Filter Get-SavedInstallerVersion {
    [CmdletBinding()]
    [OutputType([version])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Description
    )
    [RegCli]::GetSavedInstallerInfo('Version', $Path, $Description)
}

Filter Get-SavedInstallerLastModified {
    [CmdletBinding()]
    [OutputType([datetime])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Description
    )
    [RegCli]::GetSavedInstallerInfo('DateTime', $Path, $Description)
}

Filter Get-SavedInstallerSigningTime {
    [CmdletBinding()]
    [OutputType([datetime])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Description
    )
    [RegCli]::GetSavedInstallerInfo('SigningTime', $Path, $Description)
}

Function Import-CommonScript {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSModuleInfo])]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
    [RegCli]::GetCommonScript($Name, "$PSScriptRoot\common")
}
#Requires -Version 7.0
#Requires -RunAsAdministrator
using module '.\class\Extended.IO.psm1'
using module '.\class\Install\Utility\RegCli.Install.psm1'
using module '.\class\Installer\RegCli.psm1'
using module '.\class\RegCli.psm1'

#Region : The list of RegCli basic functions. 
Filter Get-ExecutableType {
    [CmdletBinding()]
    [OutputType([MachineType])]
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [Extended.IO.Path]::IsPathValid($_) })]
        [System.IO.FileInfo] $Path
    )
    [RegCli.Install.Utility]::GetExeMachineType([Extended.IO.Path]::GetFullPath($Path))
    <#
    .SYNOPSIS
        Gets the machine type of a binary file.
    .DESCRIPTION
        Get-ExecutableType gets the machine type of a binary file. When the file does not exist, the function returns the architecture type of the Operating System.
    .PARAMETER Path
        Specified the path to the binary file.
    .EXAMPLE
        [Environment]::Is64BitOperatingSystem
        True
        PS > Get-ExecutableType 'C:\GoogleChrome\chrome.exe'
        x86
    #>
}

Function New-RCUpdate {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSModuleInfo])]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [Extended.IO.Path]::IsPathValid($_) })]
        [System.IO.FileInfo] $Path,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [Extended.IO.Path]::IsFileNameValid($_) })]
        [string] $Name,
        [ValidateNotNullOrEmpty()]
        [scriptblock] $Scriptblock = { ([System.IO.FileInfo] $args[0]).VersionInfo.FileVersionRaw },
        [ValidateScript({ [ValidationScript]::VersionTypeType($_) })]
        [psobject] $Version,
        [ValidateScript({ [ValidationScript]::ChecksumLength($_) })]
        [string] $Checksum,
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [System.IO.Directory]::Exists($_) })]
        [System.IO.DirectoryInfo] $SaveTo = $Env:TEMP,
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationScript]::DescriptionType($_) })]
        [psobject] $Description = $Name,
        [VersionType] $CompareBy = $Version -is [version] ? 'Version':'DateTime',
        [InstallerType] $Type = 'Chromium',
        [ValidateScript({ [ValidationScript]::Extension($_) })]
        [psobject] $Extension = '.exe'
    )
    [RegCli.Updater]::Create([Extended.IO.Path]::GetFullPath($Path), $Name, $Scriptblock, $Version, $Checksum, $SaveTo, $Description, $CompareBy, $Type, $Extension)
    <#
    .SYNOPSIS
        Returns a set of functions to help updating a software.
    .DESCRIPTION
        New-RCUpdate returns a module that is a set of functions performing operations to update a specified software.
    .PARAMETER Path
        Specified the path to the software executable.
    .PARAMETER Name
        Specifies the software name.
    .PARAMETER Scriptblock
        Specified the scriptblock that gets as input a path to an file system executable and returns its version.
        It defaults to the scriptblock that returns the FileVersionRaw property of a file system object.
    .PARAMETER Version
        Specifies the software name.
    .PARAMETER Checksum
        Specifies the installer checksum.
    .PARAMETER SaveTo
        Specifies the installer directory.
    .PARAMETER Description
        Specifies the installer description.
    .PARAMETER CompareBy
        Specifies the type of version to use to compare installers.
    .PARAMETER Type
        Specifies the installer type.
    .EXAMPLE
        $UpdaterModule = New-RCUpdate -Path 'C:\ProgramData\GoogleChrome\chrome.exe' -Name 'Google Chrome' -Version ([version]'105.0.5195.54') -SaveTo 'C:\Software' -Description 'Google Chrome Installer' -CompareBy Version -Type Chromium
        PS > $UpdateModule.ExportedFunctions.Keys
        Expand-Installer
        Set-ConsoleAppSymlink
        Set-ExecutableShortcut
        Set-VisualElementsManifest
        Start-InstallerDownload
        Test-InstallUpdate
    #>
}

Function Test-InstallerLocation {
    [CmdletBinding()]
    [OutputType([bool])]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo] $Path
    )
    [System.IO.Directory]::Exists($_)
    <#
    .SYNOPSIS
        Returns true whether the installer directory exists.
    .DESCRIPTION
        Test-InstallerLocation determines whether the specified literal path exists.
    .PARAMETER Path
        Specified the literal path to the installer directory.
    .EXAMPLE
        Test-InstallerLocation -Path 'C:\Software\GoogleChrome'
        True
    #>
}

Function Test-InstallLocation {
    [CmdletBinding()]
    [OutputType([bool])]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [Extended.IO.Path]::IsPathValid($_) })]
        [System.IO.DirectoryInfo] $Path,
        [System.IO.DirectoryInfo[]] $Exclude = @()
    )
    $Path = [Extended.IO.Path]::GetFullPath($Path)
    $Path -inotin (@($Exclude.ForEach{ Try { [Extended.IO.Path]::GetFullPath($_) } Catch { } }) + @((Get-ChildItem $PSScriptRoot -Directory -Recurse).ForEach{ $_.FullName })) -and !("$PSScriptRoot\".Contains("$Path\"))
    <#
    .SYNOPSIS
        Returns true whether the installation directory is not excluded directory.
    .DESCRIPTION
        Test-InstallLocation determines whether the specified literal path is not an excluded directory. By default, the excluded folders are the recursive children of the RegCli directory or any of its parent directory. 
    .PARAMETER Path
        Specified the literal path to the installation directory.
    .PARAMETER Exclude
        Specifies an extended list of literal paths that should be excluded as installation directory.
    .EXAMPLE
        Test-InstallLocation -Path 'C:\PowerShell\RegCli\class\' -Exclude 'C:\PowerShell\RegCli\class*'
        False
    .EXAMPLE
        Test-InstallLocation -Path 'C:\PowerShell\RegCli_1\class\' -Exclude 'C:\PowerShell\RegCli\class*'
        True
    #>
}

Function Test-InstallProcess {
    [CmdletBinding()]
    [OutputType([bool])]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [Extended.IO.Path]::IsPathValid($_) })]
        [System.IO.DirectoryInfo] $Path
    )
    ForEach ($Process in (Get-Process)) { If ($Process.Path -like "$([Extended.IO.Path]::GetFullPath($Path))\*") { Return $True } }
    Return $False
    <#
    .SYNOPSIS
        Returns true if the installation directory contains an opened executable.
    .DESCRIPTION
        Test-InstallLocation determines whether the specified the installation directory contains an opened executable.
    .PARAMETER Path
        Specified the literal path to the installation directory.
    .EXAMPLE
        Get-Process chrome | Select-Object Path -First 1
        Path
        ----
        C:\ProgramData\GoogleChrome\chrome.exe
        PS > Test-InstallProcess -Path 'C:\ProgramData\GoogleChrome\'
        True
    .EXAMPLE
        Get-Process chrome -ErrorAction SilentlyContinue | Select-Object Path -First 1
        PS > Test-InstallProcess -Path 'C:\ProgramData\GoogleChrome\'
        False
    #>
}
#EndRegion

#Region : The main function common to every installation.
Add-Type @'
public enum RegCliOption {
	Remove_Outdated_Installer,
	Remove_Outdated_Backup
}
'@

Function Start-RCUpdate {
    [CmdletBinding()]
    [OutputType([void])]
    Param (
        [AllowNull()]
        [PSCustomObject] $Info
    )
    $Info
}
#EndRegion
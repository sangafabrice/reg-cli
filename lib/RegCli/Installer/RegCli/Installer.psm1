#Requires -Version 7.0
#Requires -RunAsAdministrator
using module '..\..\System.Extended.IO'
using module '..\..\PowerShell.ValidationScript'

Class Installer {
    # Installer is the type that describes a file system installer.

    # Hidden property that specifies the path of the installer.
    # Path is a read-only accessor property to get the path of the installer.
    Hidden [string] $_path = $($This | Add-Member ScriptProperty 'Path' { $This._path })

    # Hidden property that specifies the version of the installer.
    # Version is a read-only accessor property to get the version of the installer.
    Hidden [object] $_version = $($This | Add-Member ScriptProperty 'Version' { $This._version })

    Installer([string] $Path, [object] $Version) {
        # Constructor that instantiates an installer object.

        # Get the validated full path from the $Path string.
        $Path = [System.Extended.IO.Path]::GetFullPath($Path)
        # Validate the extension of the $Path string.
        If (![ValidationScript]::Extension([System.IO.Path]::GetExtension($Path))) { Throw 'The installer extension is not valid.' }
        # Validate the type of the $Version object.
        If (![ValidationScript]::VersionTypeType($Version)) { Throw 'The version type is not valid.' }
        $This._path = $Path
        $This._version = $Version
    }

    # Allow to convert the installer object to its full path string.
    [string] ToString() { Return $This._path }
}
#Requires -Version 7.0
#Requires -RunAsAdministrator
using module '..\Extended.IO.psm1'

# The versioning types are different file system info properties that can be
# used to compare two different file system installers of the same software.
# The different versioning types are Version, the last modified date indexed
# as DateTime, and the signing time of the installer referred to as SigningTime.
Enum VersionType { Version; DateTime; SigningTime }

# The list of hash algorithms with the string length of the output code.
Enum HashAlgorithm { MD5 = 32; SHA1 = 40; SHA256 = 64; SHA512 = 128 }

# The list of installer types.
Enum InstallerType { Basic; Chromium; Squirrel; InnoSetup; NSIS }

Class AllowedList {
    # A set of lists to restrict values to few literals.

    # The list of allowed extensions
    Static [string[]] GetExtensions() { Return @('.exe', '.zip') }

    # The list of allowed powershell type of the specified version
    Static [string[]] GetPSVersionTypes() { Return @([version], [datetime]) }

    # The list of allowed hashcode string lengths
    Static [int[]] GetHashcodeLengths() { Return @([Enum]::GetValues([HashAlgorithm])) }
}

Class ValidationScript {
    # A set of operations that validates certain values.

    # Validate checksum length.
    Static [bool] ChecksumLength([string] $Checksum) { Return $Checksum.Length -in [AllowedList]::GetHashcodeLengths() -and $Checksum -imatch '^[0-9A-F]+$' }

    # Validate the type of the version type.
    Static [bool] VersionTypeType([psobject] $Version) { Return ${Version}?.GetType() -in [AllowedList]::GetPSVersionTypes() }

    # Validate the extension of the installer.
    Static [bool] Extension([string] $Extension) { Return $Extension -in [AllowedList]::GetExtensions() }

    # Validate installer description type and default value.
    Static [bool] DescriptionType([psobject] $Description) { Return $Description -is [string] -or ($Description -is [hashtable] -and $Description.Value) }
}

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
        $Path = [Extended.IO.Path]::GetFullPath($Path)
        # Validate the extension of the $Path string.
        If ([System.IO.Path]::GetExtension($Path) -inotin [AllowedList]::GetExtensions()) { Throw 'The installer extension is not valid.' }
        # Validate the type of the $Version object.
        If (${Version}?.GetType() -inotin [AllowedList]::GetPSVersionTypes()) { Throw 'The version type is not valid.' }
        $This._path = $Path
        $This._version = $Version
    }

    # Allow to convert the installer object to its full path string.
    [string] ToString() { Return $This._path }
}
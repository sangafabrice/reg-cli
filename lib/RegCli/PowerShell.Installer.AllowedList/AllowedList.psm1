#Requires -Version 7.0
#Requires -RunAsAdministrator

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
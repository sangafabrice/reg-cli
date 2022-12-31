#Requires -Version 7.0
#Requires -RunAsAdministrator
using module '..\PowerShell.Installer.AllowedList'

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

    # Validate hex colors
    Static [bool] HexColor([string] $Color) { Return $Color -match '#[0-9A-F]{6}' }
}
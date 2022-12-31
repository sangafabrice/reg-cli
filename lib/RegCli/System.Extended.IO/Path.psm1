#Requires -Version 7.0
#Requires -RunAsAdministrator

# The private copy of the input unvalidated file system path to the Path class operation.
[string] $Script:mem_path = ''

Function Script:Reset-MemoryPath {
    # Reinitialize the private values $mem_full_path to null and $is_mem_path_valid to false.

    # The private copy of the full path of the $mem_path if it is valid.
    # It is null when the $mem_path value is empty, null or invalid. 
    [psobject] $Script:mem_full_path = $Null
    # The private boolean flag that acknowledges that $mem_path is a valid path,
    # and returns false otherwise. 
    [bool] $Script:is_mem_path_valid = $False
}

# Initialize $mem_full_path and $is_mem_path_valid.
Reset-MemoryPath

# Normalize the path without validation.
Function Script:Set-NormalPath { $args[0].Value = $args[0].Value -replace '/','\' -replace '(^[^:]+:)','$1\' -replace '([^:^])\\+$','$1' -replace '\\+','\' }

Class Path {
    # Performs operations on String instances that contains file system path information.
    # The operations are performed in a manner specific to Windows platforms and at a local level.
    # The specified path or file name string may be pointing to an unexisting file system object.

    Static [string] GetFullPath([string] $Path) {
        # Returns the validated Windows absolute path of the specified path string.
        # Throws an error if the path string contains invalid characters or an unexisting root drive.

        Set-NormalPath ([ref] $Path)
        # The path is not valid if it is empty or null.
        If (!$Path) {
            $Script:mem_path = ''
            Reset-MemoryPath
            Throw 'The installer path is not valid. It is either empty or null.'
        }
        $ErrorMessage = 'The installer path is not valid. It may contain invalid characters or its root does not exist.'
        # If the path is equal to the memorized path, return the saved full path or throw an error.
        If ($Path -ieq $Script:mem_path) { Return $Script:mem_full_path ?? $(Throw $ErrorMessage) }
        # Copy the path to $mem_path.
        $Script:mem_path = $Path
        # If the path string is rooted, checks if its drive name matches an existing file system PSDrive.
        # Replaces the PS drive name by its root path string and modify the value of the input path string.
        If ($Path -imatch '(?<Drive>^[^:]+):[^:]*$') {
            $DriveName = $Matches.Drive
            $Roots = @{}
            (Get-PSDrive -PSProvider FileSystem).Where{ $_.Name -ieq $DriveName }.ForEach{ $Roots.$($_.Name) = $_.Root -replace '\\$' }
            If ($Roots.Count) { $Path = $Path -replace "${DriveName}:",$Roots.$DriveName }
        }
        # If the path string is not rooted, change its value to its unvalidated full path string.
        # Splits the path in 2, the first part is the drive name and the second is the path string relative to the root.
        # Test the root path string and test if the relative path string does not contain invalid path characters.
        $Path = [System.IO.Path]::GetFullPath($Path)
        $PathParts = $Path -split ':',2
        If ((Test-Path "$(${PathParts}?[0]):\") -and ${PathParts}?[-1] -inotmatch '"|<|>|\||:|\*|\?') {
            $Script:mem_full_path = $Path
            $Script:is_mem_path_valid = $True
            Return $Path
        }
        Reset-MemoryPath
        Throw $ErrorMessage
    }

    Static [bool] IsPathValid([string] $Path) {
        # Returns true if the specified path string does not contain invalid characters and its root is an existing PSDrive.
        
        Set-NormalPath ([ref] $Path)
        # If the path is equal to the memorized path, return the validation flag.
        If ($Path -ieq $Script:mem_path) { Return $Script:is_mem_path_valid }
        Return $(Try { [Path]::GetFullPath($Path) } Catch { $False })
    }

    # Returns true if the specified path string list does not contain invalid paths.
    Static [bool] IsPathValid([string[]] $PathList) { Return $PathList.Count -eq $PathList.Where({ ![Path]::IsPathValid($_)  }, 'Until').Count }

    # Returns true if the specified file name string does not contain invalid characters.
    Static [bool] IsFileNameValid([string] $FileName) { Return $FileName -notmatch '["<>\|:\*\?\\/]' }
}

# Do not export any member to keep the script variables ($mem_path, $mem_full_path, $is_mem_path_valid) 
# and function Reset-MemoryPath private to the script.
Export-ModuleMember
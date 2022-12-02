#Requires -Version 7.0
#Requires -RunAsAdministrator
using module '..\..\Extended.IO.psm1'

# The list of machine types.
Enum MachineType { x64 = 64; x86 = 32 }

Class Utility {
    # Utility is not meant to be instantiated and only declares static methods.
    # It is a set of help methods to handle a specified software install executable.

    Static [MachineType] GetExeMachineType([System.IO.FileInfo] $ExecutablePath) {
        # Get the machine type of a file system executable specified by its path.

        # If the specified file is a symlink, use the link target path as the executable path.
        If ($ExecutablePath.LinkType -like 'SymbolicLink') {
            $LinkTarget = $ExecutablePath.LinkTarget
            $ExecutablePath = [System.IO.FileInfo] ([System.IO.Path]::IsPathRooted($LinkTarget) ? ${LinkTarget}:"$($ExecutablePath.Directory)\$LinkTarget")
        }
        If ([System.IO.File]::Exists($ExecutablePath)) {
            # If the file specified exists.
            $PESignature = [Byte[]]::New(4)
            $MachineType = $PEHeaderOffset = [Byte[]]::New(2)
            $FileStream = [System.IO.FileStream]::New($ExecutablePath, 'Open', 'Read', 'ReadWrite')
            $FileStream.Position = 0x3c
            [void] $FileStream.Read($PEHeaderOffset, 0, 2)
            $FileStream.Position = [System.BitConverter]::ToUInt16($PEHeaderOffset, 0)
            [void] $($FileStream.Read($PESignature, 0, 4); $FileStream.Read($MachineType, 0, 2))
            $FileStream.Close()
            Switch ([System.BitConverter]::ToUInt16($MachineType, 0))
            { 0x8664 { Return [MachineType]::x64 } 0x14c { Return [MachineType]::x86 } }
        }
        # If the file specified does not exist, return the OS architecture type.
        Return $([Environment]::Is64BitOperatingSystem ? ([MachineType]::x64):([MachineType]::x86))
    }

    Static [scriptblock] SetExeShortcut([System.IO.FileInfo] $ExecutablePath) {
        # Get the scriptblock that creates a shortcut link of a targetted application
        # to '%ProgramData%\Microsoft\Windows\Start Menu\Programs\'.

        Return {
            [CmdletBinding()]
            Param (
                [ValidateNotNullOrEmpty()]
                [ValidateScript({ [Extended.IO.Path]::IsFileNameValid($_) })]
                [string] $Name
            )
            Try {
                $Private:ShortcutItem = (New-Object -ComObject 'WScript.Shell').CreateShortcut("${Env:ProgramData}\Microsoft\Windows\Start Menu\Programs\$(
                $PSBoundParameters.ContainsKey('Name') ? ${Name}:(Get-Culture).TextInfo.ToTitleCase($($Script:ExecutablePath.VersionInfo.ForEach{ $_.FileDescription ? ($_.FileDescription):($_.ProductName) }))).lnk")
                $ShortcutItem.TargetPath = "$Script:ExecutablePath"
                $ShortcutItem.WorkingDirectory = "$($Script:ExecutablePath.Directory)"
                $ShortcutItem.Save()
            }
            Catch { }
            <#
            .SYNOPSIS
                Sets shortcut link with a specified name.
            .DESCRIPTION
                The command sets the shortcut link of a targetted executable with a specified name.
                If the name is not specified, the name of the link defaults to the target file system description.
            .PARAMETER Name
                Specifies the name of the shortcut link.
            .EXAMPLE
                $SymLink = "${Env:LOCALAPPDATA}\Microsoft\WindowsApps\yq.exe"
                PS > $Target = 'C:\Software\yq_windows_amd64.exe'
                PS > ${Function:Set-SymLink} = [Utility]::SetConsoleAppSymlink($SymLink)
                PS > Set-SymLink -Target $Target
                PS > Get-Item $SymLink | Select-Object LinkType,LinkTarget
                LinkType     LinkTarget
                --------     ----------
                SymbolicLink C:\Software\yq_windows_amd64.exe
            #>
        }.GetNewClosure()
    }

    Static [scriptblock] SetConsoleAppSymlink([System.IO.FileInfo] $ExecutablePath) {
        # Get the scriptblock that creates a symbolic link of a targetted console application
        # to a specified location $ExecutablePath.

        $ExecutableDirectory = [System.IO.Path]::GetDirectoryName($ExecutablePath)
        $Null = New-Item $ExecutableDirectory -ItemType Directory -Force -ErrorAction SilentlyContinue
        Return {
            [CmdletBinding()]
            Param (
                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [ValidateScript({ [System.IO.File]::Exists($_) })]
                [System.IO.FileInfo] $Target
            )
            If ($Script:ExecutableDirectory -ieq "$($Target.Directory)") { Move-Item "$Target" "$Script:ExecutablePath" -Force -ErrorAction SilentlyContinue } 
            Else { $Null = New-Item "$Script:ExecutablePath" -Value "$Target" -ItemType SymbolicLink -Force -ErrorAction SilentlyContinue }
            <#
            .SYNOPSIS
                Sets symlink with a specified target.
            .DESCRIPTION
                The command sets a symlink with a specified target.
                If the target directory is the same as the symlink, then rename the target to the symlink file name.
                The path of the symlink is determined at the scriptblock creation. 
            .PARAMETER Target
                Specifies the file system info of the target file.
            .EXAMPLE
                $SymLink = "${Env:LOCALAPPDATA}\Microsoft\WindowsApps\yq.exe"
                PS > $Target = 'C:\Software\yq_windows_amd64.exe'
                PS > ${Function:Set-SymLink} = [Utility]::SetConsoleAppSymlink($SymLink)
                PS > Set-SymLink -Target $Target
                PS > Get-Item $SymLink | Select-Object LinkType,LinkTarget
                LinkType     LinkTarget
                --------     ----------
                SymbolicLink C:\Software\yq_windows_amd64.exe
            #>
        }.GetNewClosure()
    }

    Static [scriptblock] SetChromiumVisualElementsManifest([System.IO.FileInfo] $ExecutablePath) {
        # Get the scriptblock that creates a visual element manifest of a targetted chromium application.

        $InstallLocation = [System.IO.Path]::GetDirectoryName($ExecutablePath)
        Return {
            [CmdletBinding()]
            Param(
                [Parameter(Mandatory)]
                [ValidateScript({ [Extended.IO.Path]::IsFileNameValid($_) })]
                [string] $Name,
                [Parameter(Mandatory)]
                [ValidateScript({ $_ -match '#[0-9A-F]{6}' })]
                [string] $BackgroundColor
            )
            $ErrorActionPreference = 'SilentlyContinue'
            ,@(Get-ChildItem "$Script:InstallLocation\*Logo.png" -Recurse) |
            ForEach-Object { $Pattern = "$Script:InstallLocation\" -replace '\\','\\'; @{ BigLogo = $_[0] -replace $Pattern; SmallLogo = $_[1] -replace $Pattern } } |
            ForEach-Object {
                Set-Content "$Script:InstallLocation\$Name.VisualElementsManifest.xml" -Value @"
<Application xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>
    <VisualElements
        ShowNameOnSquare150x150Logo='on'
        Square150x150Logo='$($_.BigLogo)'
        Square70x70Logo='$($_.SmallLogo)'
        Square44x44Logo='$($_.SmallLogo)'
        ForegroundText='light'
        BackgroundColor='$BackgroundColor'/>
</Application>
"@
            }
            <#
            .SYNOPSIS
                Sets the visual element manifest of a chromium app.
            .DESCRIPTION
                The command sets a symlink with a specified target.
                If the target directory is the same as the symlink, then rename the target to the symlink file name.
                The path of the symlink is determined at the scriptblock creation. 
            .PARAMETER Name
                Specifies the name of the manifest.
            .PARAMETER BackgroundColor
                Specifies the BackgroundColor attribute of the manifest xml file.
            .EXAMPLE
                ${Function:Set-VisualElementsManifest} = [Utility]::SetChromiumVisualElementsManifest('C:\ProgramData\GoogleChrome\chrome.exe')
                PS > Set-VisualElementsManifest -Name 'chrome' -BackgroundColor '#2D364C'
                PS > Get-Item 'C:\ProgramData\GoogleChrome\chrome.VisualElementsManifest.xml' | Select-Object Name
                Name
                ----
                chrome.VisualElementsManifest.xml
            #>
        }.GetNewClosure()
    }
}
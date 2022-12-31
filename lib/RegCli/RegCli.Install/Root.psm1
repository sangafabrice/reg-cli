#Requires -Version 7.0
#Requires -RunAsAdministrator
using module '..\System.Extended.IO'

Class Tester {
    # Tester is not meant to be instantiated and only declares static methods.
    # It is a set of help methods to test whether an installed software is updated.

    Static [scriptblock] Create([System.IO.FileInfo] $ExecutablePath, [scriptblock] $GetExecutableVersion) {
        # Get the scriptblock that tests whether the app is updated after installation.
        # $VERSION_PREINSTALL is the version of the application before installation or updating.
        # $ExecutablePath is the path to the executable that opens the software to update.
        # The path does not necessary exist.
        # $GetExecutableVersion is scriptblock that accepts one parameter that is the executable path
        # and returns the version of the software or returns $null when the path does not exist.
		
        $VERSION_PREINSTALL = [Tester]::convertfrom_version((& $GetExecutableVersion "$ExecutablePath"))
        Return {
            [CmdletBinding()]
            [OutputType([bool])]
            Param ()
            Return [Tester]::convertfrom_version((& ($Script:GetExecutableVersion) "$Script:ExecutablePath")) -gt $Script:VERSION_PREINSTALL
            <#
            .SYNOPSIS
                Tests if software is sucessfully updated.
            .DESCRIPTION
                The command tests if a software executable is updated since the last test.
            .EXAMPLE
                $yq_exe = "${Env:LOCALAPPDATA}\Microsoft\WindowsApps\yq.exe"
                PS > $scriptblock = { Try { ((. $args[0] --version) -split ' ')[-1] } Catch { } }
                PS > & $scriptblock $yq_exe
                PS > ${Function:Test-InstallUpdate} = [Tester]::Create($yq_exe, $scriptblock)
                PS > Test-InstallUpdate
                False
                PS > # Update yq
                PS > & $scriptblock $yq_exe
                4.26.1
                PS > Test-InstallUpdate
                True
                PS > Test-InstallUpdate
                False
                PS > # Update yq
                PS > & $scriptblock $yq_exe
                4.29.1
                PS > Test-InstallUpdate
                True
                PS > Test-InstallUpdate
                False
            #>
        }.GetNewClosure()
    }

    Static Hidden [version] convertfrom_version([psobject] $VersionString) {
        # Convert a version string to a version object which properties are not less than 0
        Return $($VersionString.Where({ $_ }).ForEach({
            $_ -is [string] ? $(
                Try {
                    [version] ((& {
                        Param ($VersionString)
                        Switch ($VersionString -replace '\.\.','.') { { $_ -eq $VersionString } { Return $_ } Default { & $MyInvocation.MyCommand.ScriptBlock $_ } }
                    } ($_ -replace '[^0-9\.]','.')) -replace '^\.' -replace '\.$')
                } Catch { }
            ):$_
        }).ForEach{ [version] (($_.Major,$_.Minor,$_.Build,$_.Revision | ForEach-Object { Switch ($_) { { $_ -lt 0 } { 0 } Default { $_ } } }) -join '.') })
    }
}

# The list of machine types.
Enum MachineType { x64 = 64; x86 = 32 }

Class Utility {
    # Utility is not meant to be instantiated and only declares static methods.
    # It is a set of help methods to handle a specified software executable.

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
                [ValidateScript({ [System.Extended.IO.Path]::IsFileNameValid($_) })]
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
                [ValidateScript({ [System.Extended.IO.Path]::IsFileNameValid($_) })]
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

	Static [bool] TestInstallerLocation([System.IO.DirectoryInfo] $InstallLocationPath, [System.IO.DirectoryInfo[]] $ExcludePathList) {
		# Return false if the specified installation path is not an excluded path.
		# An excluded path is defined by the main path and its parents.
		# The installation path and the excluded path strings must not end with '\' or '/' characters.
		
		# Return false if the path is an excluded path or one of its parents.
		ForEach ($Path in $ExcludePathList) { If ("$Path\".Contains("$InstallLocationPath\")) { Return $False } }
		# Return true if the path does not exist.
		If (![System.IO.Directory]::Exists($InstallLocationPath)) { Return $True }
		# Return false if the installation path can make changes to the module directory and subdirectories.
		# Get the module root folder from the Install Utility class module.
		$ModuleRoot = "$(([System.IO.DirectoryInfo] $PSScriptRoot).Parent.Parent.Parent)"
		# Initialize the event that is raised when a file within the modules directories is renamed.
		# The handle assign a truth value to RenamedFlag if the file with the event name as its name is renamed.
		$EvtName =
		([System.IO.FileSystemWatcher] $ModuleRoot).ForEach{
			$_.IncludeSubdirectories = $True
			$_.NotifyFilter = 'FileName'
			@{
				InputObject = $_
				EventName = 'Renamed'
				Action = { $RenamedFlag = $RenamedFlag -or [System.IO.Path]::GetFileName(($Event.SourceArgs)[1].OldName) -like $FlagFileName }
			} | ForEach-Object { (Register-ObjectEvent @_).Name }
			$_.EnableRaisingEvents = $True
		}
		$EvtActionModule = (Get-EventSubscriber -SourceIdentifier "$EvtName").Action.Module
		# Assign to FlagFileName the name of the event and build the FlagFileName and content.
		& $EvtActionModule { Set-Variable 'FlagFileName' $args[0] -Scope Script -Option Constant } $EvtName
		$NewNameSuffix = Get-Date -Format 'yyyMMddHHmmss'
		$FlagFileContent = "${ModuleRoot}:${EvtName}:${NewNameSuffix}:$(Get-Random)"
		# The list of modules directories and subdirectories which yields the list of FlagFile paths.
		$FlagFileNames = @('','lib','lib\RegCli','lib\RegCli\Installer','lib\RegCli\PowerShell.DynamicParameter','lib\RegCli\PowerShell.Installer.AllowedList','lib\RegCli\PowerShell.ValidationScript','lib\RegCli\RegCli.Install','lib\RegCli\System.Extended.IO','lib\RegCli\Installer\RegCli','lib\RegCli\Installer\RegCli.Installer').
		ForEach{
			$FlagFile = "$ModuleRoot\$_\$EvtName"
			$Null = New-Item $FlagFile -ItemType File -Force
			Set-Content $FlagFile $FlagFileContent
			$FlagFile
		}
		# Get the hashcode of the flag file.
		$FlagFileHash = (Get-FileHash $FlagFileNames[0] -Algorithm SHA512).Hash
		# Try to change the flag file from installation location even if it is a junction.
		# If a file is renamed then return false.
        $Return = $False
		$Return = (@($InstallLocationPath) + @(Get-ChildItem $InstallLocationPath -Directory -Recurse)).
        Where{ [System.IO.File]::Exists("$_\$EvtName") }.ForEach{ [System.IO.FileInfo] "$_\$EvtName" }.Where({
			(Get-FileHash "$_" -Algorithm SHA512).Hash -ieq $FlagFileHash -and
			$(
				Rename-Item "$_" "$($_.Name)-$NewNameSuffix" -Force -ErrorAction SilentlyContinue
				Rename-Item "$_-$NewNameSuffix" $_.Name -Force -ErrorAction SilentlyContinue
				& $EvtActionModule { $RenamedFlag }
			)
		}, 'First').Count -eq 0
		# Delete flag files and unregister event.
		Remove-Item $FlagFileNames
		Unregister-Event -SourceIdentifier "$EvtName" -ErrorAction SilentlyContinue
		Return $Return
	}
}

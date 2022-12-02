#Requires -Version 7.0
#Requires -RunAsAdministrator
using module '..\..\Extended.IO.psm1'
using module '..\..\Install\Utility\RegCli.Install.psm1'
using module '..\RegCli.psm1'

Set-Variable '7Z_DLL' "$PSScriptRoot\7z.dll" -Option Constant -ErrorAction SilentlyContinue
Set-Variable '7Z_EXE' "$PSScriptRoot\7z.exe" -Option Constant -ErrorAction SilentlyContinue
Set-Variable 'INNO_EXE' "$PSScriptRoot\innoextract.exe" -Option Constant -ErrorAction SilentlyContinue
Set-Variable 'DEPENDENCY' @($7Z_DLL,$7Z_EXE) -Option Constant -ErrorAction SilentlyContinue
Set-Variable 'DL_PATH' 'https://gist.githubusercontent.com/sangafabrice/9f866c5035c8d74201b8a76406d2100e/raw/35d9aea933b0e0a27cc74625fa612f56e7a81ca5' -Option Constant -ErrorAction SilentlyContinue

Class Expander {
    # Expander is not meant to be instantiated and only declares static methods.
    # It is a set of help methods to expand a specified application self-extracting installer
    # using 7zip and InnoExtract console apps.

    Static [scriptblock] Create([System.IO.FileInfo] $InstallerPath, [System.IO.FileInfo] $ExecutablePath, [scriptblock] $GetSoftwareVersion, [InstallerType] $InstallerType) {
        # Get the scriptblock that downloads an installer from a specified URL, verifies
        # the installer integrity with checksum or signature, and move the installer to the
        # $InstallerPath location, where the application is installed from.
        
		$Global:REG_CLI_OUTDATED_BACKUP = $Null
        ${Function:Expand-Installer} = "$(
            Switch ($InstallerType) {
                'NSIS' {
                    {
                        [CmdletBinding()]
                        Param([int] $Depth, [switch] $ForceReinstall, [ValidateSet(32,64)][Int16] $ForceApp)
                        [Expander]::ExpandTypeInstaller($Script:InstallerPath, $Script:ExecutablePath,
                        ('$PLUGINSDIR\app-{0}.*' -f ($PSBoundParameters.ContainsKey('ForceApp') ? ($ForceApp):([RegCli.Install.Utility]::GetExeMachineType($Script:ExecutablePath) -replace 'x' -replace '86','32'))),
                        $ForceReinstall, $Depth, $Script:GetSoftwareVersion, [ref] $Global:REG_CLI_OUTDATED_BACKUP)
                    }.GetNewClosure()
                    Break
                }
                Default {
                    $ArchivePattern = Switch ($_) { 'Basic' { $Null } 'Chromium' { '*.7z' } 'Squirrel' { '*.nupkg' } }
                    {
                        [CmdletBinding()]
                        Param([int] $Depth, [switch] $ForceReinstall)
                        [Expander]::ExpandTypeInstaller($Script:InstallerPath, $Script:ExecutablePath, $Script:ArchivePattern, $ForceReinstall, $Depth, $Script:GetSoftwareVersion, [ref] $Global:REG_CLI_OUTDATED_BACKUP)
                    }.GetNewClosure()
                    Break
                }
            }
        )" + "`n" + @'
<#
.SYNOPSIS
    Expands an installer.
.DESCRIPTION
    The command expands a specified installer and saves it to the installation directory.
.PARAMETER Depth
    Specifies the distance from the installation root directory to the install executable.
    0 means the executable is a child of the installation root.
.PARAMETER ForceReinstall
    For installation when the installed and the updated executable have the same version.
.PARAMETER ForceApp
    Specifies that the machine type to install regardless of the system architecture.
    Only available with NSIS installers.
.EXAMPLE
    ${Function:Expand-Installer} = [Expander]::Create('C:\Software\msedge_106.0.1370.52.exe','C:\ProgramData\MSEdge\msedge.exe',{ Param([AllowNull()][System.IO.FileInfo] $Executable) $Executable.VersionInfo.FileVersionRaw },'Chromium')
    PS > Get-ChildItem C:\ProgramData\MSEdge -ErrorAction SilentlyContinue
    PS > Expand-Installer -Depth 0
    PS > Get-ChildItem C:\ProgramData\MSEdge | Select-Object Name -First 5
    Name
    ----
    BHO
    EBWebView
    edge_feedback
    Extensions
    identity_proxy
    Locales
#>
'@
        Return ${Function:Expand-Installer}.GetNewClosure()
    }

    Static [void] ExpandInstaller([System.IO.FileInfo] $InstallerItem, [ref] $DestinationPath) {
        # Extract files from a specified self-extracting executable file system to a destination folder.
        # The executable is specified by $InstallerItem and $DestinationPath is the destination folder
        # that may or may not exist before this method is executed. If the destination folder is not defined
        # or null, it defaults to the $InstallerItem basename in the same directory. If the installer is an
        # InnoSetup installer, expand it with the innoextract.exe console application. Otherwise use 7zip.

        $DestPathString = $DestinationPath.Value
        $InstallerItem.ForEach{
            If ([string]::IsNullOrEmpty($DestPathString)) { $DestPathString = "$($_.Directory)\$($_.BaseName)" }
            If ([Expander]::is_inno_installer($_)) {
                [Expander]::download_dependency('innoextract')
                . "${Script:INNO_EXE}" --extract "$_" --output-dir "$DestPathString" --silent
            }
            Else { . "${Script:7Z_EXE}" x -aoa -o"$DestPathString" "$_" 2> $Null }
        }
        $DestinationPath.Value = (Resolve-Path $DestPathString -ErrorAction SilentlyContinue).Path
    }

    Static [void] ExpandInstaller([System.IO.FileInfo] $InstallerItem) { [Expander]::ExpandInstaller($InstallerItem, $Null) }
    Static [void] ExpandInstaller([System.IO.FileInfo] $InstallerItem, [string] $DestinationPath) { [Expander]::ExpandInstaller($InstallerItem, [ref] $DestinationPath) }

    Static [void] ExpandTypeInstaller([System.IO.FileInfo] $InstallerItem, [System.IO.FileInfo] $ExecutablePath, [string] $ArchivePattern, [bool] $ForceReinstall, [int] $Depth, [scriptblock] $GetSoftwareVersion, [ref] $ProgramBackup) {
        # Extracts files from a specified Type of installer $InstallerItem to the directory in which the
        # application executable location $ExecutablePath. The archive pattern helps identify the intermediate
        # archive after expanding the installer if it is there. The different $ArchivePattern: '*.7z' for most
        # chromium installers, '*.nupkg' for all nuget installers, '$PLUGINSDIR\app-64.*' or '$PLUGINSDIR\app-32.*'
        # for most NSIS installers. Other installers do not have intermediate archives. $ForceReinstall is used when
        # the version of the current install executable is the same as the update executable. $Depth is the distance
        # from the install root directory $ExeDir to the install executable. 0 means the install is a child of the root.
        # The scriptblock $GetSoftwareVersion is a function to retrieve the version of the software executable. The default is the
        # scriptblock to get the FileVersionRaw property of an install. The scriptblock must take a valid path string.

        # Get from the executable path, its name and base name,
        # and the installation directory of the software. The latter is created if it does not exist.
        $ExeBaseName = [System.IO.Path]::GetFileNameWithoutExtension(($ExeName = [System.IO.Path]::GetFileName($ExecutablePath)))
        ${Function:Get-InstallDirectory} = { If ($args[1] -ge 0) { & $MyInvocation.MyCommand.ScriptBlock ([System.IO.Path]::GetDirectoryName($args[0])) (--$args[1]) } Else { $args[0] } }
        $ExeDir = Get-InstallDirectory "$ExecutablePath" $Depth
        If (!"$ExeDir") { Throw 'The installation directory cannot be null.' }
        $Null = New-Item $ExeDir -ItemType Directory -ErrorAction SilentlyContinue
        $InstallerItem.ForEach{
            # Expand the installer to $UnzipPath
            $UnzipPath = $Null
            [Expander]::ExpandInstaller($_, [ref] $UnzipPath)
            Try {
                Push-Location $UnzipPath
                If ($ArchivePattern) {
                    # Expand the intermediate archive that contains the main executable.
                    (Get-Item ".\$ArchivePattern" | Select-Object -First 1).Where({ "$_" }).ForEach{
                        [Expander]::ExpandInstaller($_)
                        Remove-Item $_
                    }
                }
                # Get the main executable of the software.
                $UnzippedExePath = Get-ChildItem $ExeName -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                # Use the scriptblock $GetSoftwareVersion to get the version of the installed
                # executable and of the executable to install.
                ${Function:Get-SoftwareVersion} = $GetSoftwareVersion
                $ExeVersion = Get-SoftwareVersion "$ExecutablePath"
                $UnzExeVersion = Get-SoftwareVersion $UnzippedExePath
                If ($ForceReinstall ? $($UnzExeVersion -ge $ExeVersion):$($UnzExeVersion -gt $ExeVersion)) {
                    # Archive the outdated or current install to the %TEMP% directory.
					[string] $ProgramBackup.Value = "${Env:TEMP}\${ExeBaseName}_$(Get-Date -Format 'yyMMddHHmm').zip"
                    $Null =  . "${Script:7Z_EXE}" a -tzip $ProgramBackup.Value "$ExeDir\*" 2>&1
                    # Delete every file of the install root directory $ExeDir. Attempt to close any open executable
                    # or module that the install directory contains. The goal is to ease file removal.
                    (Get-Process).Where{ $_.Path -like "$ExeDir\*" }.ForEach{
                        Try { taskkill.exe /F /PID $_.Id /T 2>&1 | Out-Null }
                        Catch { Stop-Process $_ -Force -ErrorAction SilentlyContinue }
                        Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Get-ChildItem $ExeDir -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
                    # Move files from the unzipped directory to the installation directory.
                    Move-Item "$(Get-InstallDirectory $UnzippedExePath $Depth)\*" $ExeDir -Exclude '$*' -ErrorAction SilentlyContinue
                }
                Pop-Location
                Remove-Item $UnzipPath -Recurse
            }
            Catch { }
        }
    }

    Static Hidden [void] download_dependency([string] $DepCode) {
        # Download and install 7zip library and executable (7z.dll and 7z.exe) or innoextract console app.

        $DepProperties = Switch ($DepCode) {
            '7z' { @{ List = $Script:DEPENDENCY; GistBaseName = '7Zip' } }
            'innoextract' { @{ List = @($Script:INNO_EXE); GistBaseName = 'InnoExtract' } }
        }
        If ((Test-Path $DepProperties.List).Where({ $_ }).Count -lt $DepProperties.List.Count)
        { & ([scriptblock]::Create("$(Invoke-WebRequest "${Script:DL_PATH}/Download$($DepProperties.GistBaseName).ps1")")) $PSScriptRoot }
    }

    Static Hidden [string[]] get_zip_archive_list([System.IO.FileInfo] $InstallerItem) {
        # List files contained in the specified self extracting executable file system item.

        [Expander]::download_dependency('7z')
        $List = ((. $Script:7Z_EXE l $InstallerItem) -split "`n").Where({ $_ -like '-------------------*' }, 'SkipUntil')
        $List = $List | ForEach-Object { Try { $_.Substring($List[0].LastIndexOf(' ') + 1) } Catch { } } | Select-Object -Skip 1
        Return $($List[0..($List.Count - 3)])
    }

    Static Hidden [bool] is_inno_installer([System.IO.FileInfo] $InstallerItem) {
        # Check whether the installer is of InnoSetup type by checking whether the installer contains
        # a file named '[0]~' or '[0]'.

        Return [Expander]::get_zip_archive_list($InstallerItem).Where({ $_ -iin '[0]~','[0]' }, 'First')
    }
}
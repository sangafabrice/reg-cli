#Requires -Version 7.0
#Requires -RunAsAdministrator
using module '..\..\PowerShell.ValidationScript'
using module '..\..\PowerShell.DynamicParameter'
using module '..\..\PowerShell.Installer.AllowedList'
using module '..\..\System.Extended.IO'
using module '..\..\RegCli.Install'
using module '..\RegCli'

Class Downloader {
    # Downloader is not meant to be instantiated and only declares static methods.
    # It is a set of help methods to download a specified software installer

    Static [scriptblock] Create([System.IO.FileInfo] $InstallerPath) {
        # Get the scriptblock that downloads an installer from a specified URL, verifies
        # the installer integrity with checksum or signature, and move the installer to the
        # $InstallerPath location from where the application is installed.
        
        # The parent directory of the installer file system must exist.
        [System.IO.Path]::GetDirectoryName($InstallerPath).ForEach{ If (![System.IO.Directory]::Exists($_)) { Throw ('"{0}" does not exist.' -f $_) } }
        # Start building the args for get_downloader() scriptblock in a hashtable.
        # Set the file name of the downloaded resource in the Temp:\ directory.
        $InstallerName = [System.IO.Path]::GetFileName($InstallerPath)
        # The scriptblock to validate that the url starts with https for secure connexion.
        $ValidateSSL = { Param([uri] $Url) $Url.Scheme -ieq 'https' }
        Return {
            [CmdletBinding()]
            Param (
                [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                [ValidateNotNullOrEmpty()]
                [uri] $Link,
                [Parameter(ValueFromPipelineByPropertyName)]
                [ValidateNotNullOrEmpty()]
                [ValidateScript({ [ValidationScript]::ChecksumLength($_) })]
                [string] $Checksum
            )
            # The parameter -SkipSslValidation is only defined when the URL does not end with 'https'.
            DynamicParam { If (!(& $Script:ValidateSSL $Link)) { [DynamicParameter]::Create('SkipSslValidation', [switch]) } }
            Process {
                # Process only if the installer file system does not exist.
                If (![System.IO.File]::Exists($Script:InstallerPath)) {
                    # Validate URL or skip validation if the option is specified.
                    If (!($PSBoundParameters.ContainsKey('SkipSslValidation') -or (& $Script:ValidateSSL $Link))) { Throw 'The URL is not allowed.' }
                    ([Downloader]::download_installer($Link, $InstallerName)).Where{
                        # Validate the integrity of the installer file system with hashcode if -Checksum specified.
                        If ($PSBoundParameters.ContainsKey('Checksum')) { $Checksum -ieq (Get-FileHash "$_" ([HashAlgorithm] $Checksum.Length)).Hash }
                        # Validate the integrity of the installer file system with signature if -Checksum not specified.
                        Else { (Get-AuthenticodeSignature "$_").Status -ieq 'Valid' }
                        # Move downloaded installer from Temp:\ to the specified installer path when creating the function.
                    } | Move-Item -Destination "$Script:InstallerPath" -Force -ErrorAction SilentlyContinue
                }
            }
            <#
            .SYNOPSIS
                Downloads an installer.
            .DESCRIPTION
                The command downloads a specified installer and saves it to an existing local directory.
                The intermediate step in between downloading and saving is to check the integrity of the installer.
            .PARAMETER Link
                Specifies the installer resource location online.
            .PARAMETER Checksum
                Specifies the checksum code of the installer.
            .PARAMETER Force
                Specifies that SSL validation be skipped.
                It is a dynamic parameter that is only available when the URL does not start with https.
            .EXAMPLE
                ${Function:Start-InstallerDownload} = [Downloader]::Create('C:\Software\msedge_106.0.1370.52.exe')
                PS > Get-Item 'C:\Software\msedge_106.0.1370.52.exe' -ErrorAction SilentlyContinue
                PS > Start-InstallerDownload -Link 'http://msedge.b.tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/8cbf88e2-28a2-4799-ac29-870d1fb99308?P1=1667578561&P2=404&P3=2&P4=acd8ckzfGeXT1dmQzuCmWLWfkNnC7wF73mvbuot6AfxDDNxCon%2fv%2boaIHE78YRc6lAAyUoiCGXD%2bD8AFcf9wBw%3d%3d' -Name 'MicrosoftEdge_X64_106.0.1370.52.exe' -Force
                PS > Get-Item 'C:\Software\msedge_106.0.1370.52.exe' | Select-Object Name
                Name
                ----
                msedge_106.0.1370.52.exe
            #>
        }.GetNewClosure()
    }

    Static Hidden [System.IO.FileInfo] download_installer([uri] $InstallerUrl, [string] $InstallerName) {
        # Download resource and save it to Temp:\ directory
        
        Try {
            # Validate local installer name if it is a valid file system name
            If ([System.Extended.IO.Path]::IsFileNameValid($InstallerName)) {
                # Build path to local installer name in the Temp:\ directory and differentiated by date
                $Result = "${Env:TEMP}\$([system.IO.Path]::GetFileNameWithoutExtension($InstallerName))_$(Get-Date -Format 'yyMMddHHmmss')$([system.IO.Path]::GetExtension($InstallerName))"
                # Download from the specified URL to the installer path
                Start-BitsTransfer -Source "$InstallerUrl" -Destination $Result
                If (!$?) { Invoke-WebRequest -Uri "$InstallerUrl" -OutFile $Result }
                Return $Result
            }
        }
        Catch { }
        Return $Null
    }
}

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
					[System.IO.FileInfo] $ExeDirFiles = "$ExeDir\REG_CLI_FILES"
					# If the list of files REG_CLI_FILES exists, then list them in $ExeDirContent
					# Else list the files first, from the deepest to the lowest and
					# list the directories second from the deepest to the lowest in the hierarchy
					If ([System.IO.File]::Exists($ExeDirFiles) -and $ExeDirFiles.Length -gt 0) {
						$ExeDirContent = Get-Item (Get-Content "$ExeDirFiles") -ErrorAction SilentlyContinue
						$ExeList = $ExeDirContent.Where{ $_.Extension -ieq '.exe' }.ForEach{ "$_" }
						${Function:Test-ProcessPath} = { $args[0] -iin $Script:ExeList }.GetNewClosure()
					}
					Else {
						$InstallExeDirDirectories = @(Get-ChildItem $ExeDir -Recurse -Directory -ErrorAction SilentlyContinue)
						Try { [array]::Reverse($InstallExeDirDirectories) } Catch { }
						$ExeDirContent = @(Get-ChildItem $ExeDir -Recurse -File -ErrorAction SilentlyContinue) + $InstallExeDirDirectories
						${Function:Test-ProcessPath} = { $args[0] -like "$Script:ExeDir\*" }.GetNewClosure()
					}
					# Check if the install directory is not empty.
					If ($ExeDirContent.Where({ "$_" }, 'First')) {
						# Archive the outdated or current install to the %TEMP% directory.
						[string] $ProgramBackup.Value = "${Env:TEMP}\${ExeBaseName}_$(Get-Date -Format 'yyMMddHHmm').zip"
						$Null =  . "${Script:7Z_EXE}" a -tzip $ProgramBackup.Value "$ExeDir\*" 2>&1
						# Delete every file of the install root directory $ExeDir. Attempt to close any open executable
						# or module that the install directory contains. The goal is to ease file removal.
						(Get-Process).Where{ Test-ProcessPath $_.Path }.ForEach{
							Try { taskkill.exe /F /PID $_.Id /T 2>&1 | Out-Null }
							Catch { Stop-Process $_ -Force -ErrorAction SilentlyContinue }
						}
						ForEach ($File in $ExeDirContent) {
							If ([System.IO.Directory]::Exists($File) -and @(Get-ChildItem $File).Count -gt 0) { Continue }
							Remove-Item $File -ErrorAction SilentlyContinue
						}
					}
                    # Save the list of files and directories in the install location.
					$UnzippedExeDir = Get-InstallDirectory $UnzippedExePath $Depth
					$UnzippedExeDirDirectories =  @((Get-ChildItem $UnzippedExeDir -Name -Recurse -Directory).ForEach{ [System.Extended.IO.Path]::GetFullPath("$ExeDir\$_") })
					Try {
						Try { [array]::Reverse($UnzippedExeDirDirectories) } Catch { }
						Set-Content "$ExeDirFiles" (@((Get-ChildItem $UnzippedExeDir -Name -Recurse -File -Exclude '$*').ForEach{ [System.Extended.IO.Path]::GetFullPath("$ExeDir\$_") }) + $UnzippedExeDirDirectories)
					}
					Catch { }
					# Move files from the unzipped directory to the installation directory.
                    Move-Item "$UnzippedExeDir\*" $ExeDir -Exclude '$*' -ErrorAction SilentlyContinue
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

Class Selector {
    # Selector is not meant to be instantiated and only declares static methods.
    # It is a set of help methods to identify and select a specified application installer
    # file system items from a pool of saved installers. The idea is to avoid downloading
    # a version of an installer that is already saved locally.

    Static [scriptblock] Create([hashtable] $Description) {
        # Get the scriptblock that selects installer specified by a description.

        # Validate the description hashtable Value key value.
        If (!$Description.Value) { Throw 'The description value cannot be null or empty.' }
        # Declare selector scriptblocks to filter installers and properties.
        $SelectInstallerItem = [Selector]::get_filter()
        $SelectInstallerInfo = [Selector]::get_selector()
        Return {
            [CmdletBinding(DefaultParameterSetName='Latest')]
            [OutputType([Installer])]
            Param(
                [Parameter(Mandatory, ValueFromPipeline)]
                [ValidateNotNullOrEmpty()]
                [ValidateScript({ [System.IO.File]::Exists($_) })]
                [System.IO.FileInfo] $Item,
                [VersionType] $Type = 'Version',
                [Parameter(ParameterSetName='Latest')]
                [switch] $Latest,
                [Parameter(ParameterSetName='Checksum')]
                [ValidateScript({ [ValidationScript]::ChecksumLength($_) })]
                [string] $Checksum
            )
            # The parameter -FullList is only defined when -Latest or -Checksum is defined and it is reference variable.
            DynamicParam { If ($Latest -or $PSBoundParameters.ContainsKey('Checksum')) { [DynamicParameter]::Create('FullList', [ref]) } }
            Begin {
                # Initialize the variable that will contain the latest installer or the installer with a specified hashcode.
                $Output = $Null
                $IsChecksumParameterSet = $PSCmdlet.ParameterSetName -eq 'Checksum'
                # $Algorithm is the hash algorithm name generated from the specified checksum length
                If ($IsChecksumParameterSet) { $Algorithm = [HashAlgorithm] $Checksum.Length }
                # Initialize the full list reference value to an empty array.
                If ($PSBoundParameters.ContainsKey('FullList')) { $PSBoundParameters.FullList.Value = @() }
            }
            Process {
                If (!($IsChecksumParameterSet -and $Output)) {
                    ($Item | & $Script:SelectInstallerItem -Description $Script:Description | & $Script:SelectInstallerInfo -Type $Type).
                    ForEach{
                        # Add indexed installer full path to the reference variable specified by FullList parameter.
                        If ($PSBoundParameters.ContainsKey('FullList') -and ("$_" -inotin $PSBoundParameters.FullList.Value)) { $PSBoundParameters.FullList.Value += "$_" }
                        # Compare current installer item with the previous latest by Version if -Latest is specified.
                        If ($Latest) { $Output = ($Output && $_) | Sort-Object Version -Descending -Top 1 }
                        # Compare current installer hashcode with the hashcode specified by -FullList.
                        # Else return the indexed installer object.
                        ElseIf ($IsChecksumParameterSet) { If ($Checksum -ieq (Get-FileHash "$_" $Algorithm).Hash) { $Output = $_ } } Else { $_ }
                    }
                }
            }
            # Return the latest installer from the pool of saved intallers or the installer with a specified hashcode.
            End { $Output }
            <#
            .SYNOPSIS
                Selects installers indexed by description.
            .DESCRIPTION
                The command filters installer file system items with a specified file info property value.
                The later is referred to as the installer description.
                To get only the latest version of the items, use the switch parameter -Latest.
                To get the items that matches a specified checksum code, use the parameter -Checksum with the checksum specified.
                The parameters -Latest and -Checksum are mutually exclusive.
            .PARAMETER Item
                Specifies the file system info object.
            .PARAMETER Type
                Specifies the type of the object that is referred to as the version of the installer.
                The different versioning types are:
                Version of type [version],
                DateTime of type [datetime] that is the last modified date of the installer,
                SigningTime of type [datetime] that is the signing time of the installer.
            .PARAMETER Latest
                Specifies that only the latest version of the selected items.
            .PARAMETER Checksum
                Specifies that only the item with the specified checksum to be selected.
            .PARAMETER FullList
                Specifies the reference that saves the list of full paths of installers with the specified file info property value.
                It is a dynamic parameter that is available only when Latest or Checksum is defined.
            .EXAMPLE
                ${Function:Select-InstallerInfo} = [Selector]::Create(@{ Value = 'Google Chrome' })
                PS > Get-Item 'C:\Software\' | Select-InstallerInfo -Latest
                Path                           Version
                ----                           -------
                C:\Software\105.0.5195.54.exe  105.0.5195.54
            .EXAMPLE
                Get-Item 'C:\Software\' | Select-InstallerInfo -Checksum '591987CD7FB585AC01EB9A4EBDC69C4044E99976'
                Path                           Version
                ----                           -------
                C:\Software\104.0.5112.81.exe  104.0.5112.81
            .EXAMPLE
                Get-Item 'C:\Software\' | Select-InstallerInfo -Type DateTime
                Path                            Version
                ----                            -------
                C:\Software\103.0.5060.114.exe  7/2/2022 4:41:01 AM
                C:\Software\103.0.5060.134.exe  7/18/2022 10:16:56 PM
                C:\Software\104.0.5112.102.exe  8/16/2022 1:28:04 AM
                C:\Software\104.0.5112.81.exe   7/30/2022 7:37:12 PM
                C:\Software\105.0.5195.54.exe   8/24/2022 4:29:17 AM
            #>
        }.GetNewClosure()
    }

    Static [scriptblock] Create([string] $FileDescriptionValue) { Return [Selector]::Create(@{ Value = $FileDescriptionValue }) }

    Static Hidden [string] get_description([System.IO.FileInfo] $InstallerItem, [string] $PropertyName) {
        # Get the most descritive text of the application from the installer file properties.
        # $InstallerItem is the installer item that must exist on the file system.
        # $PropertyName is the version info property to retrieve from the installer file that
        # describes the most the application that is being installed.

        Return ($InstallerItem ?? $(Throw '$InstallerItem must not be null')).ForEach{
            # Return the version info property value when it is not empty nor null.
            # Otherwise return the signature subject if it is not null.
            # Otherwise return the file name of the installer item.
            ($_.VersionInfo.$($PropertyName.ForEach{ $_ ? ${_}:'FileDescription' }) | ForEach-Object { $_ ? ${_}:$Null }) ??
            (Get-AuthenticodeSignature "$_").SignerCertificate.Subject ?? $_.BaseName
        }
    }

    Static Hidden [scriptblock] get_filter() {
        # Get the scriptblock that runs the steppable pipeline that filters saved installer file
        # system items by their most descriptive property value returned by get_description().

        Return {
            [CmdletBinding()]
            [OutputType([System.IO.FileInfo])]
            Param(
                [Parameter(Mandatory, ValueFromPipeline)]
                [ValidateNotNullOrEmpty()]
                [ValidateScript({ [System.IO.File]::Exists($_) })]
                [System.IO.FileInfo] $Item,
                [Parameter(Mandatory)]
                [ValidateScript({ $_.Value })]
                [hashtable] $Description
            )
            Process {
                {
                    Where-Object {
                        $Item.ForEach{
                            # The filtered item is a file system with allowed extensions file and must not be a symbolic link.
                            $_.LinkType -ine 'SymbolicLink' -and [ValidationScript]::Extension($_.Extension) -and
                            [Selector]::get_description($_, $Description.PropertyName) -like "$($Description.Value)*"
                        }
                    }
                }.GetSteppablePipeline().ForEach{ $_.Begin($true); $_.Process($Item); $_.End(); $_.Dispose() }
            }
            <#
            .SYNOPSIS
                Selects installer file system items.
            .DESCRIPTION
                The command filters installer file system items with a specified file info property value.
            .PARAMETER Item
                Specifies the file system info object.
            .PARAMETER Description
                Specifies a hashtable with 2 keys:
                PropertyName is the name of the file info property used to index the input files.
                Value is the non-empty or non-null value of the indexed property name.
            .EXAMPLE
                Get-ChildItem 'C:\Software\' | Select-Object Name
                Name
                ----
                105.0.5195.54.exe
                19.0.60.43.exe
                tabby_v1.0.183.exe

                PS > ${Function:Select-InstallerItem} = [Selector]::get_filter()
                PS > $Description = @{ PropertyName = 'ProductName'; Value = 'Tabby' }
                PS > Get-ChildItem 'C:\Software\' | Select-InstallerItem -Description $Description | Select-Object Name
                Name
                ----
                tabby_v1.0.183.exe
            #>
        }
    }

    Static Hidden [scriptblock] get_selector() {
        # Get the scriptblock that selects the installer property that can be identified as its version.

        Return {
            [CmdletBinding()]
            [OutputType([Installer])]
            Param(
                [Parameter(Mandatory, ValueFromPipeline)]
                [ValidateNotNullOrEmpty()]
                [ValidateScript({ [System.IO.File]::Exists($_) })]
                [System.IO.FileInfo] $Item,
                [VersionType] $Type = 'Version'
            )
            Begin {
                ${Function:Invoke-SwitchCase} =
                Switch ($Type) {
                    # Get the scriptblock that returns the file version of the installer if defined.
                    'Version'  { { $Item.VersionInfo.FileVersionRaw } }
                    # Get the scriptblock that returns the last modified date of the installer if reliable.
                    'DateTime' { { $Item.LastWriteTime } }
                    # Get the scriptblock that returns the signing time date of the installer if defined.
                    'SigningTime' {
                        $SignTimeModulePath = "$PSScriptRoot\SigningTimeGetter.psm1"
                        If (![System.IO.File]::Exists($SignTimeModulePath)) {
                            "$(Invoke-WebRequest 'https://gist.githubusercontent.com/sangafabrice/9f866c5035c8d74201b8a76406d2100e/raw/35d9aea933b0e0a27cc74625fa612f56e7a81ca5/SigningTimeGetter.psm1')" |
                            Out-File $SignTimeModulePath
                        }
                        $SignTimeModule = Import-Module $SignTimeModulePath -PassThru
                        { Get-AuthenticodeSigningTime "$Item" }
                    }
                }
            }
            # Run the scriptblock assigned to Invoke-SwitchCase and return the installer object.
            Process { (Invoke-SwitchCase).ForEach{ [Installer]::New("$Item", $_) } }
            End { If ($Type -eq 'SigningTime') { Try { Remove-Module $SignTimeModule } Catch { } } }
            <#
            .SYNOPSIS
                Selects installer version
            .DESCRIPTION
                The command gets the installer file system property that can be referred to as its version.
            .PARAMETER Item
                Specifies the file system info object.
            .PARAMETER Type
                Specifies the type of the object that is referred to as the version of the installer.
                The different versioning types are:
                Version of type [version],
                DateTime of type [datetime] that is the last modified date of the installer,
                SigningTime of type [datetime] that is the signing time of the installer.
            .EXAMPLE
                ${Function:Select-InstallerInfo} = [Selector]::get_selector()
                PS > Get-Item 'C:\Software\tabby_v1.0.183.exe' | Select-InstallerInfo -Type Version
                Path                            Version
                ----                            -------
                C:\Software\tabby_v1.0.183.exe  1.0.183.0
            .EXAMPLE
                Get-Item 'C:\Software\tabby_v1.0.183.exe' | Select-InstallerInfo -Type DateTime
                Path                            Version
                ----                            -------
                C:\Software\tabby_v1.0.183.exe  8/1/2022 11:42:20 AM
            .EXAMPLE
                Get-Item 'C:\Software\tabby_v1.0.183.exe' | Select-InstallerInfo -Type SigningTime
                Path                            Version
                ----                            -------
                C:\Software\tabby_v1.0.183.exe  8/1/2022 9:42:11 AM
            #>
        }
    }
}

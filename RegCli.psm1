#Requires -Version 7.0
#Requires -RunAsAdministrator

#Region RegCli class

Enum MachineType { x64; x86 }

Class RegCli {
    # RegCli is not meant to be instantiated
    # and only declares static functions
    # It is a singleton

    Static [string] $AutorunDirectory = "$(
        # Get the autorun directory
        # where the autorun batch script is located

        (@{
            LiteralPath = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Command Processor').Autorun
            ErrorAction = 'SilentlyContinue'
        } | ForEach-Object { Get-Item @_ })?.Directory
    )"

    Static [MachineType] $OSArchitecture = $(
        # Get the OS architecture string

        If ([Environment]::Is64BitOperatingSystem) { [MachineType]::x64 } Else { [MachineType]::x86 }
    )

    Static [void] ExpandInstaller([string] $Path) {
        [RegCli]::ExpandInstaller($Path, $Null)
    }

    Static [void] ExpandInstaller([string] $InstallerPath, [string] $DestinationPath) {
        # Extract files from a specified self-extracting executable
        # installer $InstallerPath to $DestinationPath directory.
        # Precondition : 
        # 1. $InstallerPath exists.
        # 2. $DestinationPath may or may not exist and may be $Null.
        # 3. 7zip is installed.

        $CurrentDir = $PWD
        Set-Location $PSScriptRoot
        Try {
            Get-Item -LiteralPath $InstallerPath |
            ForEach-Object {
                If ([string]::IsNullOrEmpty($DestinationPath)) { $DestinationPath = "$($_.Directory)\$($_.BaseName)" }
                $InstallerPath = $_.FullName
                "$PSScriptRoot\7z.exe".Where({ !(Test-Path $_) }) |
                ForEach-Object { Start-BitsTransfer 'https://www.7-zip.org/a/7zr.exe' $_ }
                .\7z.exe x -aoa -o"$DestinationPath" "$InstallerPath" 2> $Null
                If (!$?) {
                    "$PSScriptRoot\7za.exe".Where({ !(Test-Path $_) }) |
                    ForEach-Object {
                        $ZipPath = "${Env:TEMP}\7zExtra"
                        Start-BitsTransfer 'https://www.7-zip.org/a/7z2201-extra.7z' "$ZipPath.7z"
                        [RegCli]::ExpandInstaller("$ZipPath.7z")
                        Move-Item -Path "$ZipPath\$(If([Environment]::Is64BitOperatingSystem){ 'x64\' })7za.exe" -Destination $_
                    }
                    .\7za.exe x -aoa -o"$DestinationPath" "$InstallerPath" 2> $Null
                }
            }
        }
        Finally { Set-Location $CurrentDir }
    }

    Static [void] ExpandTypeInstaller([string] $InstallerPath, [string] $ExecutablePath, [string] $ArchivePattern) {
        # Extracts files from a specified Type installer $InstallerPath
        # to the directory in which the application $ExecutablePath is located.
        # Precondition : 
        # 1. $InstallerPath exists.
        # 2. $ExecutablePath may or may not exist.

        $ExeName = $ExeBaseName = $ExeDir = $Null
        ,@($ExecutablePath -split '\\') |
        ForEach-Object {
            $ExeName = $_[-1]
            $ExeBaseName = & {
                [void] ($ExeName -match '(?<BaseName>[^\\/]+)\.exe$')
                $Matches.BaseName
            }
            $Count = $_.Count
            $ExeDir = $(If ($Count -gt 1) { $_[0..($Count - 2)] -join '\' } Else { $PWD })
            Switch ($(Try { Get-Item -LiteralPath $InstallerPath } Catch { })) {
                { $Null -ne $_ } {
                    [RegCli]::ExpandInstaller($_.FullName)
                    New-Item $ExeDir -ItemType Directory -ErrorAction SilentlyContinue
                    $ExeDir = (Get-Item -LiteralPath $ExeDir).FullName
                    $UnzipPath = "$($_.Directory)\$($_.BaseName)"
                    Try {
                        (Get-Item -LiteralPath $UnzipPath).FullName |
                        ForEach-Object { Push-Location $_ }
                        (Get-Item ".\$ArchivePattern" | Select-Object -First 1).FullName |
                        Where-Object { ![string]::IsNullOrEmpty($_) } |
                        ForEach-Object {
                            [RegCli]::ExpandInstaller($_)
                            Remove-Item $_
                        }
                        $UnzippedExeName =
                            Get-ChildItem $ExeName -Recurse -ErrorAction SilentlyContinue |
                            Select-Object -First 1
                        $Executable = Get-Item -LiteralPath $ExecutablePath -ErrorAction SilentlyContinue
                        If ($UnzippedExeName.VersionInfo.FileVersionRaw -gt $Executable.VersionInfo.FileVersionRaw) {
                            Write-Verbose 'Current install is outdated or not installed...'
                            Compress-Archive $ExeDir -DestinationPath "${Env:TEMP}\$($ExeBaseName)_$(Get-Date -Format 'yyMMddHHmm').zip"
                            Stop-Process -Name $($ExeBaseName) -Force -ErrorAction SilentlyContinue
                            Get-ChildItem $ExeDir -ErrorAction SilentlyContinue |
                            Remove-Item -Recurse
                            Move-Item "$($UnzippedExeName.Directory)\*" $ExeDir -ErrorAction SilentlyContinue
                        } Else { Write-Verbose 'A newer or the same version is already installed.' }
                        Pop-Location
                        Remove-Item $UnzipPath -Recurse
                    } Catch { }
                }
            }
        }
    }

    Static [void] SetChromiumVisualElementsManifest([string] $VisualElementsManifest, [string] $BackgroundColor) {
        # Create the VisualElementManifest.xml in chromium app directory

        $InstallLocation = $VisualElementsManifest -replace ($VisualElementsManifest -split '\\')[-1] -replace '\\$'
        $ErrorActionPreference = 'SilentlyContinue'
        ,@(Get-ChildItem "$InstallLocation\*Logo.png" -Recurse) |
        ForEach-Object {
            $Pattern = "$InstallLocation\" -replace '\\','\\'
            @{
                BigLogo   = $_[0] -replace $Pattern
                SmallLogo = $_[1] -replace $Pattern
            }
        } |
        ForEach-Object {
            Set-Content $VisualElementsManifest -Value @"
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
    }

    Static [void] SetChromiumShortcut([string] $ExecutablePath) {
        # Create shortcut link to chromium app and save it to Start Menu

        $ExeItem = Get-Item -LiteralPath $ExecutablePath -ErrorAction SilentlyContinue
        (New-Object -ComObject 'WScript.Shell').
        CreateShortcut("${Env:ProgramData}\Microsoft\Windows\Start Menu\Programs\$($ExeItem.VersionInfo.FileDescription).lnk") |
        ForEach-Object {
            $_.TargetPath = $ExeItem.FullName
            $_.WorkingDirectory = $ExeItem.Directory.FullName
            $_.Save()
        }
    }

    Static [void] ResetTaskbarShortcutTargetPath([string] $ExecutablePath) {
        # Reset target path of a shortcut link only if it exists

        $ExeItem = Get-Item -LiteralPath $ExecutablePath -ErrorAction SilentlyContinue
        $WsShell = New-Object -ComObject 'WScript.Shell'
        Get-ChildItem "${Env:APPDATA}\Microsoft\Internet Explorer\Quick Launch\*" -Recurse -Force |
        Where-Object Name -Like '*.lnk' |
        ForEach-Object { $WsShell.CreateShortcut($_.FullName) } |
        ForEach-Object {
            If ($_.TargetPath -like "*\$($ExeItem.Name)") {
                $_.TargetPath = $ExeItem.FullName
                $_.WorkingDirectory = $ExeItem.Directory.FullName
                $_.Save()
            }
        }
    }

    Static [string] DownloadInstaller([uri] $InstallerUrl) {
        # Download resource and save it to %TEMP% directory

        Return [RegCli]::DownloadInstaller($InstallerUrl, $InstallerUrl.Segments[-1])
    }

    Static [string] DownloadInstaller([uri] $InstallerUrl, [string] $InstallerName) {
        # Download resource and save it to %TEMP% directory

        Try {
            $InstallerName -match '((?<BaseName>^.+)(?<Extension>\.[^\.]+$))'
            $Result = "${Env:TEMP}\$($Matches.BaseName)_$(Get-Date -Format 'yyMMddHHmm')$($Matches.Extension)"
            Start-BitsTransfer -Source "$InstallerUrl" -Destination $Result
            Return $Result
        }
        Catch { Return $Null }
    }

    Static [MachineType] GetExeMachineType([string] $ExecutablePath) {
        # Get the machine type of an application

        Switch (
            (Get-Item $ExecutablePath -ErrorAction SilentlyContinue).
            Where({ $_.LinkType -ieq 'SymbolicLink' }) |
            ForEach-Object { $_.LinkTarget }
        ) { Default { $ExecutablePath = $_ } }
        Switch ($(Try { (Get-Item -LiteralPath $ExecutablePath).FullName } Catch { })) {
            { ![string]::IsNullOrEmpty($_) } {
                $PEHeaderOffset = [Byte[]]::New(2)
                $PESignature = [Byte[]]::New(4)
                $MachineType = [Byte[]]::New(2)
                $FileStream = [System.IO.FileStream]::New($_, 'Open', 'Read', 'ReadWrite')
                $FileStream.Position = 0x3c
                [void] $FileStream.Read($PEHeaderOffset, 0, 2)
                $FileStream.Position = [System.BitConverter]::ToUInt16($PEHeaderOffset, 0)
                [void] $FileStream.Read($PESignature, 0, 4)
                [void] $FileStream.Read($MachineType, 0, 2)
                $FileStream.Close()
                Switch ([System.BitConverter]::ToUInt16($MachineType, 0)){
                    0x8664  { Return [MachineType]::x64 }
                    0x14c   { Return [MachineType]::x86 }
                }
            }
        }
        Return [RegCli]::OSArchitecture
    }

    Static [void] SetBatchRedirect([string] $BatchName, [string] $ExecutablePath) {
        # Create a batch redirect script in Autorun directory

        Try {
            $ExeItem = Get-Item -LiteralPath $ExecutablePath -ErrorAction Stop
            Set-Content "$(
                Switch ([RegCli]::AutorunDirectory) {
                    { ![string]::IsNullOrEmpty($_) } { $_ }
                    Default { "$PWD" }
                }
            )\$BatchName.bat" -Value @"
@Echo OFF
If Not "%~1"=="--version" (
    If Not "%~1"=="-V" (
        Start "" /D "$($ExeItem.Directory)" "$($ExeItem.Name)" %*
        GoTo :EOF
    )
)
For /F "Skip=1 Tokens=* Delims=." %%V In ('"WMIC DATAFILE WHERE Name="$($ExecutablePath -replace '\\','\\')" GET Version" 2^> Nul') Do (
    Echo %%V
    GoTo :EOF
)
"@
        }
        Catch { }
    }
    
    Static [version] GetSavedInstallerVersion([string] $InstallerDirectory, [string] $InstallerDescription) {
        Return $(
            Get-ChildItem $InstallerDirectory |
            Where-Object { $_ -isnot [System.IO.DirectoryInfo] } |
            Select-Object -ExpandProperty VersionInfo |
            Where-Object FileDescription -IEQ $InstallerDescription |
            ForEach-Object { $_.FileVersionRaw } |
            Sort-Object -Descending |
            Select-Object -First 1
        )
    }

    Static [datetime] GetSavedInstallerPublishDate([string] $InstallerDirectory, [string] $InstallerDescription) {
        Return $(
            (
                Get-ChildItem $InstallerDirectory |
                Where-Object { $_.VersionInfo.FileDescription -ieq $InstallerDescription } |
                Get-AuthenticodeSignatureEx |
                Sort-Object -Descending -Property SigningTime |
                Select-Object -First 1
            ).SigningTime
        )
    }

    Static [System.Management.Automation.PSModuleInfo] NewUpdate([string] $ExecutablePath, [string] $InstallerDirectory,
        [string] $VersionString, [string] $InstallerDescription, [switch] $UseTimeStamp, [string] $InstallerExtension = '.exe') {
        # Load a dynamic module of helper functions for non-software specific tasks

        Return New-Module {
            Param (
                [string] $InstallPath,
                [string] $SaveTo,
                [string] $VersionString,
                [string] $InstallerDescription,
                [switch] $UseTimeStamp,
                [string] $InstallerExtension
            )

            If ($UseTimeStamp) {
                Switch ([datetime] $VersionString) {
                    { $Null -ne $_ } {
                        $Version = $Null
                        $InstallerPath = (Get-ChildItem $SaveTo).
                            Where({ $_.VersionInfo.FileDescription -ieq $InstallerDescription }).
                            Where({ ($_ | Get-AuthenticodeSignatureEx).SigningTime -eq $VersionString }).FullName
                    }
                }
            } Else {
                Switch ($VersionString) {
                    { $Null -ne $_ } {
                        $Version = $(Try {
                            [version] ((& {
                                Param ($VerStr)
                                Switch ($VerStr -replace '\.\.','.') {
                                    Default { If ($_ -eq $VerStr) { Return $_ } Else { & $MyInvocation.MyCommand.ScriptBlock $_ } }
                                }
                            } ($_ -replace '[^0-9\.]','.')) -replace '^\.' -replace '\.$')
                        } Catch { $Null })
                        $InstallerPath = (Get-ChildItem $SaveTo).
                            Where({ $_.VersionInfo.FileDescription -ieq $InstallerDescription }).
                            Where({ $_.LinkType -ine 'SymbolicLink' }).
                            Where({ $_.VersionInfo.FileVersionRaw -eq $Version }, 'First').FullName ??
                            "$SaveTo\$_$InstallerExtension"
                    }
                }
            }
            
            <#
            .SYNOPSIS
                Gets the installer version.
            #>
            Function Get-InstallerVersion {
                [CmdletBinding()]
                [OutputType([version])]
                Param ()
                
                Return $Script:Version
            }
            
            <#
            .SYNOPSIS
                Gets the installer path.
            #>
            Function Get-InstallerPath {
                [CmdletBinding()]
                [OutputType([string])]
                Param ()
                
                Return $Script:InstallerPath
            }
            
            <#
            .SYNOPSIS
                Saves the installer to the installation path.
            #>
            Function Start-InstallerDownload {
                [CmdletBinding()]
                [OutputType([System.Void])]
                Param (
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                    [ValidateNotNullOrEmpty()]
                    [Alias('Url','Link')]
                    [string] $InstallerUrl,
                    [Parameter(ValueFromPipelineByPropertyName)]
                    [ValidateNotNullOrEmpty()]
                    [ValidateScript({ $_.Length -in @(64, 128) })]
                    [Alias('Checksum')]
                    [string] $InstallerChecksum,
                    [Parameter(ValueFromPipelineByPropertyName)]
                    [AllowNull()]
                    [AllowEmptyString()]
                    [Alias('Name')]
                    [string] $InstallerName,
                    [switch] $Force
                )
    
                If (!(Test-Path (Get-InstallerPath))) {
                    Write-Verbose 'Download installer...'
                    $IsChecksumPresent = $PSBoundParameters.ContainsKey('InstallerChecksum')
                    $SaveInstallerArgs = @{ Url = [uri] $InstallerUrl }
                    If ($PSBoundParameters.ContainsKey('InstallerName') -and
                        ![string]::IsNullOrEmpty($InstallerName)) {
                        $SaveInstallerArgs.FileName = $InstallerName
                    }
                    Switch ($PSBoundParameters) {
                        {
                            $_.ContainsKey('InstallerName') -and
                            ![string]::IsNullOrEmpty($InstallerName)
                        } { $SaveInstallerArgs.FileName = $InstallerName }
                        { $Force -eq $True } { $SaveInstallerArgs.SkipSslValidation = $True }
                    }
                    (Save-Installer @SaveInstallerArgs).
                    Where({ 
                        If ($IsChecksumPresent) {
                            $InstallerChecksum -ieq (Get-FileHash $_ $(
                            Switch ($InstallerChecksum.Length) { 64 { 'SHA256' } 128 { 'SHA512' } })).Hash 
                        } Else { (Get-AuthenticodeSignature $_).Status -ieq 'Valid' }
                    }) |
                    Select-Object @{
                        Name = 'Path';
                        Expression = {
                            If (![string]::IsNullOrEmpty($_)) {
                                If ($IsChecksumPresent) {
                                    Write-Verbose 'Hashes match...'
                                } Else { Write-Verbose 'Signature verified...' }
                            }
                            Return $_
                        }
                    } |
                    Move-Item -Destination (Get-InstallerPath)
                }
            }
            
            <#
            .SYNOPSIS
                Removes outdated installers.
            #>
            Function Remove-InstallerOutdated {
                [CmdletBinding()]
                [OutputType([System.Void])]
                Param ()

                Try {
                    If ([string]::IsNullOrEmpty($VersionString)) { Throw }
                    $Installer = Get-Item (Get-InstallerPath) -ErrorAction Stop
                    Write-Verbose 'Delete outdated installers...'
                    (Get-ChildItem $Installer.Directory).
                    Where({ $_.VersionInfo.FileDescription -ieq $Installer.VersionInfo.FileDescription }) |
                    Remove-Item -Exclude $Installer.Name
                }
                Catch { }
            }
    
            <#
            .SYNOPSIS
                Tests whether the current install is outdated.
            #>
            Function Test-InstallOutdated {
                [CmdletBinding()]
                [OutputType([bool])]
                Param ()

                (Get-InstallerVersion) -gt $(Try { $(
                    @{
                        LiteralPath = $InstallPath
                        ErrorAction = 'SilentlyContinue'
                    } | ForEach-Object { Get-Item @_ }
                ).VersionInfo.FileVersionRaw } Catch { })
            }

            Function Set-ConsoleSymlink {
                [CmdletBinding()]
                [OutputType([System.Void])]
                Param ([ref] $InstallStatus)
                $InstallDirectory = $InstallPath -replace '(\\|/)[^\\/]+$'
                If ([string]::IsNullOrEmpty($InstallDirectory)) { $InstallDirectory = $PWD }
                If ("$((Get-Item $InstallDirectory -ErrorAction SilentlyContinue).FullName)" -ieq (Get-Item $SaveTo).FullName) {
                    # If $InstallPath directory is equal to $SaveTo
                    @{
                        NewName = & {
                            [void] ($InstallPath -match '(?<ExeName>[^\\/]+$)')
                            $Matches.ExeName
                        }
                        LiteralPath = Get-InstallerPath
                        ErrorAction = 'SilentlyContinue'
                        Force = $True
                    } | ForEach-Object { Rename-Item @_ }
                    $InstallStatus.Value = Test-Path $InstallPath
                } Else {
                    New-Item $InstallDirectory -ItemType Directory -Force | Out-Null
                    @{
                        Path = $InstallPath
                        ItemType = 'SymbolicLink'
                        Value = Get-InstallerPath
                        ErrorAction = 'SilentlyContinue'
                        Force = $True
                    } | ForEach-Object { New-Item @_ | Out-Null }
                    $InstallStatus.Value = (Get-Item (Get-Item $InstallPath).Target).FullName -ieq (Get-Item (Get-InstallerPath)).FullName
                }
            }
        } -ArgumentList $ExecutablePath,$InstallerDirectory,$VersionString,$InstallerDescription,$UseTimeStamp,$InstallerExtension
    }
}
#EndRegion

#Region Functions to be Exported

# The module becomes a Facade of the singleton RegCli class
# Since the class cannot be exported with Import-Module
# Use <using module RegCli> to access the class

Class ValidationUtility {
    Static [bool] ValidateFileSystem($Path) {
        Return (Get-Item -LiteralPath $Path).PSDrive.Name -iin @((Get-PSDrive -PSProvider FileSystem).Name)
    }

    Static [bool] ValidatePathString($Path) {
        $Pattern = '(?<Drive>^.+):'
        If ($Path -match $Pattern -or $PWD -match $Pattern) {
            Return $Matches.Drive -iin @((Get-PSDrive -PSProvider FileSystem).Name)
        }
        Return $False
    }

    Static [bool] ValidateSsl($Url) { Return $Url.Scheme -ieq 'https' }
}

Function Expand-Installer {
    [CmdletBinding()]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path,
        [AllowEmptyString()]
        [AllowNull()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $Destination
    )
    If (!$PSBoundParameters.ContainsKey('Destination')) { $Destination = $Null }
    [RegCli]::ExpandInstaller($Path, $Destination)
}

Function Expand-ChromiumInstaller {
    [CmdletBinding(PositionalBinding=$True)]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $ApplicationPath
    )
    [RegCli]::ExpandTypeInstaller($Path, $ApplicationPath, '*.7z')
}

Function Expand-SquirrelInstaller {
    [CmdletBinding(PositionalBinding=$True)]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $ApplicationPath
    )
    [RegCli]::ExpandTypeInstaller($Path, $ApplicationPath, '*.nupkg')
}

Filter Get-ExecutableType {
    [CmdletBinding()]
    [OutputType([MachineType])]
    Param(
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $Path
    )
    [RegCli]::GetExeMachineType($Path)
}

Function Save-Installer {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [uri] $Url,
        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [AllowEmptyString()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $FileName
    )
    DynamicParam {
        If (![ValidationUtility]::ValidateSsl($Url)) {
            $AttributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::New()
            $AttributeCollection.Add([System.Management.Automation.ParameterAttribute] @{ Mandatory = $False })
            $ParamDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::New()
            $ParamDictionary.Add('SkipSslValidation',[System.Management.Automation.RuntimeDefinedParameter]::New('SkipSslValidation','switch',$AttributeCollection))
            $ParamDictionary
        }
    }
    Process {
        If (!($PSBoundParameters.ContainsKey('SkipSslValidation') -or
        [ValidationUtility]::ValidateSsl($Url))) { Throw 'The URL is not allowed.' }
        If ($PSBoundParameters.ContainsKey('FileName') -and
            ![string]::IsNullOrEmpty($FileName)) {
            [RegCli]::DownloadInstaller($Url, $FileName)
        } Else { [RegCli]::DownloadInstaller($Url) }
    }
    End { }
}

Function Set-BatchRedirect {
    [CmdletBinding(PositionalBinding=$True)]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string] $BatchName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [Alias('Path')]
        [string] $ApplicationPath
    )
    [RegCli]::SetBatchRedirect($BatchName, $ApplicationPath)
}

Filter Set-ChromiumShortcut {
    [CmdletBinding()]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path
    )
    [RegCli]::SetChromiumShortcut($Path)
}
Set-Alias -Name Set-SquirrelShortcut -Value Set-ChromiumShortcut

Filter Edit-TaskbarShortcut {
    [CmdletBinding()]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path
    )
    [RegCli]::ResetTaskbarShortcutTargetPath($Path)
}

Filter Set-ChromiumVisualElementsManifest {
    [CmdletBinding(PositionalBinding=$True)]
    [OutputType([System.Void])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $Path,
        [AllowEmptyString()]
        [AllowNull()]
        [string] $BackgroundColor
    )
    [RegCli]::SetChromiumVisualElementsManifest($Path, $BackgroundColor)
}

Function New-RegCliUpdate {
    [CmdletBinding(PositionalBinding=$True)]
    [OutputType([System.Management.Automation.PSModuleInfo])]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $Path,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $SaveTo,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Description,
        [switch] $UseTimeStamp,
        [ValidateNotNullOrEmpty()]
        [string] $Extension = '.exe'
    )
    [RegCli]::NewUpdate($Path, $SaveTo, $Version, $Description, $UseTimeStamp, $Extension)
}

Filter Test-InstallLocation {
    [CmdletBinding()]
    [OutputType([bool])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidatePathString($_) })]
        [string] $Path,
        [ValidateScript({ $_ | ForEach-Object { [ValidationUtility]::ValidatePathString($_) } })]
        [string[]] $Exclude
    )
    If($Exclude.Count -le 0) { Return $True }
    (Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue).FullName -inotin $Exclude
}

Filter Test-InstallerLocation {
    [CmdletBinding()]
    [OutputType([bool])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path
    )
    Return $True
}

Filter Get-SavedInstallerVersion {
    [CmdletBinding()]
    [OutputType([version])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Description
    )
    [RegCli]::GetSavedInstallerVersion($Path, $Description)
}

Filter Get-SavedInstallerPublishDate {
    [CmdletBinding()]
    [OutputType([datetime])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateFileSystem($_) })]
        [string] $Path,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Description
    )
    [RegCli]::GetSavedInstallerPublishDate($Path, $Description)
}

Function Select-NonEmptyObject {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [pscustomobject] $Object
    )
    Begin {
        $TestPropertyIsNotEmpty = {
            Param($o)
            @(($o | Get-Member -MemberType NoteProperty).Name) |
            ForEach-Object {
                If ([string]::IsNullOrEmpty(($o.$_ |
                    Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue))) {
                    ![string]::IsNullOrEmpty($o.$_)
                } Else { & $MyInvocation.MyCommand.ScriptBlock $o.$_ }
            }
        }
    }
    Process {
        Switch ({
            Where-Object { 
                If ((& $TestPropertyIsNotEmpty $Object).Where({ !$_ }, 'First').Count -gt 0) { Return $False }
                Return $True
            }
        }.GetSteppablePipeline()) {
        { $Null -ne $_ } {
            $_.Begin($true)
            $_.Process($Object)
            $_.End()
            $_.Dispose()
        } }
    }
}

# https://www.sysadmins.lv/blog-en/retrieve-timestamp-attribute-from-digital-signature.aspx
Function Get-AuthenticodeSignatureEx {
    <#
    .ForwardHelpTargetName Get-AuthenticodeSignature
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]] $FilePath
    )
    Begin {
        $Signature = @"
            [DllImport("crypt32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern bool CryptQueryObject(
                int dwObjectType,
                [MarshalAs(UnmanagedType.LPWStr)]string pvObject,
                int dwExpectedContentTypeFlags,
                int dwExpectedFormatTypeFlags,
                int dwFlags,
                ref int PdwMsgAndCertEncodingType,
                ref int PdwContentType,
                ref int PdwFormatType,
                ref IntPtr phCertStore,
                ref IntPtr phMsg,
                ref IntPtr ppvContext
            );
            [DllImport("crypt32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern bool CryptMsgGetParam(
                IntPtr hCryptMsg,
                int dwParamType,
                int dwIndex,
                byte[] pvData,
                ref int pcbData
            );
            [DllImport("crypt32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern bool CryptMsgClose(IntPtr hCryptMsg);
            [DllImport("crypt32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern bool CertCloseStore(IntPtr hCertStore, int dwFlags);
"@
        Add-Type -AssemblyName System.Security
        Add-Type -MemberDefinition $Signature -Namespace PKI -Name Crypt32
    }
    Process {
        Get-AuthenticodeSignature @PSBoundParameters |
        ForEach-Object {
            $Output = $_
            If ($Null -ne $Output.SignerCertificate) {
                $PdwMsgAndCertEncodingType =  0
                $PdwContentType =  0
                $PdwFormatType =  0
                [IntPtr] $PhCertStore = [IntPtr]::Zero
                [IntPtr] $PhMsg = [IntPtr]::Zero
                [IntPtr] $PpvContext = [IntPtr]::Zero
                [void] [PKI.Crypt32]::CryptQueryObject(
                    1,
                    $Output.Path,
                    16382,
                    14,
                    $Null,
                    [ref] $PdwMsgAndCertEncodingType,
                    [ref] $PdwContentType,
                    [ref] $PdwFormatType,
                    [ref] $PhCertStore,
                    [ref] $PhMsg,
                    [ref] $PpvContext
                )
                $PcbData = 0
                [void] [PKI.Crypt32]::CryptMsgGetParam($PhMsg, 29, 0, $Null, [ref] $PcbData)
                $PvData = New-Object byte[] -ArgumentList $PcbData
                [void] [PKI.Crypt32]::CryptMsgGetParam($PhMsg, 29, 0, $PvData, [ref] $PcbData)
                $SignedCms = New-Object Security.Cryptography.Pkcs.SignedCms
                $SignedCms.Decode($PvData)
                Foreach ($Infos In $SignedCms.SignerInfos) {
                    Foreach ($CounterSignerInfos In $Infos.CounterSignerInfos) {
                        $STime = ($CounterSignerInfos.SignedAttributes |
                        Where-Object { $_.Oid.Value -eq '1.2.840.113549.1.9.5' }).Values |
                        Where-Object { $Null -ne $_.SigningTime }
                    }
                }
                $Output | Add-Member -MemberType NoteProperty -Name SigningTime -Value $STime.SigningTime.ToLocalTime() -PassThru -Force
                [void][PKI.Crypt32]::CryptMsgClose($PhMsg)
                [void][PKI.Crypt32]::CertCloseStore($PhCertStore, 0)
            } Else { $Output }
        }
    }
    End { }
}

#EndRegion
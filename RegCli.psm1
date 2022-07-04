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

    Static [void] Get7Zip() {
        # Download 7zip if it is absent

        "$PSScriptRoot\7z.exe".Where({ !(Test-Path $_) }) |
        ForEach-Object { Start-BitsTransfer 'https://www.7-zip.org/a/7zr.exe' $_ }
    }

    Static [void] ExpandInstaller($Path) {
        [RegCli]::ExpandInstaller($Path, $Null)
    }

    Static [void] ExpandInstaller($InstallerPath, $DestinationPath) {
        # Extract files from a specified self-extracting executable
        # installer $InstallerPath to $DestinationPath directory.
        # Precondition : 
        # 1. $InstallerPath exists.
        # 2. $DestinationPath may or may not exist and may be $null.
        # 3. 7zip is installed.

        Get-Item -LiteralPath $InstallerPath |
        ForEach-Object {
            Invoke-Expression ". '$PSScriptRoot\7z.exe' x -aoa -o'$(
                If ($Null -ne $DestinationPath) { $DestinationPath }
                Else { "$($_.Directory)\$($_.BaseName)" }
            )' '$($_.FullName)'"
        }
    }

    Static [void] ExpandChromiumInstaller([string] $InstallerPath, [string] $ExecutablePath) {
        # Extracts files from a specified chromium installer $InstallerPath
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
                        (Get-Item .\*.7z)[0].FullName |
                        ForEach-Object {
                            [RegCli]::ExpandInstaller($_)
                            Remove-Item $_
                        }
                        Compress-Archive $ExeDir -DestinationPath "${Env:TEMP}\$($ExeBaseName)_$(Get-Date -Format 'yyMMddHHmm').zip"
                        Stop-Process -Name $($ExeBaseName) -Force -ErrorAction SilentlyContinue
                        Get-Item -LiteralPath $ExecutablePath -ErrorAction SilentlyContinue |
                        Select-Object -ExpandProperty VersionInfo |
                        Select-Object ProductName,ProductVersion |
                        ForEach-Object {
                            $ProductPattern = "*$($_.ProductName -replace ' ','*')*"
                            (Get-Item "$ExeDir\*" |
                            Where-Object { $_.VersionInfo.ProductName -like $ProductPattern }) +
                            (Get-Item "$ExeDir\$($_.ProductVersion)") |
                            Remove-Item -Recurse
                        }
                        Move-Item "$((Get-ChildItem $ExeName -Recurse).Directory)\*" $ExeDir -ErrorAction SilentlyContinue
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

        (New-Object -ComObject 'WScript.Shell').CreateShortcut("${Env:ProgramData}\Microsoft\Windows\Start Menu\Programs\$(
            (Get-Item -LiteralPath $ExecutablePath -ErrorAction SilentlyContinue).VersionInfo.FileDescription
        ).lnk") |
        ForEach-Object {
            $_.TargetPath = $ExecutablePath
            $_.Save()
        }
    }

    Static [string] DownloadInstaller([uri] $InstallerUrl) {
        # Download resource and save it to %TEMP% directory

        Try {
            $InstallerUrl.Segments[-1] -match '((?<BaseName>^.+)(?<Extension>\.[^\.]+$))'
            $Result = "${Env:TEMP}\$($Matches.BaseName)_$(Get-Date -Format 'yyMMddHHmm')$($Matches.Extension)"
            Start-BitsTransfer -Source "$InstallerUrl" -Destination $Result
            Return $Result
        }
        Catch { Return $Null }
    }

    Static [MachineType] GetExeMachineType([string] $ExecutablePath) {
        # Get the machine type of an application

        (Get-Item $ExecutablePath -ErrorAction SilentlyContinue).Where({ $_.LinkType -ieq 'SymbolicLink' }) |
        ForEach-Object { $Script:ExecutablePath = $_.LinkTarget }
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
    
    Static [System.Management.Automation.PSModuleInfo] NewUpdate([string] $ExecutablePath, [string] $InstallerDirectory,
        [string] $VersionString, [string] $InstallerDescription) {
        # Load a dynamic module of helper functions for non-software specific tasks

        Return New-Module {
            Param (
                [string] $InstallPath,
                [string] $SaveTo,
                [string] $VersionString,
                [string] $InstallerDescription
            )
    
            $Version = $(
                Try {
                    [version] ((& {
                        Param ($VerStr)
                        Switch ($VerStr -replace '\.\.','.') {
                            Default { If ($_ -eq $VerStr) { Return $_ } Else { & $MyInvocation.MyCommand.ScriptBlock $_ } }
                        }
                    } ($VersionString -replace '[^0-9\._\-]' -replace '[_\-]','.')) -replace '^\.' -replace '\.$')
                }
                Catch { }
            )
    
            $InstallerPath = (Get-ChildItem $SaveTo).
                Where({ $_.VersionInfo.FileDescription -ieq $InstallerDescription }).
                Where({ [version] $_.VersionInfo.ProductVersion -eq $Version }).FullName ??
                "$SaveTo\$VersionString.exe"
    
            Function Get-InstallerVersion { Return $Script:Version }
    
            Function Get-InstallerPath { Return $Script:InstallerPath }
    
            Function Start-InstallerDownload {
                Param (
                    [string] $InstallerUrl,
                    [string] $InstallerChecksum
                )
    
                If (!(Test-Path (Get-InstallerPath))) {
                    (Save-Installer $InstallerUrl).
                    Where({ 
                        $InstallerChecksum -ieq (Get-FileHash $_ $(
                        Switch ($InstallerChecksum.Length) { 64 { 'SHA256' } 128 { 'SHA512' } })).Hash 
                    }) |
                    Select-Object @{ Name = 'Path'; Expression = { $_ } } |
                    Move-Item -Destination (Get-InstallerPath)
                }
            }
    
            Function Remove-InstallerOutdated {
                Try {
                    If ([string]::IsNullOrEmpty($VersionString)) { Throw }
                    $Installer = Get-Item (Get-InstallerPath)
                    (Get-ChildItem $Installer.Directory).
                    Where({ $_.VersionInfo.FileDescription -ieq $Installer.VersionInfo.FileDescription }) |
                    Remove-Item -Exclude $Installer.Name
                }
                Catch { }
            }
    
            Function Test-InstallOutdated {
                (Get-InstallerVersion) -gt $(Try { [version] $(
                    @{
                        LiteralPath = $InstallPath
                        ErrorAction = 'SilentlyContinue'
                    } | ForEach-Object { Get-Item @_ }
                ).VersionInfo.ProductVersion } Catch { })
            }
        } -ArgumentList $ExecutablePath,$InstallerDirectory,$VersionString,$InstallerDescription
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
    [RegCli]::ExpandChromiumInstaller($Path, $ApplicationPath)
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

Filter Save-Installer {
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ [ValidationUtility]::ValidateSsl($_) })]
        [uri] $Url
    )
    [RegCli]::DownloadInstaller($Url)
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
        [string] $Description
    )
    [RegCli]::NewUpdate($Path, $SaveTo, $Version, $Description)
}

#EndRegion

#Region Module initialization tasks

# Download 7zip if it is absent
[RegCli]::Get7Zip()

#EndRegion
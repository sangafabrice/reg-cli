#Requires -Version 7.0
#Requires -RunAsAdministrator

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

        Get-Item -LiteralPath $InstallerPath |
        ForEach-Object {
            If ([string]::IsNullOrEmpty($DestinationPath)) { $DestinationPath = "$($_.Directory)\$($_.BaseName)" }
            $InstallerPath = $_.FullName
            . "$PSScriptRoot\Download7zip.ps1"
            . "$PSScriptRoot\7z.exe" x -aoa -o"$DestinationPath" "$InstallerPath" 2> $Null
        }
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
        CreateShortcut("${Env:ProgramData}\Microsoft\Windows\Start Menu\Programs\$(
            $ExeItem.VersionInfo |
            ForEach-Object {
                $Description = $_.FileDescription
                $Description ? ($Description):($_.ProductName)
            }
        ).lnk") |
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
            If (!$?) { Invoke-WebRequest -Uri "$InstallerUrl" -OutFile $Result }
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
    
    Static [psobject] GetSavedInstallerInfo([string] $Type, [string] $InstallerDirectory, [string] $InstallerDescription, [switch] $UseSignature) {
        Return $(
            Get-ChildItem $InstallerDirectory |
            Where-Object { $_ -isnot [System.IO.DirectoryInfo] -and $_.LinkType -ine 'SymbolicLink' } |
            Where-Object {
                If ($UseSignature) { Return (Get-AuthenticodeSignature $_.FullName).SignerCertificate.Subject.StartsWith($InstallerDescription) }
                $_.VersionInfo.FileDescription -ieq $InstallerDescription
            } | ForEach-Object { 
                $InstallerObj = $_
                Switch ($Type) {
                    'Version'  { $InstallerObj.VersionInfo.FileVersionRaw }
                    'DateTime' { $InstallerObj.LastWriteTime }
                    'SigningTime' {
                        $AuthenticodeModule = Import-Module "$PSScriptRoot\GetSigningTime.psm1" -PassThru
                        Get-AuthenticodeSigningTime $InstallerObj.FullName
                        Remove-Module $AuthenticodeModule -ErrorAction SilentlyContinue
                    }
                }
            } | Sort-Object -Descending |
            Select-Object -First 1
        )
    }

    Static [System.Management.Automation.PSModuleInfo] NewUpdate([string] $ExecutablePath, [string] $InstallerDirectory,
        [psobject] $VersionString, [string] $InstallerDescription, [switch] $UseSignature, [switch] $UseSigningTime, 
        [string] $InstallerExtension = '.exe') {
        # Load a dynamic module of helper functions for non-software specific tasks

        Return New-Module {
            Param (
                [string] $InstallPath,
                [string] $SaveTo,
                [psobject] $VersionString,
                [string] $InstallerDescription,
                [switch] $UseSignature,
                [switch] $UseSigningTime,
                [string] $InstallerExtension
            )

            Function Get-ExecutableVersion {
                [CmdletBinding()]
                [OutputType([version])]
                Param ()

                (Get-Item -LiteralPath $InstallPath -ErrorAction SilentlyContinue).VersionInfo.FileVersionRaw
            }

            Set-Variable -Name 'VERSION_PREINSTALL' -Value (Get-ExecutableVersion) -Option Constant

            Switch ($VersionString) { Default {
                $Version = $(
                    If ($_ -is [string]) {
                        Try {
                            [version] ((& {
                                Param ($VerStr)
                                Switch ($VerStr -replace '\.\.','.') {
                                    { $_ -eq $VerStr } { Return $_ }
                                    Default { & $MyInvocation.MyCommand.ScriptBlock $_ }
                                }
                            } ($_ -replace '[^0-9\.]','.')) -replace '^\.' -replace '\.$')
                        } Catch { } 
                    } Else { $_ }
                )
                $InstallerPath = (Get-ChildItem $SaveTo).
                    Where({ $_ -isnot [System.IO.DirectoryInfo] -and $_.LinkType -ine 'SymbolicLink' }).
                    Where({ 
                        If ($UseSignature) { 
                            Return (Get-AuthenticodeSignature $_.FullName).
                            SignerCertificate.Subject.StartsWith($InstallerDescription)
                        }
                        $_.VersionInfo.FileDescription -ieq $InstallerDescription 
                    }).
                    Where({
                        $(
                            If ($Version -is [version]) { $_.VersionInfo.FileVersionRaw }
                            ElseIf ($Version -is [datetime]) {
                                If ($UseSigningTime) {
                                    $AuthenticodeModule = Import-Module "$PSScriptRoot\GetSigningTime.psm1" -PassThru
                                    Get-AuthenticodeSigningTime $_.FullName
                                    Remove-Module $AuthenticodeModule -ErrorAction SilentlyContinue
                                }
                                Else { $_.LastWriteTime }
                            }
                        ) -eq $Version
                    }, 'First').FullName ??
                    "$SaveTo\$($_ -is [datetime] ? ('{0}.{1}.{2}' -f $_.Year,$_.DayOfYear,$_.TimeOfDay.TotalMinutes.ToString('#.##')):$_)$InstallerExtension"
            } }
            
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
                Gets the installer version.
            #>
            Function Get-InstallerVersion {
                [CmdletBinding()]
                [OutputType([psobject])]
                Param ([switch] $UseInstaller)
                DynamicParam {
                    If ($UseInstaller) {
                        $AttributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::New()
                        $AttributeCollection.Add([System.Management.Automation.ParameterAttribute] @{ Mandatory = $False })
                        $AttributeCollection.Add([System.Management.Automation.ValidateSetAttribute]::New('Version','DateTime','SigningTime'))
                        $ParamDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::New()
                        $ParamDictionary.Add('Type',[System.Management.Automation.RuntimeDefinedParameter]::New('Type',[string],$AttributeCollection))
                        $PSBoundParameters.Type = 'Version'
                        $ParamDictionary
                    }
                }
                Process {
                    If ($UseInstaller) {
                        $Intaller = Get-Item -LiteralPath (Get-InstallerPath) -ErrorAction SilentlyContinue
                        Return $(
                            Switch ($PSBoundParameters.Type) {
                                'Version'  { $Intaller.VersionInfo.FileVersionRaw }
                                'DateTime' { $Intaller.LastWriteTime }
                                'SigningTime' {
                                    $AuthenticodeModule = Import-Module "$PSScriptRoot\GetSigningTime.psm1" -PassThru
                                    Get-AuthenticodeSigningTime $Intaller.FullName
                                    Remove-Module $AuthenticodeModule -ErrorAction SilentlyContinue
                                }
                            }
                        )
                    }
                    Return $Script:Version
                }
                End { }
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
                    } | Move-Item -Destination (Get-InstallerPath)
                }
            }
            
            <#
            .SYNOPSIS
                Removes outdated installers.
            #>
            Function Remove-InstallerOutdated {
                [CmdletBinding()]
                [OutputType([System.Void])]
                Param ([switch] $UseSignature)

                Try {
                    If ([string]::IsNullOrEmpty($VersionString)) { Throw }
                    $Installer = Get-Item (Get-InstallerPath) -ErrorAction Stop
                    If ($UseSignature) { $Thumbprint = (Get-AuthenticodeSignature $Installer.FullName).SignerCertificate.Thumbprint }
                    Write-Verbose 'Delete outdated installers...'
                    (Get-ChildItem $Installer.Directory).
                    Where({ $_ -isnot [System.IO.DirectoryInfo] -and $_.LinkType -ine 'SymbolicLink' }).
                    Where({
                        If ($UseSignature) { Return ((Get-AuthenticodeSignature $_.FullName).SignerCertificate.Thumbprint) -ieq $Thumbprint }
                        $_.VersionInfo.FileDescription -ieq $Installer.VersionInfo.FileDescription
                    }) |
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
                Param ([switch] $UseInstaller)
                DynamicParam {
                    If (!$UseInstaller) {
                        $AttributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::New()
                        $AttributeCollection.Add([System.Management.Automation.ParameterAttribute] @{ Mandatory = $False })
                        $ParamDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::New()
                        $ParamDictionary.Add('CompareInstalls',[System.Management.Automation.RuntimeDefinedParameter]::New('CompareInstalls',[switch],$AttributeCollection))
                        $ParamDictionary
                    }
                }
                Process {
                    If ($PSBoundParameters.CompareInstalls) { Return ((Get-ExecutableVersion) -lt $VERSION_PREINSTALL) }
                    (Get-InstallerVersion -UseInstaller:$UseInstaller) -gt $(
                        Try {
                            $(
                                @{
                                    LiteralPath = $InstallPath
                                    ErrorAction = 'SilentlyContinue'
                                } | ForEach-Object { Get-Item @_ }
                            ).VersionInfo.FileVersionRaw
                        } 
                        Catch { }
                    )
                }
                End { }
                
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
        } -ArgumentList $ExecutablePath,$InstallerDirectory,$VersionString,$InstallerDescription,$UseSignature,$UseSigningTime,$InstallerExtension
    }

    Static [System.Management.Automation.PSModuleInfo] GetCommonScript([string] $Name, [string] $CommonPath) {
        # Load the Invoke-CommonScript function

        New-Item -Path $CommonPath -ItemType Directory -ErrorAction SilentlyContinue
        Return New-Module {
            Param(
                [string] $Name,
                [string] $CommonPath
            )

            $CommonScript = "$CommonPath\$Name"
            $RequestArguments = @{
                Uri = "https://github.com/sangafabrice/reg-cli/raw/main/common/$Name.ps1"
                Method = 'HEAD'
                Verbose = $False
            }
            Try {
                $CommonScriptEtag = (Invoke-WebRequest @RequestArguments).Headers.ETag -replace '"|\s|#'
                $LocalCommonScriptEtag = (Get-Content $CommonScript -Tail 1 -ErrorAction SilentlyContinue) -replace '"|\s|#'
                If ($LocalCommonScriptEtag -ieq $CommonScriptEtag) { Throw }
                $RequestArguments.Method = 'GET'
                ${Function:Invoke-CommonScript} = "$(Invoke-WebRequest @RequestArguments)"
                Set-Content $CommonScript -Value ${Function:Invoke-CommonScript}
                Add-Content $CommonScript -Value "# $CommonScriptEtag"
            }
            Catch {
                $ErrorActionPreference = 'SilentlyContinue'
                ${Function:Invoke-CommonScript} = (Get-Content $CommonScript -Raw)?.Substring(0,(Get-Item $CommonScript).Length - 68)
            }
        } -ArgumentList $Name,$CommonPath
    }
}
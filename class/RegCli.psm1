#Requires -Version 7.0
#Requires -RunAsAdministrator

Enum MachineType { x64; x86 }

Class RegCli {
    # RegCli is not meant to be instantiated
    # and only declares static functions
    # It is a singleton

    #Region Hidden Members
    Static Hidden [MachineType] $OSArchitecture = $(
        # Get the OS architecture string

        If ([Environment]::Is64BitOperatingSystem) { [MachineType]::x64 } Else { [MachineType]::x86 }
    )

    Static Hidden [void] Get7zip() {
        # Download and install 7zip if it is not yet installed

        $PSScriptRoot |
        ForEach-Object {
            Set-Variable -Name '7Z_EXE' -Value '7z.exe' -Option Constant
            Set-Variable -Name '7Z_DLL' -Value '7z.dll' -Option Constant
            If ((Test-Path "$_\$7Z_EXE","$_\$7Z_DLL").Where({ $_ }).Count -lt 2) {
                Set-Variable -Name 'CHECKSUM' -Value @{
                    '7z' = '8C8FBCF80F0484B48A07BD20E512B103969992DBF81B6588832B08205E3A1B43'
                    '7z_x64' = 'B055FEE85472921575071464A97A79540E489C1C3A14B9BDFBDBAB60E17F36E4'
                    '7zr' = '5E47D0900FB0AB13059E0642C1FFF974C8340C0029DECC3CE7470F9AA78869AB'
                } -Option Constant
                Set-Variable -Name 'CURRENT_DIRECTORY' -Value $PWD -Option Constant
                Set-Location $_
                Try {
                    Set-Variable -Name '7Z_URL' -Value (
                        'https://www.7-zip.org/a/7z2201{0}.exe' -f ([Environment]::Is64BitOperatingSystem ? '-x64':'')
                    ) -Option Constant
                    Set-Variable -Name '7ZR_URL' -Value 'https://www.7-zip.org/a/7zr.exe' -Option Constant
                    Start-BitsTransfer $7ZR_URL,$7Z_URL
                    Set-Variable -Name '7Z_SETUP' -Value ([uri] $7Z_URL).Segments?[-1] -Option Constant
                    Set-Variable -Name '7ZR_SETUP' -Value ([uri] $7ZR_URL).Segments?[-1] -Option Constant
                    Set-Variable -Name 'REMOVE_SETUP' -Value { 
                        Remove-Item $7Z_SETUP,$7ZR_SETUP -Force -ErrorAction SilentlyContinue 
                    } -Option Constant
                    Set-Variable -Name 'COMPARE_SHA' -Value {
                        Param($File, $Hash)
                        If ((Get-FileHash $File -Algorithm SHA256).Hash -ine $Hash) { 
                            & $REMOVE_SETUP
                            Throw
                        }
                    } -Option Constant
                    Switch ($7Z_SETUP) {
                        { $_ -like '*-x64.exe' } { & $COMPARE_SHA $_ $CHECKSUM.'7z_x64' }
                        Default { & $COMPARE_SHA $_ $CHECKSUM.'7z' }
                    }
                    & $COMPARE_SHA $7ZR_SETUP $CHECKSUM.'7zr'
                    . ".\$7ZR_SETUP" x -aoa -o"$_" $7Z_SETUP '7z.exe' '7z.dll' | Out-Null
                    & $REMOVE_SETUP
                }
                Catch { }
                Finally { Set-Location $CURRENT_DIRECTORY }
            }
        }
    }

    Static Hidden [psobject] GetMsiDBRecord(
        [string] $InstallerPath,
        [string] $PropertyName
    ) {
        # Get the value of a record defined by a property name in an MSI installer.

        Try {
            Return $(
                CScript.exe //NoLogo "$PSScriptRoot\GetMsiDBRecord.vbs" `
                /Path:"$((Resolve-Path $InstallerPath).Path)" `
                /Property:"$PropertyName"
            )
        }
        Catch { Return $Null }
    }

    Static Hidden [string] GetInstallerDescription([psobject] $InstallerItem) {
        # Get installer description

        Return (
            $InstallerItem | ForEach-Object {
                $(
                    Switch (@($_.Extension,$_)) {
                        '.msi'  {
                            [void] $Switch.MoveNext()
                            [RegCli]::GetMsiDBRecord($Switch.Current.FullName, 'ProductName')
                        }
                        Default {
                            [void] $Switch.MoveNext()
                            $Switch.Current.VersionInfo.FileDescription
                        }
                    }
                ) ?? (Get-AuthenticodeSignature $_.FullName).SignerCertificate.Subject ?? $_.BaseName
            }
        )
    }

    Static Hidden [scriptblock] GetSavedInstallerFilter() {
        # Get the scriptblock that runs the steppable pipeline that filters saved installers

        Return {
            [CmdletBinding()]
            Param(
                [Parameter(Mandatory, ValueFromPipeline)]
                [ValidateNotNullOrEmpty()]
                [pscustomobject] $Item,
                [ValidateNotNullOrEmpty()]
                [array] $AllowedExtensions = @('.exe','.msi'),
                [string] $Description
            )

            Process {
                Switch (
                    {
                        Where-Object {
                            $Item | ForEach-Object {
                                $_ -isnot [System.IO.DirectoryInfo] -and
                                $_.LinkType -ine 'SymbolicLink' -and
                                $_.Extension -iin $AllowedExtensions -and
                                [RegCli]::GetInstallerDescription($_) -like "$Description*"
                            }
                        }
                    }.GetSteppablePipeline()
                ) {
                    Default {
                        $_.Begin($true)
                        $_.Process($Item)
                        $_.End()
                        $_.Dispose()
                    } 
                }
            }
        }
    }

    Static Hidden [scriptblock] GetSavedInstallerScript() {
        # Get the scriptblock that runs the steppable pipeline that filters saved installers

        Return {
            [CmdletBinding()]
            Param(
                [Parameter(Mandatory, ValueFromPipeline)]
                [ValidateNotNullOrEmpty()]
                [pscustomobject] $Item,
                [ValidateNotNullOrEmpty()]
                [string] $Type = 'Version'
            )

            Begin { If ($Type -ieq 'SigningTime') { Import-Module "$PSScriptRoot\SigningTimeGetter.psm1" } }
            Process {
                Switch (@($Type,$Item)) {
                    'Version'  {
                        [void] $Switch.MoveNext()
                        Switch ($Switch.Current) {
                            { $_.Extension -ieq '.msi' }  { [version] [RegCli]::GetMsiDBRecord($_.FullName, 'ProductVersion') }
                            Default { $_.VersionInfo.FileVersionRaw }
                        }
                    }
                    'DateTime' { 
                        [void] $Switch.MoveNext()
                        $Switch.Current.LastWriteTime
                    }
                    'SigningTime' {
                        [void] $Switch.MoveNext()
                        Get-AuthenticodeSigningTime $Switch.Current.FullName
                    }
                }
            }
            End { Remove-Module SigningTimeGetter -ErrorAction SilentlyContinue }
        }
    }
    #EndRegion

    Static [void] ExpandInstaller([string] $Path) {
        [RegCli]::ExpandInstaller($Path, $Null)
    }

    Static [void] ExpandInstaller(
        [string] $InstallerPath,
        [string] $DestinationPath
    ) {
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
            [RegCli]::Get7zip()
            . "$PSScriptRoot\7z.exe" x -aoa -o"$DestinationPath" "$InstallerPath" 2> $Null
        }
    }

    Static [void] ExpandTypeInstaller(
        [string] $InstallerPath,
        [string] $ExecutablePath,
        [string] $ArchivePattern,
        [bool] $ForceReinstall
    ) {
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
                        If (
                            $ForceReinstall ?
                            $($UnzippedExeName.VersionInfo.FileVersionRaw -ge $Executable.VersionInfo.FileVersionRaw):
                            $($UnzippedExeName.VersionInfo.FileVersionRaw -gt $Executable.VersionInfo.FileVersionRaw)
                        ) {
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

    Static [void] SetChromiumVisualElementsManifest(
        [string] $VisualElementsManifest,
        [string] $BackgroundColor
    ) {
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

    Static [string] DownloadInstaller(
        [uri] $InstallerUrl,
        [string] $InstallerName
    ) {
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

    Static [psobject] GetSavedInstallerInfo(
        [string] $Type,
        [string] $InstallerDirectory,
        [string] $InstallerDescription
    ) {
        # Get the most recent date or signing time, or the latest version
        # of a pool of saved installers of particular software.

        ${Function:Select-SavedInstaller} = [RegCli]::GetSavedInstallerFilter()
        ${Function:Get-SavedInstallerInfo} = [RegCli]::GetSavedInstallerScript()
        Return Get-ChildItem $InstallerDirectory |
        Select-SavedInstaller -Description $InstallerDescription |
        Get-SavedInstallerInfo -Type $Type |
        Sort-Object -Descending |
        Select-Object -First 1
    }

    Static [System.Management.Automation.PSModuleInfo] NewUpdate(
        [string] $ExecutablePath,
        [string] $InstallerDirectory,
        [psobject] $VersionString,
        [string] $InstallerDescription,
        [switch] $UseSigningTime,
        [string] $InstallerChecksum,
        [string] $SoftwareName,
        [string] $InstallerExtension = '.exe'
    ) {
        # Load a dynamic module of helper functions for non-software specific tasks

        Return New-Module {
            Param (
                [string] $InstallPath,
                [string] $SaveTo,
                [psobject] $VersionString,
                [string] $InstallerDescription,
                [switch] $UseSigningTime,
                [string] $InstallerChecksum,
                [string] $SoftwareName,
                [string] $InstallerExtension
            )
            
            ${Function:Select-SavedInstaller} = [RegCli]::GetSavedInstallerFilter()
            ${Function:Get-SavedInstallerInfo} = [RegCli]::GetSavedInstallerScript()

            Function Get-ExecutableVersion {
                [CmdletBinding()]
                [OutputType([version])]
                Param ()

                (Get-Item -LiteralPath $InstallPath -ErrorAction SilentlyContinue).VersionInfo.FileVersionRaw
            }

            Set-Variable -Name 'VERSION_PREINSTALL' -Value (Get-ExecutableVersion) -Option Constant

            $Version =
                Switch ($VersionString) {
                    { $_ -is [string] } { 
                        Try {
                            [version] (
                                (
                                    & {
                                        Param ($VerStr)
                                        Switch ($VerStr -replace '\.\.','.') {
                                            { $_ -eq $VerStr } { Return $_ }
                                            Default { & $MyInvocation.MyCommand.ScriptBlock $_ }
                                        }
                                    } ($_ -replace '[^0-9\.]','.')
                                ) -replace '^\.' -replace '\.$'
                            )
                        } Catch { }
                    }
                    Default { $_ }
                }
            
            If ($Version -is [version]) {
                $Version = $Version | ForEach-Object {
                    [version] (
                        ($_.Major,$_.Minor,$_.Build,$_.Revision |
                        ForEach-Object {
                            Switch ($_) { 
                                { $_ -lt 0 } { 0 }
                                Default { $_ }
                            }
                        }) -join '.'
                    )
                }
            }

            $GetVersionInfo = & {
                Switch ($InstallerChecksum.Length) {
                    40 {
                        Return {
                            Param($Item)
                            $InstallerChecksum -ieq (Get-FileHash $Item.FullName 'SHA1').Hash 
                        }
                    }
                    64 {
                        Return {
                            Param($Item)
                            $InstallerChecksum -ieq (Get-FileHash $Item.FullName 'SHA256').Hash 
                        }
                    }
                    128 {
                        Return {
                            Param($Item)
                            $InstallerChecksum -ieq (Get-FileHash $Item.FullName 'SHA512').Hash
                        }
                    }
                }
                Switch (${Version}?.GetType()) {
                    'version'  {
                        Switch ($InstallerExtension) {
                            '.msi'  {
                                Return {
                                    Param($Item)
                                    ([version] [RegCli]::GetMsiDBRecord($Item.FullName, 'ProductVersion')) -eq $Version
                                }
                            }
                            Default {
                                Return {
                                    Param($Item)
                                    $Item.VersionInfo.FileVersionRaw -eq $Version
                                }
                            }
                        }
                    }
                    'datetime' {
                        If ($UseSigningTime) {
                            Return {
                                Param($Item)
                                (Get-AuthenticodeSigningTime $Item.FullName) -eq $Version
                            }
                        }
                        Else {
                            Return {
                                Param($Item)
                                $Item.LastWriteTime -eq $Version
                            }
                        }
                    }
                }
            }

            $InstallerPrefix = "$(${SoftwareName}?.ToLower().Trim() -replace ' ','_')$(If(!!$SoftwareName){'_'})"

            $InstallerPath = $(
                If ($UseSigningTime) { Import-Module "$PSScriptRoot\SigningTimeGetter.psm1" }
                Get-ChildItem $SaveTo |
                Select-SavedInstaller -AllowedExtensions @($InstallerExtension) -Description $InstallerDescription |
                Where-Object { & $GetVersionInfo $_ } |
                Select-Object -First 1
                Remove-Module SigningTimeGetter -ErrorAction SilentlyContinue
            ).FullName ??
            "$SaveTo\$InstallerPrefix$(
                $VersionString | ForEach-Object {
                    $_ -is [datetime] ? ('{0}.{1}.{2}' -f $_.Year,$_.DayOfYear,$_.TimeOfDay.TotalMinutes.ToString('#.##')):$_
                }
            )$InstallerExtension"

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
                        Return Get-SavedInstallerInfo -Type $Type -Item (Get-Item -LiteralPath (Get-InstallerPath) -ErrorAction SilentlyContinue)
                    }
                    Return $Script:Version
                }
                End { }
            }
            
            <#
            .SYNOPSIS
                Saves the installer to the installation path.
            #>
            Filter Start-InstallerDownload {
                [CmdletBinding()]
                [OutputType([System.Void])]
                Param (
                    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                    [ValidateNotNullOrEmpty()]
                    [Alias('Url','Link')]
                    [string] $InstallerUrl,
                    [Parameter(ValueFromPipelineByPropertyName)]
                    [ValidateNotNullOrEmpty()]
                    [ValidateScript({ $_.Length -in @(40, 64, 128) })]
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
                            Switch ($InstallerChecksum.Length) { 40 { 'SHA1' } 64 { 'SHA256' } 128 { 'SHA512' } })).Hash 
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
                Param ([switch] $UsePrefix)

                Try {
                    If ([string]::IsNullOrEmpty($VersionString)) { Throw }
                    $Installer = Get-Item (Get-InstallerPath) -ErrorAction Stop
                    $DescriptionCopy = !$UsePrefix ? [RegCli]::GetInstallerDescription($Installer):$InstallerPrefix
                    Write-Verbose 'Delete outdated installers...'
                    Get-ChildItem $Installer.Directory |
                    Select-SavedInstaller -Description $DescriptionCopy |
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
                    If ($PSBoundParameters.CompareInstalls) { Return (Get-ExecutableVersion) -lt $VERSION_PREINSTALL }
                    (Get-InstallerVersion -UseInstaller:$UseInstaller) -gt (Get-ExecutableVersion)
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
        } -ArgumentList $ExecutablePath,$InstallerDirectory,$VersionString,$InstallerDescription,$UseSigningTime,$InstallerChecksum,$SoftwareName,$InstallerExtension
    }

    Static [string] $CommonScriptVersion = '1.1'

    Static [System.Management.Automation.PSModuleInfo] GetCommonScript(
        [string] $Name,
        [string] $CommonPath
    ) {
        # Load the Invoke-CommonScript function

        New-Item -Path $CommonPath -ItemType Directory -ErrorAction SilentlyContinue
        Return New-Module {
            Param(
                [string] $Name,
                [string] $CommonPath
            )

            $CommonScript = "$CommonPath\$Name"
            $RequestArguments = @{
                Uri = "https://github.com/sangafabrice/reg-cli/raw/main/common/$Name@$([RegCli]::CommonScriptVersion).ps1"
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
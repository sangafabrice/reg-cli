#Requires -Version 7.0
#Requires -RunAsAdministrator

#Region RegCli class
Class RegCli {
    # RegCli is not meant to be instantiated
    # and only declares static functions
    # It is a singleton

    Static [string] $AutorunDirectory = "$(
        # Get the autorun directory
        # where the autorun batch script is located
        (@{
            Path = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Command Processor').Autorun
            ErrorAction = 'SilentlyContinue'
        } | ForEach-Object { Get-Item @_ })?.Directory
    )"

    Static [string] $OSArchitecture = $(
        # Get the OS architecture string
        If ([Environment]::Is64BitOperatingSystem) { 'x64' } Else { 'x86' }
    )

    Static [void] Get7Zip() {
        # Download 7zip if it is absent
        "$PSScriptRoot\7z.exe".Where({ !(Test-Path $_) }) |
        ForEach-Object {
            @{
                Source      = 'https://www.7-zip.org/a/7zr.exe'
                Destination = $_
            } | ForEach-Object { Start-BitsTransfer @_ }
        }
    }

    Static [void] ExpandInstaller($Path) {
        [RegCli]::ExpandInstaller($Path, $Null)
    }

    Static [void] ExpandInstaller($InstallerPath, $DestinationPath) {
        # Extract files from installer executable
        # to $DestinationPath directory
        # If $DestinationPath is null, then extract to
        # the folder which carries the basename of $InstallerPath 
        Get-Item $InstallerPath |
        ForEach-Object {
            Invoke-Expression ". '$PSScriptRoot\7z.exe' x -aoa -o'$(
                If ($Null -ne $DestinationPath) { $DestinationPath }
                Else { "$($_.Directory)\$($_.BaseName)" }
            )' '$($_.FullName)'"
        }
    }

    Static [void] ExpandChromium($InstallerPath, $ExecutablePath) {
        # Extract files from chromium installer executable
        # to $ExecutablePath parent directory
        $ExeName = $Null
        $ExeBaseName = $Null
        $ExeDir = $Null
        ,@($ExecutablePath -split '\\') |
        ForEach-Object {
            $ExeName = $_[-1]
            $ExeBaseName = & {
                [void] ($ExeName -match '(?<BaseName>[^\\/]+)\.exe$')
                $Matches.BaseName
            }
            $Count = $_.Count
            $ExeDir = $(If ($Count -gt 1) { $_[0..($Count - 2)] -join '\' } Else { $PWD })
            Switch ($(Try { Get-Item $InstallerPath } Catch { })) {
                { $Null -ne $_ } {
                    [RegCli]::ExpandInstaller($_.FullName)
                    New-Item $ExeDir -ItemType Directory -ErrorAction SilentlyContinue
                    $ExeDir = (Get-Item $ExeDir).FullName
                    $UnzipPath = "$($_.Directory)\$($_.BaseName)"
                    Try {
                        (Get-Item $UnzipPath).FullName |
                        ForEach-Object { Push-Location $_ }
                        (Get-Item .\*.7z)[0].FullName |
                        ForEach-Object {
                            [RegCli]::ExpandInstaller($_)
                            Remove-Item $_
                        }
                        Compress-Archive $ExeDir -DestinationPath "${Env:TEMP}\$($ExeBaseName)_$(Get-Date -Format 'yyMMddHHmm').zip"
                        Stop-Process -Name $($ExeBaseName) -Force -ErrorAction SilentlyContinue
                        Remove-Item "$ExeDir\*" -Recurse
                        Move-Item "$((Get-ChildItem $ExeName -Recurse).Directory)\*" $ExeDir
                        Pop-Location
                        Remove-Item $UnzipPath -Recurse
                    } Catch { }
                }
            }
        }
    }

    Static [void] SetChromiumVisualElementsManifest($VisualElementsManifest, $BackgroundColor) {
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

    Static [void] SetChromiumShortcut($ExecutablePath) {
        # Create shortcut link to chromium app
        (New-Object -ComObject 'WScript.Shell').CreateShortcut("${Env:ProgramData}\Microsoft\Windows\Start Menu\Programs\$(
            (Get-Item $ExecutablePath -ErrorAction SilentlyContinue).VersionInfo.FileDescription
        ).lnk") |
        ForEach-Object {
            $_.TargetPath = $ExecutablePath
            $_.Save()
        }
    }

    Static [string] DownloadSetup([uri] $SetupUrl) {
        # Download resource and save it to %TEMP% directory
        Try {
            $SetupUrl.Segments[-1] -match '((?<BaseName>^.+)(?<Extension>\.[^\.]+$))'
            $Result = "${Env:TEMP}\$($Matches.BaseName)_$(Get-Date -Format 'yyMMddHHmm')$($Matches.Extension)"
            Start-BitsTransfer -Source "$SetupUrl" -Destination $Result
            Return $Result
        }
        Catch { Return $Null }
    }

    Static [string] GetExeMachineType($ExecutablePath) {
        # Get the machine type of an application
        Switch ($(Try { (Get-Item $ExecutablePath).FullName } Catch { })) {
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
                    0x8664  { Return 'x64' }
                    0x14c   { Return 'x86' }
                }
            }
        }
        Return [RegCli]::OSArchitecture
    }

    Static [void] SetBatchRedirect($BatchName, $ExecutablePath) {
        # Create a batch redirect script in Autorun directory
        $ExeName = ($ExecutablePath -split '\\')[-1]
        Set-Content "$(
            Switch ([RegCli]::AutorunDirectory) {
                { ![string]::IsNullOrEmpty($_) } { $_ }
                Default { "$PWD" }
            }
        )\$BatchName.bat" -Value @"
@Echo OFF
If Not "%~1"=="--version" (
    If Not "%~1"=="-V" (
        Start "" /D "$($ExecutablePath -replace $ExeName -replace '\\$')" "$ExeName" %*
        GoTo :EOF
    )
)
For /F "Skip=1 Tokens=* Delims=." %%V In ('"WMIC DATAFILE WHERE Name="$($ExecutablePath -replace '\\','\\')" GET Version" 2^> Nul') Do (
    Echo %%V
    GoTo :EOF
)
"@
    }
}
#EndRegion

#Region Functions to be Exported

# The module becomes a Facade of the singleton RegCli class
# Since the class cannot be exported with Import-Module
# Use <using module RegCli> to access the class

Function Get-OsArchitecture { [RegCli]::OSArchitecture }

Function Get-ExecutableType {
    Param($Path)
    [RegCli]::GetExeMachineType($Path)
}

Function Get-Setup {
    Param($SetupUrl)
    [RegCli]::DownloadSetup($SetupUrl)
}

Function Expand-Chromium {
    Param($Path, $ExePath)
    [RegCli]::ExpandChromium($Path, $ExePath)
}

Function Set-ChromiumVisualElementsManifest {
    Param($InstallLocation, $BackgroundColor)
    [RegCli]::SetChromiumVisualElementsManifest($InstallLocation, $BackgroundColor)
}

Function Set-ChromiumShortcut {
    Param($ExePath)
    [RegCli]::SetChromiumShortcut($ExePath)
}

Function Set-BatchRedirect {
    Param($BatchName, $TargetPath)
    [RegCli]::SetBatchRedirect($BatchName, $TargetPath)
}

#EndRegion

#Region Module initialization tasks

# Download 7zip if it is absent
[RegCli]::Get7Zip()

#EndRegion
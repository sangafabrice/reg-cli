[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (& {
            Param($Path)
            $Pattern = '(?<Drive>^.+):'
            If ($Path -match $Pattern -or $PWD -match $Pattern) {
                Return $Matches.Drive -iin @((Get-PSDrive -PSProvider FileSystem).Name)
            }
            Return $False
        } $_) -and
        $(
            @{
                LiteralPath = $_
                ErrorAction = 'SilentlyContinue'
            } | ForEach-Object { Get-Item @_ }
        ).FullName -ine $PSScriptRoot
    })] [string]
    $InstallLocation = "${Env:LOCALAPPDATA}\Microsoft\WindowsApps\yq.exe",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (Get-Item -LiteralPath $_).PSDrive.Name -iin 
        @((Get-PSDrive -PSProvider FileSystem).Name)
    })] [string]
    $SaveTo = $PSScriptRoot
)

& {
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $ExeName = "yq_windows_$(Switch (Get-ExecutableType $InstallLocation) { 'x64' { 'amd64' } Default { '386' } }).exe"
    $UpdateInfo = 
        Get-DownloadInfo -PropertyList @{
            RepositoryId = 'mikefarah/yq'
            AssetPattern = "$ExeName$|checksums.*$"
        } |
        Where-Object {
            @($_.Version,$_.Link) |
            ForEach-Object { $_ -notin @($Null, '') }
        }
    $InstallerDescription = 'Yq data format processor'
    If ($UpdateInfo.Count -le 0) { Return }
    Try {
        New-RegCliUpdate $InstallLocation $SaveTo $UpdateInfo.Version $InstallerDescription |
        Import-Module -Verbose:$False -Force
        If ($UpdateInfo.Count -gt 0) {
            $SelectLink = {
                Param($Obj, $FileName)
                $Obj.Link.Url.Where({ "$_" -like "*$FileName" })
            }
            $RqstContent = {
                Param($Obj, $FileName)
                ((Invoke-WebRequest "$(& $SelectLink $Obj $FileName)" -Verbose:$False).Content |
                ForEach-Object { [char] $_ }) -join '' -split "`n"
            }
            $ShaIndex = "P$([array]::IndexOf((& $RqstContent $UpdateInfo 'checksums_hashes_order'),'SHA-512') + 2)"
            Start-InstallerDownload "$(& $SelectLink $UpdateInfo $ExeName)" "$(
                $(& $RqstContent $UpdateInfo 'checksums' |
                ConvertFrom-String |
                Select-Object P1,$ShaIndex |
                Where-Object P1 -Like $ExeName).$ShaIndex
            )" -Verbose:$VerbosePreferenceBool
        }
        Try { 
            Remove-Item "$SaveTo\v$(
                @(((. $InstallLocation --version) -split ' ')[-1]).
                Where({ [version] $_ -ne [version] (Get-InstallerVersion) }) |
                ForEach-Object { $_ }
            ).exe" -ErrorAction SilentlyContinue -Force
        } Catch { }
        $TestInstall = $False
        $InstallDirectory = $InstallLocation -replace '(\\|/)[^\\/]+$'
        If ([string]::IsNullOrEmpty($InstallDirectory)) { $InstallDirectory = $PWD }
        If ("$((Get-Item $InstallDirectory -ErrorAction SilentlyContinue).FullName)" -ieq (Get-Item $SaveTo).FullName) {
            # If $InstallLocation directory is equal to $SaveTo
            @{
                NewName = & {
                    [void] ($InstallLocation -match '(?<ExeName>[^\\/]+$)')
                    $Matches.ExeName
                }
                LiteralPath = Get-InstallerPath
                ErrorAction = 'SilentlyContinue'
                Force = $True
            } | ForEach-Object { Rename-Item @_ }
            $TestInstall = Test-Path $InstallLocation
        } Else {
            New-Item $InstallDirectory -ItemType Directory -Force | Out-Null
            @{
                Path = $InstallLocation
                ItemType = 'SymbolicLink'
                Value = Get-InstallerPath
                ErrorAction = 'SilentlyContinue'
                Force = $True
            } | ForEach-Object { New-Item @_ | Out-Null }
            $TestInstall = (Get-Item (Get-Item $InstallLocation).Target).FullName -ieq (Get-Item (Get-InstallerPath)).FullName
        }
        If ($TestInstall) { Write-Verbose "$InstallerDescription $(Get-InstallerVersion) installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Yq data format processor.
.DESCRIPTION
    The script installs or updates Yq data format processor on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the console app.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %LOCALAPPDATA%\Microsoft\WindowsApps\yq.exe.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Yq -ErrorAction SilentlyContinue

    PS > .\UpdateYq.ps1 -InstallLocation C:\ProgramData\Yq\yq.exe -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Yq | Select-Object Name
    Name
    ----
    yq.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    v4.25.3.exe
    UpdateYq.ps1

    Install Yq to 'C:\ProgramData\Yq' and save its setup installer to the current directory.
#>
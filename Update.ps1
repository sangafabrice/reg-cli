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

$ExeName = "yq_windows_$(Switch (Get-ExecutableType $InstallLocation) { 'x64' { 'amd64' } Default { '386' } }).exe"
Switch (
    Get-DownloadInfo -PropertyList @{
        RepositoryId = 'mikefarah/yq'
        AssetPattern = "$ExeName$|checksums.*$"
    }
) {
    {
        @($_.Version,$_.Link) |
        ForEach-Object { $_ -notin @($Null, '') }
    } {
        $SelectLink = {
            Param($Obj, $FileName)
            $Obj.Link.Url.Where({ "$_" -like "*$FileName" })
        }
        $RqstContent = {
            Param($Obj, $FileName)
            ((Invoke-WebRequest "$(& $SelectLink $Obj $FileName)").Content |
            ForEach-Object { [char] $_ }) -join '' -split "`n"
        }
        $ShaIndex = "P$([array]::IndexOf((& $RqstContent $_ 'checksums_hashes_order'),'SHA-512') + 2)"
        $Installer = "$SaveTo\$($_.Version).exe"
        $Checksum = $(& $RqstContent $_ 'checksums' |
            ConvertFrom-String |
            Select-Object P1,$ShaIndex |
            Where-Object P1 -Like $ExeName).$ShaIndex
        If (!(Test-Path $Installer)) {
            Save-Installer "$(& $SelectLink $_ $ExeName)" |
            ForEach-Object { 
                If ($Checksum -ieq (Get-FileHash $_ SHA512).Hash) {
                    Try { Remove-Item "$SaveTo\v$(((. $InstallLocation --version) -split ' ')[-1]).exe" -Force } Catch { }
                    Move-Item $_ -Destination $Installer
                } 
            }
        }
        @{
            Path = $InstallLocation
            ItemType = 'SymbolicLink'
            Value = $Installer
            ErrorAction = 'SilentlyContinue'
            Force = $True
        } | ForEach-Object { New-Item @_ }
    }
}
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
    $InstallLocation = "${Env:LOCALAPPDATA}\Microsoft\WindowsApps\youtube-dl.exe",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (Get-Item -LiteralPath $_).PSDrive.Name -iin 
        @((Get-PSDrive -PSProvider FileSystem).Name)
    })] [string]
    $SaveTo = $PSScriptRoot
)

Switch (
    Get-DownloadInfo -PropertyList @{
        RepositoryId = 'ytdl-org/youtube-dl'
        AssetPattern = 'youtube-dl.exe$|SHA2-512SUMS$'
    }
) {
    {
        @($_.Version,$_.Link) |
        ForEach-Object { $_ -notin @($Null, '') }
    } {
        $SaveToContent = Get-Item "$SaveTo\*"
        $Version = [version]$_.Version
        $Installer = $SaveToContent.Where({ [version]$_.VersionInfo.ProductVersion -eq $Version }).FullName ??
            "$SaveTo\$($_.Version).exe"
        $Checksum = (((Invoke-WebRequest "$($_.Link.Where({$_.Url -like '*512SUMS'}).Url)").Content |
            ForEach-Object { [char] $_ }) -join '' -split "`n" |
            ConvertFrom-String).Where({$_.P2 -ieq 'youtube-dl.exe'}).P1
        If (!(Test-Path $Installer)) {
            Save-Installer "$($_.Link.Where({$_.Url -like '*.exe'}).Url)" |
            ForEach-Object { 
                If ($Checksum -ieq (Get-FileHash $_ SHA512).Hash) {
                    $SaveToContent.Where({ $_.VersionInfo.FileDescription -ieq 'YouTube video downloader' }) |
                    Remove-Item
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
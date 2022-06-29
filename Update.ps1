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
    $InstallLocation = "${Env:ProgramData}\GoogleChrome",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (Get-Item -LiteralPath $_).PSDrive.Name -iin 
        @((Get-PSDrive -PSProvider FileSystem).Name)
    })] [string]
    $SaveTo = $PSScriptRoot
)

$BaseNameLocation = "$InstallLocation\chrome"
Switch ($(
    "$(Get-ExecutableType "$BaseNameLocation.exe")" |
    ForEach-Object {
        Get-DownloadInfo -PropertyList @{
            UpdateServiceURL = 'https://update.googleapis.com/service/update2'
            ApplicationID    = '{8A69D345-D564-463c-AFF1-A69D9E530F96}'
            OwnerBrand       = "$(Switch ($_) { 'x64' { 'YTUH' } Default { 'GGLS' } })"
            ApplicationSpec  = "$(Switch ($_) { 'x64' { 'x64-stable-statsdef_1' } Default { 'stable-arch_x86-statsdef_1' } })"
        } -From Omaha
    }
)) {
    {
        @($_.Version,$_.Link,$_.Checksum) |
        ForEach-Object { $_ -notin @($Null, '') }
    } {
        $Installer = "$SaveTo\$($_.Version).exe"
        $Checksum = $_.Checksum
        If (!(Test-Path $Installer)) {
            Save-Installer "$($_.Link.Where({ "$_" -like 'https://*' }, 'First'))" |
            ForEach-Object {
                If ($Checksum -ieq (Get-FileHash $_ SHA256).Hash) {
                    Remove-Item "$SaveTo\*" -Exclude (Get-Item $PSCommandPath).Name
                    Move-Item $_ -Destination $Installer
                }
            }
        }
        If (([version] $_.Version) -gt $(Try { [version] $(
            @{
                LiteralPath = "$BaseNameLocation.exe"
                ErrorAction = 'SilentlyContinue'
            } | ForEach-Object { Get-ChildItem @_ }
        ).VersionInfo.ProductVersion } Catch { })) {
            Expand-ChromiumInstaller $Installer "$BaseNameLocation.exe"
        }
    }
}
Set-ChromiumVisualElementsManifest "$BaseNameLocation.VisualElementsManifest.xml" '#5F6368'
Set-ChromiumShortcut "$BaseNameLocation.exe"
Set-BatchRedirect 'chrome' "$BaseNameLocation.exe"
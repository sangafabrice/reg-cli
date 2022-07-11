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
    $InstallLocation = "${Env:ProgramData}\MSEdge",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        (Get-Item -LiteralPath $_).PSDrive.Name -iin 
        @((Get-PSDrive -PSProvider FileSystem).Name)
    })] [string]
    $SaveTo = $PSScriptRoot
)

& {
    $BaseNameLocation = "$InstallLocation\msedge"
    $NameLocation = "$BaseNameLocation.exe"
    $VerbosePreferenceBool = $VerbosePreference -ine 'SilentlyContinue'
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo = 
        $(Try {
            $UriBasis = "https://msedge.api.cdp.microsoft.com/api/v1.1/contents/Browser/namespaces/Default/names/msedge-stable-win-$(Get-ExecutableType $NameLocation)/versions/"
            $WebRequestArgs = {
                Param($ActionString)
                Return @{
                    Uri = "$UriBasis$ActionString"
                    UserAgent = 'winhttp'
                    Method = 'POST'
                    Body = '{"targetingAttributes":{}}'
                    Headers = @{ 'Content-Type' = 'application/json' }
                    Verbose = $False
                }
            }
            & $WebRequestArgs 'latest?action=select' |
            ForEach-Object { 
                Invoke-WebRequest @_ |
                ConvertFrom-Json |
                ForEach-Object {
                    $Version = $_.ContentId.Version
                    & $WebRequestArgs "$Version/files?action=GenerateDownloadInfo" |
                    ForEach-Object { 
                        (Invoke-WebRequest @_).Content |
                        ConvertFrom-Json |
                        Select-Object @{
                            Name = 'Size'
                            Expression = { $_.SizeInBytes }
                        },@{
                            Name = 'Version'
                            Expression = { $Version }
                        },@{
                            Name = 'Name'
                            Expression = { $_.FileId }
                        },@{
                            Name = 'Link'
                            Expression = { $_.Url }
                        } |
                        Sort-Object -Property Size -Descending |
                        Select-Object Version,Link,Name -First 1
                    }
                }
            }
        } Catch { }) |
        Where-Object {
            @($_.Version,$_.Link,$_.Name) |
            ForEach-Object { $_ -notin @($Null, '') }
        }
    $InstallerVersion = $UpdateInfo.Version
    $SoftwareName = 'Microsoft Edge'
    $InstallerDescription = "$SoftwareName Installer"
    If ($UpdateInfo.Count -le 0) {
        $InstallerVersion = "$(
            Get-ChildItem $SaveTo |
            Select-Object VersionInfo -ExpandProperty VersionInfo |
            Where-Object { $_.FileDescription -ieq $InstallerDescription } |
            ForEach-Object { [version] $_.ProductVersion } |
            Sort-Object -Descending |
            Select-Object -First 1
        )"
    }
    Try {
        New-RegCliUpdate $NameLocation $SaveTo $InstallerVersion $InstallerDescription |
        Import-Module -Verbose:$False -Force
        If ($UpdateInfo.Count -gt 0) {
            Start-InstallerDownload $UpdateInfo.Link -Name $UpdateInfo.Name -Force -Verbose:$VerbosePreferenceBool
        }
        Remove-InstallerOutdated -Verbose:$VerbosePreferenceBool
        If (Test-InstallOutdated) {
            Write-Verbose 'Current install is outdated or not installed...'
            Expand-ChromiumInstaller (Get-InstallerPath) $NameLocation
        }
        Set-ChromiumVisualElementsManifest "$BaseNameLocation.VisualElementsManifest.xml" '#173A73'
        Set-ChromiumShortcut $NameLocation
        Edit-TaskbarShortcut $NameLocation
        Set-BatchRedirect 'msedge' $NameLocation
        #Region: Set shell verb to open a PDF file as an MSEdge app
        @{
            Path = 'Registry::HKEY_CLASSES_ROOT\MSEdgePDF\shell\open\command'
            Name = '(default)'
            Value = '"' + $NameLocation + '" --app="%1"'
            Force = $True
        } | ForEach-Object { Set-ItemProperty @_ }
        #EndRegion
        If (!(Test-InstallOutdated)) { Write-Verbose "$SoftwareName $InstallerVersion installation complete." }
    } 
    Catch { }
}

<#
.SYNOPSIS
    Updates Microsoft Edge browser software.
.DESCRIPTION
    The script installs or updates Microsoft Edge browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\MSEdge.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\MSEdge -ErrorAction SilentlyContinue

    PS > .\UpdateMSEdge.ps1 -InstallLocation C:\ProgramData\MSEdge -SaveTo .

    PS > Get-ChildItem C:\ProgramData\MSEdge | Select-Object Name -First 5
    Name
    ----
    BHO
    EBWebView
    edge_feedback
    Extensions
    identity_proxy
    Locales

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    103.0.1264.49.exe
    UpdateMSEdge.ps1

    Install MSEdge browser to 'C:\ProgramData\MSEdge' and save its setup installer to the current directory.
#>
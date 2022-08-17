[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\GoogleChrome",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $BaseNameLocation = "$InstallLocation\chrome"
    $NameLocation = "$BaseNameLocation.exe"
    Write-Verbose 'Retrieve install or update information...'
    $MachineType = "$(Get-ExecutableType $NameLocation)"
    $UpdateInfo = $(
        Try {
            Get-DownloadInfo -PropertyList @{
                UpdateServiceURL = 'https://update.googleapis.com/service/update2'
                ApplicationID    = '{8A69D345-D564-463c-AFF1-A69D9E530F96}'
                OwnerBrand       = "$(
                    Switch ($MachineType) {
                        'x64'   { 'YTUH' }
                        Default { 'GGLS' }
                    }
                )"
                ApplicationSpec  = "$(
                    Switch ($MachineType) {
                        'x64'   { 'x64-stable-statsdef_1' }
                        Default { 'stable-arch_x86-statsdef_1' }
                    }
                )"
            } -From Omaha | Select-NonEmptyObject
        }
        Catch { }
    )
    If ($UpdateInfo) { $UpdateInfo.Link = "$($UpdateInfo.Link.Where({ "$_" -like 'https://*' }, 'First'))" }
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $UpdateInfo
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Google Chrome'
            InstallerDescription = 'Google Chrome Installer'
            BatchRedirectName = 'chrome'
            VisualElementManifest = @{
                BaseNameLocation = $BaseNameLocation
                HexColor = '#2D364C'
            }
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Google Chrome browser software.
.DESCRIPTION
    The script installs or updates Google Chrome browser on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\GoogleChrome.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\GoogleChrome -ErrorAction SilentlyContinue

    PS > .\UpdateGoogleChrome.ps1 -InstallLocation C:\ProgramData\GoogleChrome -SaveTo .

    PS > Get-ChildItem C:\ProgramData\GoogleChrome | Select-Object Name
    Name
    ----
    103.0.5060.66
    chrome_proxy.exe
    chrome.exe
    chrome.VisualElementsManifest.xml

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    103.0.5060.66.exe
    UpdateGoogleChrome.ps1

    Install Google Chrome browser to 'C:\ProgramData\GoogleChrome' and save its setup installer to the current directory.
#>
[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Maxthon",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Maxthon.exe"
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                @{
                    Uri = "https://www.maxthon.com/mx6/formal-$(
                        Switch (Get-ExecutableType $NameLocation) { 'x64' { '64' } 'x86' { '32' } }
                    )/dl"
                    Method  = 'HEAD'
                    MaximumRedirection = 0
                    SkipHttpErrorCheck = $True
                    ErrorAction = 'SilentlyContinue'
                    Verbose = $False
                } | ForEach-Object { (Invoke-WebRequest @_).Headers.Location?[0] } |
                Select-Object @{
                    Name = 'Version'
                    Expression = { (([uri] $_).Segments?[-1] -split '_')?[1] }
                },@{
                    Name = 'Link'
                    Expression = { $_ }
                } | Select-NonEmptyObject
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Maxthon'
            InstallerDescription = 'Maxthon Installer'
            BatchRedirectName = 'maxthon'
            VisualElementManifest = @{
                BaseNameLocation = "$InstallLocation\chrome"
                HexColor = '#5F6368'
            }
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Maxthon software.
.DESCRIPTION
    The script installs or updates Maxthon on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Maxthon".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Maxthon' -ErrorAction SilentlyContinue

    PS > .\UpdateMaxthon.ps1 -InstallLocation 'C:\ProgramData\Maxthon' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Maxthon' | Select-Object Name -First 5
    Name
    ----
    6.1.3.3000
    chrome_proxy.exe
    chrome.VisualElementsManifest.xml
    Maxthon.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    6.1.3.3000.exe
    UpdateMaxthon.ps1

    Install Maxthon to 'C:\ProgramData\Maxthon' and save its setup installer to the current directory.
#>
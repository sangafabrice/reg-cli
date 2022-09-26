[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Messenger",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try { Get-DownloadInfo -From Messenger }
                Catch { }
            )
            NameLocation = "$InstallLocation\Messenger.exe"
            SaveTo = $SaveTo
            SoftwareName = 'Messenger'
            InstallerDescription = 'Messenger by Facebook'
            InstallerType = 'NSIS'
            CompareInstalls = $True
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Messenger software.
.DESCRIPTION
    The script installs or updates Messenger on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Messenger".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Messenger' -ErrorAction SilentlyContinue

    PS > .\UpdateMessenger.ps1 -InstallLocation 'C:\ProgramData\Messenger' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Messenger' | Select-Object Name -First 5
    Name
    ----
    resources
    CrashpadHandlerWindows.exe
    libEGL.dll
    libGLESv2.dll
    Messenger.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    messenger_2022.238.356.18.exe
    UpdateMessenger.ps1

    Install Messenger to 'C:\ProgramData\Messenger' and save its setup installer to the current directory.
#>
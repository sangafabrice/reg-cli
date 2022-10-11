[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Darktable",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    Write-Verbose 'Retrieve install or update information...'
    $UpdateInfo =
        Try { Get-DownloadInfo -From Darktable }
        Catch { }
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $UpdateInfo
            NameLocation = "$InstallLocation\bin\darktable.exe"
            SaveTo = $SaveTo
            SoftwareName = 'Darktable'
            ShortcutName = 'Darktable Photo Workflow'
            UseTimestamp = $True
            Checksum = $UpdateInfo.Checksum
            UsePrefix = $True
            InstallerType = 'Basic'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Darktable photo editor software.
.DESCRIPTION
    The script installs or updates Darktable photo editor on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Darktable.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Darktable -ErrorAction SilentlyContinue

    PS > .\UpdateDarktable.ps1 -InstallLocation C:\ProgramData\Darktable -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Darktable\bin\ | Where-Object Name -Like 'darktable*' | Select-Object Name
    Name
    ----
    darktable-chart.exe
    darktable-cli.exe
    darktable-cltest.exe
    darktable-generate-cache.exe
    darktable-rs-identify.exe
    darktable.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    darktable_release-4.0.1.exe
    UpdateDarktable.ps1

    Install Darktable to 'C:\ProgramData\Darktable' and save its setup installer to the current directory.
#>
[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Inkscape",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\bin\inkscape.exe"
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try {
                    Get-DownloadInfo -PropertyList @{
                        OSArch = Get-ExecutableType $NameLocation
                    } -From Inkscape
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Inkscape'
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
    Updates Inkscape vector graphics editor software.
.DESCRIPTION
    The script installs or updates Inkscape vector graphics editor on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to %ProgramData%\Inkscape.
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem C:\ProgramData\Inkscape -ErrorAction SilentlyContinue

    PS > .\UpdateInkscape.ps1 -InstallLocation C:\ProgramData\Inkscape -SaveTo .

    PS > Get-ChildItem C:\ProgramData\Inkscape\bin\ | Where-Object Name -Like 'ink*' | Select-Object Name
    Name
    ----
    inkscape.com
    inkscape.exe
    inkview.com
    inkview.exe

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    inkscape_1.2.1.exe
    UpdateInkscape.ps1

    Install Inkscape to 'C:\ProgramData\Inkscape' and save its setup installer to the current directory.
#>
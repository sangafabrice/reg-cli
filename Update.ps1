[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\RunJS",
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
                Try {
                    Get-DownloadInfo -PropertyList @{ 
                        RepositoryId = 'lukehaas/RunJS'
                        AssetPattern = 'RunJS\-Setup\-(\d+\.)+exe$' 
                    }
                }
                Catch { }
            )
            NameLocation = "$InstallLocation\RunJS.exe"
            SaveTo = $SaveTo
            SoftwareName = 'RunJS'
            InstallerDescription = 'The JavaScript and TypeScript playground for your desktop'
            InstallerType = 'NSIS'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates RunJS software.
.DESCRIPTION
    The script installs or updates RunJS on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\RunJS".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\RunJS' -ErrorAction SilentlyContinue

    PS > .\UpdateRunJS.ps1 -InstallLocation 'C:\ProgramData\RunJS' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\RunJS' | Select-Object Name -First 5
    Name
    ----
    locales
    resources
    swiftshader
    chrome_100_percent.pak
    chrome_200_percent.pak

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    runjs_v2.6.0.exe
    UpdateRunJS.ps1

    Install RunJS to 'C:\ProgramData\RunJS' and save its setup installer to the current directory.
#>
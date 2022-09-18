[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Atom",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\atom.exe"
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try {
                    Get-DownloadInfo -PropertyList @{
                        RepositoryId = 'atom/atom'
                        AssetPattern = "AtomSetup$(If((Get-ExecutableType $NameLocation) -eq 'x64'){ '\-x64' })\.exe$"
                    }
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Atom'
            InstallerDescription = 'A hackable text editor for the 21st Century.'
            InstallerType = 'Squirrel'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Atom software.
.DESCRIPTION
    The script installs or updates Atom on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Atom".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Atom' -ErrorAction SilentlyContinue

    PS > .\UpdateAtom.ps1 -InstallLocation 'C:\ProgramData\Atom' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Atom' | Select-Object Name -First 5
    Name
    ----
    locales
    resources
    atom_ExecutionStub.exe
    atom.exe
    chrome_100_percent.pak

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    atom_v1.60.0.exe
    UpdateAtom.ps1

    Install Atom to 'C:\ProgramData\Atom' and save its setup installer to the current directory.
#>
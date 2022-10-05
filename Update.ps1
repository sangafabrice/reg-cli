[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Notepad++",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Notepad++.exe"
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
                    } -From Notepad++
                }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Notepad++'
            InstallerDescription = 'Notepad++ : a free (GNU) source code editor'
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Notepad++ software.
.DESCRIPTION
    The script installs or updates Notepad++ editor on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Notepad++".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Notepad++' -ErrorAction SilentlyContinue

    PS > .\UpdateNotepad++.ps1 -InstallLocation 'C:\ProgramData\Notepad++' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Notepad++' | Select-Object Name -First 5
    Name
    ----
    $_14_
    $_15_
    $_17_
    $PLUGINSDIR
    autoCompletion

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    notepad++_v8.4.6.exe
    UpdateNotepad++.ps1

    Install Notepad++ to 'C:\ProgramData\Notepad++' and save its setup installer to the current directory.
#>
[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallLocation $_ $PSScriptRoot })]
    [string]
    $InstallLocation = "${Env:ProgramData}\Grammarly",
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-InstallerLocation $_ })]
    [string]
    $SaveTo = $PSScriptRoot
)

& {
    $NameLocation = "$InstallLocation\Grammarly.Desktop.exe"
    $TempRegLocation = "${Env:TEMP}\grammarly.windows-extension.reg"
    Try {
        $HttpResponse = @{
            Uri = 'https://raw.githubusercontent.com/sangafabrice/reg-cli' +
                '/grammarly/grammarly.windows-extension.reg'
            Verbose = $False
        } | ForEach-Object { Invoke-WebRequest @_ }
        $RegFileLocation = "$PSScriptRoot\grammarly-$(
            ($HttpResponse.Headers.ETag -replace '"').Substring(0,8)
        ).reg"
        If (!(Test-Path $RegFileLocation)) {
            $HttpResponse.Content | Out-String | Out-File $RegFileLocation
        }
    }
    Catch { }
    Try {
        $UpdateModule =
            Import-CommonScript chrome-installer |
            Import-Module -PassThru -Force -Verbose:$False
        @{
            UpdateInfo = $(
                Write-Verbose 'Retrieve install or update information...'
                Try { Get-DownloadInfo -From Grammarly }
                Catch { }
            )
            NameLocation = $NameLocation
            SaveTo = $SaveTo
            SoftwareName = 'Grammarly Desktop'
            InstallerDescription = 'Grammarly for Windows'
            CompareInstalls = $True
            Verbose = $VerbosePreference -ine 'SilentlyContinue'
        } | ForEach-Object { Invoke-CommonScript @_ }
        If (Test-Path $NameLocation) {
            Invoke-Expression "@`"`n$(Get-Content $RegFileLocation -Raw)`n`"@" |
            Out-File $TempRegLocation
            @{
                FilePath = "${Env:Windir}\System32\Reg.exe"
                ArgumentList = "Import $TempRegLocation"
                WindowStyle = 'Hidden'
                Wait = $True
            } | ForEach-Object { Start-Process @_ }
            Remove-Item $TempRegLocation -Force
        }
    }
    Catch { }
    Finally { $UpdateModule | Remove-Module -Verbose:$False }
}

<#
.SYNOPSIS
    Updates Grammarly software.
.DESCRIPTION
    The script installs or updates Grammarly on Windows.
.NOTES
    Required: at least Powershell Core 7.
.PARAMETER InstallLocation
    Path to the installation directory.
    It is restricted to file system paths.
    It does not necessary exists.
    It defaults to "%ProgramData%\Grammarly".
.PARAMETER SaveTo
    Path to the directory of the downloaded installer.
    It is an existing file system path.
    It defaults to the script directory.
.EXAMPLE
    Get-ChildItem 'C:\ProgramData\Grammarly' -ErrorAction SilentlyContinue

    PS > .\UpdateGrammarly.ps1 -InstallLocation 'C:\ProgramData\Grammarly' -SaveTo .

    PS > Get-ChildItem 'C:\ProgramData\Grammarly' | Select-Object Name -First 5
    Name
    ----
    $PLUGINSDIR
    cs
    de
    es
    fr

    PS > Get-ChildItem | Select-Object Name
    Name
    ----
    grammarly_2022.266.750.77.exe
    UpdateGrammarly.ps1

    Install Grammarly to 'C:\ProgramData\Grammarly' and save its setup installer to the current directory.
#>
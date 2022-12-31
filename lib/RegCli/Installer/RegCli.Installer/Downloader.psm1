#Requires -Version 7.0
#Requires -RunAsAdministrator
using module '..\..\PowerShell.ValidationScript'
using module '..\..\PowerShell.DynamicParameter'
using module '..\..\PowerShell.Installer.AllowedList'
using module '..\..\System.Extended.IO'

Class Downloader {
    # Downloader is not meant to be instantiated and only declares static methods.
    # It is a set of help methods to download a specified software installer

    Static [scriptblock] Create([System.IO.FileInfo] $InstallerPath) {
        # Get the scriptblock that downloads an installer from a specified URL, verifies
        # the installer integrity with checksum or signature, and move the installer to the
        # $InstallerPath location from where the application is installed.
        
        # The parent directory of the installer file system must exist.
        [System.IO.Path]::GetDirectoryName($InstallerPath).ForEach{ If (![System.IO.Directory]::Exists($_)) { Throw ('"{0}" does not exist.' -f $_) } }
        # Start building the args for get_downloader() scriptblock in a hashtable.
        # Set the file name of the downloaded resource in the Temp:\ directory.
        $InstallerName = [System.IO.Path]::GetFileName($InstallerPath)
        # The scriptblock to validate that the url starts with https for secure connexion.
        $ValidateSSL = { Param([uri] $Url) $Url.Scheme -ieq 'https' }
        Return {
            [CmdletBinding()]
            Param (
                [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
                [ValidateNotNullOrEmpty()]
                [uri] $Link,
                [Parameter(ValueFromPipelineByPropertyName)]
                [ValidateNotNullOrEmpty()]
                [ValidateScript({ [ValidationScript]::ChecksumLength($_) })]
                [string] $Checksum
            )
            # The parameter -SkipSslValidation is only defined when the URL does not end with 'https'.
            DynamicParam { If (!(& $Script:ValidateSSL $Link)) { [DynamicParameter]::Create('SkipSslValidation', [switch]) } }
            Process {
                # Process only if the installer file system does not exist.
                If (![System.IO.File]::Exists($Script:InstallerPath)) {
                    # Validate URL or skip validation if the option is specified.
                    If (!($PSBoundParameters.ContainsKey('SkipSslValidation') -or (& $Script:ValidateSSL $Link))) { Throw 'The URL is not allowed.' }
                    ([Downloader]::download_installer($Link, $InstallerName)).Where{
                        # Validate the integrity of the installer file system with hashcode if -Checksum specified.
                        If ($PSBoundParameters.ContainsKey('Checksum')) { $Checksum -ieq (Get-FileHash "$_" ([HashAlgorithm] $Checksum.Length)).Hash }
                        # Validate the integrity of the installer file system with signature if -Checksum not specified.
                        Else { (Get-AuthenticodeSignature "$_").Status -ieq 'Valid' }
                        # Move downloaded installer from Temp:\ to the specified installer path when creating the function.
                    } | Move-Item -Destination "$Script:InstallerPath" -Force -ErrorAction SilentlyContinue
                }
            }
            <#
            .SYNOPSIS
                Downloads an installer.
            .DESCRIPTION
                The command downloads a specified installer and saves it to an existing local directory.
                The intermediate step in between downloading and saving is to check the integrity of the installer.
            .PARAMETER Link
                Specifies the installer resource location online.
            .PARAMETER Checksum
                Specifies the checksum code of the installer.
            .PARAMETER Force
                Specifies that SSL validation be skipped.
                It is a dynamic parameter that is only available when the URL does not start with https.
            .EXAMPLE
                ${Function:Start-InstallerDownload} = [Downloader]::Create('C:\Software\msedge_106.0.1370.52.exe')
                PS > Get-Item 'C:\Software\msedge_106.0.1370.52.exe' -ErrorAction SilentlyContinue
                PS > Start-InstallerDownload -Link 'http://msedge.b.tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/8cbf88e2-28a2-4799-ac29-870d1fb99308?P1=1667578561&P2=404&P3=2&P4=acd8ckzfGeXT1dmQzuCmWLWfkNnC7wF73mvbuot6AfxDDNxCon%2fv%2boaIHE78YRc6lAAyUoiCGXD%2bD8AFcf9wBw%3d%3d' -Name 'MicrosoftEdge_X64_106.0.1370.52.exe' -Force
                PS > Get-Item 'C:\Software\msedge_106.0.1370.52.exe' | Select-Object Name
                Name
                ----
                msedge_106.0.1370.52.exe
            #>
        }.GetNewClosure()
    }

    Static Hidden [System.IO.FileInfo] download_installer([uri] $InstallerUrl, [string] $InstallerName) {
        # Download resource and save it to Temp:\ directory
        
        Try {
            # Validate local installer name if it is a valid file system name
            If ([System.Extended.IO.Path]::IsFileNameValid($InstallerName)) {
                # Build path to local installer name in the Temp:\ directory and differentiated by date
                $Result = "${Env:TEMP}\$([system.IO.Path]::GetFileNameWithoutExtension($InstallerName))_$(Get-Date -Format 'yyMMddHHmmss')$([system.IO.Path]::GetExtension($InstallerName))"
                # Download from the specified URL to the installer path
                Start-BitsTransfer -Source "$InstallerUrl" -Destination $Result
                If (!$?) { Invoke-WebRequest -Uri "$InstallerUrl" -OutFile $Result }
                Return $Result
            }
        }
        Catch { }
        Return $Null
    }
}
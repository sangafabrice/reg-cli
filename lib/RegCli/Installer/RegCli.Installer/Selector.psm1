#Requires -Version 7.0
#Requires -RunAsAdministrator
using module '..\RegCli'
using module '..\..\PowerShell.Installer.AllowedList'
using module '..\..\PowerShell.ValidationScript'
using module '..\..\PowerShell.DynamicParameter'

Class Selector {
    # Selector is not meant to be instantiated and only declares static methods.
    # It is a set of help methods to identify and select a specified application installer
    # file system items from a pool of saved installers. The idea is to avoid downloading
    # a version of an installer that is already saved locally.

    Static [scriptblock] Create([hashtable] $Description) {
        # Get the scriptblock that selects installer specified by a description.

        # Validate the description hashtable Value key value.
        If (!$Description.Value) { Throw 'The description value cannot be null or empty.' }
        # Declare selector scriptblocks to filter installers and properties.
        $SelectInstallerItem = [Selector]::get_filter()
        $SelectInstallerInfo = [Selector]::get_selector()
        Return {
            [CmdletBinding(DefaultParameterSetName='Latest')]
            [OutputType([Installer])]
            Param(
                [Parameter(Mandatory, ValueFromPipeline)]
                [ValidateNotNullOrEmpty()]
                [ValidateScript({ [System.IO.File]::Exists($_) })]
                [System.IO.FileInfo] $Item,
                [VersionType] $Type = 'Version',
                [Parameter(ParameterSetName='Latest')]
                [switch] $Latest,
                [Parameter(ParameterSetName='Checksum')]
                [ValidateScript({ [ValidationScript]::ChecksumLength($_) })]
                [string] $Checksum
            )
            # The parameter -FullList is only defined when -Latest or -Checksum is defined and it is reference variable.
            DynamicParam { If ($Latest -or $PSBoundParameters.ContainsKey('Checksum')) { [DynamicParameter]::Create('FullList', [ref]) } }
            Begin {
                # Initialize the variable that will contain the latest installer or the installer with a specified hashcode.
                $Output = $Null
                $IsChecksumParameterSet = $PSCmdlet.ParameterSetName -eq 'Checksum'
                # $Algorithm is the hash algorithm name generated from the specified checksum length
                If ($IsChecksumParameterSet) { $Algorithm = [HashAlgorithm] $Checksum.Length }
                # Initialize the full list reference value to an empty array.
                If ($PSBoundParameters.ContainsKey('FullList')) { $PSBoundParameters.FullList.Value = @() }
            }
            Process {
                If (!($IsChecksumParameterSet -and $Output)) {
                    ($Item | & $Script:SelectInstallerItem -Description $Script:Description | & $Script:SelectInstallerInfo -Type $Type).
                    ForEach{
                        # Add indexed installer full path to the reference variable specified by FullList parameter.
                        If ($PSBoundParameters.ContainsKey('FullList') -and ("$_" -inotin $PSBoundParameters.FullList.Value)) { $PSBoundParameters.FullList.Value += "$_" }
                        # Compare current installer item with the previous latest by Version if -Latest is specified.
                        If ($Latest) { $Output = ($Output && $_) | Sort-Object Version -Descending -Top 1 }
                        # Compare current installer hashcode with the hashcode specified by -FullList.
                        # Else return the indexed installer object.
                        ElseIf ($IsChecksumParameterSet) { If ($Checksum -ieq (Get-FileHash "$_" $Algorithm).Hash) { $Output = $_ } } Else { $_ }
                    }
                }
            }
            # Return the latest installer from the pool of saved intallers or the installer with a specified hashcode.
            End { $Output }
            <#
            .SYNOPSIS
                Selects installers indexed by description.
            .DESCRIPTION
                The command filters installer file system items with a specified file info property value.
                The later is referred to as the installer description.
                To get only the latest version of the items, use the switch parameter -Latest.
                To get the items that matches a specified checksum code, use the parameter -Checksum with the checksum specified.
                The parameters -Latest and -Checksum are mutually exclusive.
            .PARAMETER Item
                Specifies the file system info object.
            .PARAMETER Type
                Specifies the type of the object that is referred to as the version of the installer.
                The different versioning types are:
                Version of type [version],
                DateTime of type [datetime] that is the last modified date of the installer,
                SigningTime of type [datetime] that is the signing time of the installer.
            .PARAMETER Latest
                Specifies that only the latest version of the selected items.
            .PARAMETER Checksum
                Specifies that only the item with the specified checksum to be selected.
            .PARAMETER FullList
                Specifies the reference that saves the list of full paths of installers with the specified file info property value.
                It is a dynamic parameter that is available only when Latest or Checksum is defined.
            .EXAMPLE
                ${Function:Select-InstallerInfo} = [Selector]::Create(@{ Value = 'Google Chrome' })
                PS > Get-Item 'C:\Software\' | Select-InstallerInfo -Latest
                Path                           Version
                ----                           -------
                C:\Software\105.0.5195.54.exe  105.0.5195.54
            .EXAMPLE
                Get-Item 'C:\Software\' | Select-InstallerInfo -Checksum '591987CD7FB585AC01EB9A4EBDC69C4044E99976'
                Path                           Version
                ----                           -------
                C:\Software\104.0.5112.81.exe  104.0.5112.81
            .EXAMPLE
                Get-Item 'C:\Software\' | Select-InstallerInfo -Type DateTime
                Path                            Version
                ----                            -------
                C:\Software\103.0.5060.114.exe  7/2/2022 4:41:01 AM
                C:\Software\103.0.5060.134.exe  7/18/2022 10:16:56 PM
                C:\Software\104.0.5112.102.exe  8/16/2022 1:28:04 AM
                C:\Software\104.0.5112.81.exe   7/30/2022 7:37:12 PM
                C:\Software\105.0.5195.54.exe   8/24/2022 4:29:17 AM
            #>
        }.GetNewClosure()
    }

    Static [scriptblock] Create([string] $FileDescriptionValue) { Return [Selector]::Create(@{ Value = $FileDescriptionValue }) }

    Static Hidden [string] get_description([System.IO.FileInfo] $InstallerItem, [string] $PropertyName) {
        # Get the most descritive text of the application from the installer file properties.
        # $InstallerItem is the installer item that must exist on the file system.
        # $PropertyName is the version info property to retrieve from the installer file that
        # describes the most the application that is being installed.

        Return ($InstallerItem ?? $(Throw '$InstallerItem must not be null')).ForEach{
            # Return the version info property value when it is not empty nor null.
            # Otherwise return the signature subject if it is not null.
            # Otherwise return the file name of the installer item.
            ($_.VersionInfo.$($PropertyName.ForEach{ $_ ? ${_}:'FileDescription' }) | ForEach-Object { $_ ? ${_}:$Null }) ??
            (Get-AuthenticodeSignature "$_").SignerCertificate.Subject ?? $_.BaseName
        }
    }

    Static Hidden [scriptblock] get_filter() {
        # Get the scriptblock that runs the steppable pipeline that filters saved installer file
        # system items by their most descriptive property value returned by get_description().

        Return {
            [CmdletBinding()]
            [OutputType([System.IO.FileInfo])]
            Param(
                [Parameter(Mandatory, ValueFromPipeline)]
                [ValidateNotNullOrEmpty()]
                [ValidateScript({ [System.IO.File]::Exists($_) })]
                [System.IO.FileInfo] $Item,
                [Parameter(Mandatory)]
                [ValidateScript({ $_.Value })]
                [hashtable] $Description
            )
            Process {
                {
                    Where-Object {
                        $Item.ForEach{
                            # The filtered item is a file system with allowed extensions file and must not be a symbolic link.
                            $_.LinkType -ine 'SymbolicLink' -and [ValidationScript]::Extension($_.Extension) -and
                            [Selector]::get_description($_, $Description.PropertyName) -like "$($Description.Value)*"
                        }
                    }
                }.GetSteppablePipeline().ForEach{ $_.Begin($true); $_.Process($Item); $_.End(); $_.Dispose() }
            }
            <#
            .SYNOPSIS
                Selects installer file system items.
            .DESCRIPTION
                The command filters installer file system items with a specified file info property value.
            .PARAMETER Item
                Specifies the file system info object.
            .PARAMETER Description
                Specifies a hashtable with 2 keys:
                PropertyName is the name of the file info property used to index the input files.
                Value is the non-empty or non-null value of the indexed property name.
            .EXAMPLE
                Get-ChildItem 'C:\Software\' | Select-Object Name
                Name
                ----
                105.0.5195.54.exe
                19.0.60.43.exe
                tabby_v1.0.183.exe

                PS > ${Function:Select-InstallerItem} = [Selector]::get_filter()
                PS > $Description = @{ PropertyName = 'ProductName'; Value = 'Tabby' }
                PS > Get-ChildItem 'C:\Software\' | Select-InstallerItem -Description $Description | Select-Object Name
                Name
                ----
                tabby_v1.0.183.exe
            #>
        }
    }

    Static Hidden [scriptblock] get_selector() {
        # Get the scriptblock that selects the installer property that can be identified as its version.

        Return {
            [CmdletBinding()]
            [OutputType([Installer])]
            Param(
                [Parameter(Mandatory, ValueFromPipeline)]
                [ValidateNotNullOrEmpty()]
                [ValidateScript({ [System.IO.File]::Exists($_) })]
                [System.IO.FileInfo] $Item,
                [VersionType] $Type = 'Version'
            )
            Begin {
                ${Function:Invoke-SwitchCase} =
                Switch ($Type) {
                    # Get the scriptblock that returns the file version of the installer if defined.
                    'Version'  { { $Item.VersionInfo.FileVersionRaw } }
                    # Get the scriptblock that returns the last modified date of the installer if reliable.
                    'DateTime' { { $Item.LastWriteTime } }
                    # Get the scriptblock that returns the signing time date of the installer if defined.
                    'SigningTime' {
                        $SignTimeModulePath = "$PSScriptRoot\SigningTimeGetter.psm1"
                        If (![System.IO.File]::Exists($SignTimeModulePath)) {
                            "$(Invoke-WebRequest 'https://gist.githubusercontent.com/sangafabrice/9f866c5035c8d74201b8a76406d2100e/raw/35d9aea933b0e0a27cc74625fa612f56e7a81ca5/SigningTimeGetter.psm1')" |
                            Out-File $SignTimeModulePath
                        }
                        $SignTimeModule = Import-Module $SignTimeModulePath -PassThru
                        { Get-AuthenticodeSigningTime "$Item" }
                    }
                }
            }
            # Run the scriptblock assigned to Invoke-SwitchCase and return the installer object.
            Process { (Invoke-SwitchCase).ForEach{ [Installer]::New("$Item", $_) } }
            End { If ($Type -eq 'SigningTime') { Try { Remove-Module $SignTimeModule } Catch { } } }
            <#
            .SYNOPSIS
                Selects installer version
            .DESCRIPTION
                The command gets the installer file system property that can be referred to as its version.
            .PARAMETER Item
                Specifies the file system info object.
            .PARAMETER Type
                Specifies the type of the object that is referred to as the version of the installer.
                The different versioning types are:
                Version of type [version],
                DateTime of type [datetime] that is the last modified date of the installer,
                SigningTime of type [datetime] that is the signing time of the installer.
            .EXAMPLE
                ${Function:Select-InstallerInfo} = [Selector]::get_selector()
                PS > Get-Item 'C:\Software\tabby_v1.0.183.exe' | Select-InstallerInfo -Type Version
                Path                            Version
                ----                            -------
                C:\Software\tabby_v1.0.183.exe  1.0.183.0
            .EXAMPLE
                Get-Item 'C:\Software\tabby_v1.0.183.exe' | Select-InstallerInfo -Type DateTime
                Path                            Version
                ----                            -------
                C:\Software\tabby_v1.0.183.exe  8/1/2022 11:42:20 AM
            .EXAMPLE
                Get-Item 'C:\Software\tabby_v1.0.183.exe' | Select-InstallerInfo -Type SigningTime
                Path                            Version
                ----                            -------
                C:\Software\tabby_v1.0.183.exe  8/1/2022 9:42:11 AM
            #>
        }
    }
}
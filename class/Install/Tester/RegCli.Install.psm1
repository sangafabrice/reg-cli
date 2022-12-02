#Requires -Version 7.0
#Requires -RunAsAdministrator

Class Tester {
    # Tester is not meant to be instantiated and only declares static methods.
    # It is a set of help methods to handle a specified software install executable.

    Static [scriptblock] Create([System.IO.FileInfo] $ExecutablePath, [scriptblock] $OneParameterBlock) {
        # Get the scriptblock that tests whether the app is updated after installation.
        # $VERSION_PREINSTALL is the version of the application before installation or updating.
        # $ExecutablePath is the path to the executable that opens the software to update.
        # The path does not necessary exist.
        # $OneParameterBlock is scriptblock that accepts one parameter that is the executable path
        # and returns the version of the software or returns $null when the path does not exist.
        $VERSION_PREINSTALL = [Tester]::convertfrom_version((& $OneParameterBlock "$ExecutablePath"))
        Return {
            [CmdletBinding()]
            [OutputType([bool])]
            Param ()
            Return [Tester]::convertfrom_version((& ($Script:OneParameterBlock) "$Script:ExecutablePath")) -gt $Script:VERSION_PREINSTALL
            <#
            .SYNOPSIS
                Tests if software is sucessfully updated.
            .DESCRIPTION
                The command tests if a software executable is updated since the last test.
            .EXAMPLE
                $yq_exe = "${Env:LOCALAPPDATA}\Microsoft\WindowsApps\yq.exe"
                PS > $scriptblock = { Try { ((. $args[0] --version) -split ' ')[-1] } Catch { } }
                PS > & $scriptblock $yq_exe
                PS > ${Function:Test-InstallUpdate} = [Tester]::Create($yq_exe, $scriptblock)
                PS > Test-InstallUpdate
                False
                PS > # Update yq
                PS > & $scriptblock $yq_exe
                4.26.1
                PS > Test-InstallUpdate
                True
                PS > Test-InstallUpdate
                False
                PS > # Update yq
                PS > & $scriptblock $yq_exe
                4.29.1
                PS > Test-InstallUpdate
                True
                PS > Test-InstallUpdate
                False
            #>
        }.GetNewClosure()
    }

    Static Hidden [version] convertfrom_version([psobject] $VersionString) {
        # Convert a version string to a version object which properties are not less than 0
        Return $($VersionString.Where({ $_ }).ForEach({
            $_ -is [string] ? $(
                Try {
                    [version] ((& {
                        Param ($VersionString)
                        Switch ($VersionString -replace '\.\.','.') { { $_ -eq $VersionString } { Return $_ } Default { & $MyInvocation.MyCommand.ScriptBlock $_ } }
                    } ($_ -replace '[^0-9\.]','.')) -replace '^\.' -replace '\.$')
                } Catch { }
            ):$_
        }).ForEach{ [version] (($_.Major,$_.Minor,$_.Build,$_.Revision | ForEach-Object { Switch ($_) { { $_ -lt 0 } { 0 } Default { $_ } } }) -join '.') })
    }
}
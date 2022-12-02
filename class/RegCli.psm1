#Requires -Version 7.0
#Requires -RunAsAdministrator
using module '.\Extended.IO.psm1'
using module '.\Extended.PS.psm1'
using module '.\Install\Tester\RegCli.Install.psm1'
using module '.\Install\Utility\RegCli.Install.psm1'
using module '.\Installer\RegCli.psm1'
using module '.\Installer\Selector\RegCli.Installer.psm1'
using module '.\Installer\Downloader\RegCli.Installer.psm1'
using module '.\Installer\Expander\RegCli.Installer.psm1'

Class Updater {
    # Performs operations that consist of identifying an installer,
    # downloading it and installing the embedded software.

    Static [System.Management.Automation.PSModuleInfo] Create(
        [System.IO.FileInfo] $ExecutablePath,
        [string] $SoftwareName,
        [scriptblock] $GetSoftwareVersion,
        [psobject] $SoftwareLatestVersion,
        [string] $SoftwareChecksum,
        [System.IO.DirectoryInfo] $InstallerDirectory,
        [psobject] $InstallerDescription,
        [VersionType] $InstallerCompareBy,
        [InstallerType] $InstallerType,
        [string] $InstallerExtension
    ) {
        # Get the dynamic module that defines a set of operations to perform a software installation.

        Return New-Module {
            Param (
                [System.IO.FileInfo] $ExecutablePath,
                [string] $SoftwareName,
                [scriptblock] $GetSoftwareVersion,
                [psobject] $SoftwareLatestVersion,
                [string] $SoftwareChecksum,
                [System.IO.DirectoryInfo] $InstallerDirectory,
                [psobject] $InstallerDescription,
                [VersionType] $InstallerCompareBy,
                [InstallerType] $InstallerType,
                [string] $InstallerExtension
            )
            # Pseudo-exported function to select installers identified by a description.
            ${Function:Global:Select-InstallerInfo} = [RegCli.Installer.Selector]::Create($InstallerDescription)
            # Function to test if the software is updated since function creation or the last test.
            ${Function:Test-InstallUpdate} = [RegCli.Install.Tester]::Create($ExecutablePath, $GetSoftwareVersion)
            # Function to set the software shortcut.
            ${Function:Set-ExecutableShortcut} = [RegCli.Install.Utility]::SetExeShortcut($ExecutablePath)
            # Function to set the symlink to a console application.
            ${Function:Set-ConsoleAppSymlink} = [RegCli.Install.Utility]::SetConsoleAppSymlink($ExecutablePath)
            # Function to set the visual element manifest of a chromium based application.
            ${Function:Set-VisualElementsManifest} = [RegCli.Install.Utility]::SetChromiumVisualElementsManifest($ExecutablePath)
            # Initialize the list of installers of the software being installed.
            $InstallerPathList = $Null
            # Get the path to the latest version of an installer of the software to install.
            $InstallerPath = [Updater]::set_installer_path($SoftwareName, $SoftwareLatestVersion, $SoftwareChecksum, $InstallerDirectory, $InstallerCompareBy, $InstallerExtension, [ref] $InstallerPathList)
            # Function to download installer and move it to installer path.
            ${Function:Start-InstallerDownload} = [RegCli.Installer.Downloader]::Create("$InstallerPath")
            # Function to expand installer to installation directory.
            ${Function:Expand-Installer} = [RegCli.Installer.Expander]::Create("$InstallerPath", $ExecutablePath, $GetSoftwareVersion, $InstallerType)
            # Set the installer path as the default target value for Set-ConsoleAppSymlink.
            $Global:PSDefaultParameterValues.'Set-ConsoleAppSymlink:Target' = "$InstallerPath"
            & {
                $ModuleInfo = $MyInvocation.MyCommand.ScriptBlock.Module
                # Save the module name in the read-only  variable $REG_CLI_MODULE.
                Set-Variable 'REG_CLI_MODULE' $ModuleInfo.Name -Option ReadOnly -Scope Script -Force
                # Operation performed when the dynamic module is removed.
                $ModuleInfo.OnRemove = {
                    Remove-Item -Path 'Function:\Select-InstallerInfo' -Force
                    # Remove the installer path as the default target value for Set-ConsoleAppSymlink.
                    $Global:PSDefaultParameterValues.Remove('Set-ConsoleAppSymlink:Target')
					# Remove the outdated backup copy of the install directory.
                    If ($Script:REG_CLI_REMOVE_OUTDATED_BACKUP) {
						Remove-Item -Path $Global:REG_CLI_OUTDATED_BACKUP -ErrorAction SilentlyContinue -Force
						If (![System.IO.File]::Exists($Global:REG_CLI_OUTDATED_BACKUP)) { Remove-Variable 'REG_CLI_OUTDATED_BACKUP' -Scope Global -ErrorAction SilentlyContinue -Force }
					}
                    # Remove the outdated installers if the installer exists.
                    If ($Script:REG_CLI_REMOVE_OUTDATED_INSTALLER) { Try { Remove-Item $Script:InstallerPathList -Exclude (Get-Item "$Script:InstallerPath").Name -Force -ErrorAction SilentlyContinue } Catch { } }
                }
            }
            $REG_CLI_REMOVE_OUTDATED_INSTALLER = $False
            $REG_CLI_REMOVE_OUTDATED_BACKUP = $False
            Export-ModuleMember -Function '*' -Variable 'REG_CLI_*'
        } -ArgumentList $ExecutablePath,$SoftwareName,$GetSoftwareVersion,$SoftwareLatestVersion,$SoftwareChecksum,$InstallerDirectory,$InstallerDescription,$InstallerCompareBy,$InstallerType,$InstallerExtension
    }

    Static Hidden [string] set_installer_prefix([string] $SoftwareName) {
        # Return the prefix of the installer file system base name.

        Return "$(${SoftwareName}?.ToLower().Trim() -replace ' ','_')$(If(!!$SoftwareName){'_'})"
    }

    Static Hidden [string] set_installer_suffix([psobject] $SoftwareLatestVersion) {
        # Return the version string of that serves as the suffix of the installer file system base name.

        Return $SoftwareLatestVersion.ForEach{ $_ -is [datetime] ? ('{0}.{1}.{2}' -f $_.Year,$_.DayOfYear,$_.TimeOfDay.TotalMinutes.ToString('#.##')):$_ }
    }

    Static Hidden [RegCli.Installer] set_installer_path(
        [string] $SoftwareName,
        [psobject] $SoftwareLatestVersion,
        [string] $SoftwareChecksum,
        [System.IO.DirectoryInfo] $InstallerDirectory,
        [VersionType] $InstallerCompareBy,
        [string] $InstallerExtension,
        [ref] $InstallerPathList
    ) {
        # Return the installer path and optionally the list of the paths of the installers of the same software as a reference.

        # Reinitialize the list of the paths of the installers.
        $InstallerPathList.Value = @()
        # The arguments of Select-InstallerInfo. 
        $__args__ = @{ Type = $InstallerCompareBy; FullList = $InstallerPathList; ErrorAction = 'SilentlyContinue' } + ($SoftwareChecksum ? @{ Checksum = $SoftwareChecksum }:@{ Latest = $True })
        $InstallerPath = Get-ChildItem $InstallerDirectory | Select-InstallerInfo @__args__
        If (!("$InstallerPath" -or "$SoftwareLatestVersion")) { Throw 'No installer was found.' }
        # If the path is an empty string or the latest installer locally is not the software latest version
        # add the constructed path with prefix and suffix to the list of paths.
        If ((!"$InstallerPath" -or $__args__.Latest) -and $InstallerPath.Version -lt $SoftwareLatestVersion) {
            $InstallerPath = [RegCli.Installer]::New([Extended.IO.Path]::GetFullPath("$InstallerDirectory\$([Updater]::set_installer_prefix($SoftwareName))$([Updater]::set_installer_suffix($SoftwareLatestVersion))$InstallerExtension"), $SoftwareLatestVersion)
            $InstallerPathList.Value += "$InstallerPath"
        }
        Return $InstallerPath
    }
}
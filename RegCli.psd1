@{
RootModule = 'RegCli.psm1'
ModuleVersion = '6.1.0'
GUID = '9d980765-e8a9-4dd6-b7b0-9142a7a6e704'
Author = 'Fabrice Sanga'
CompanyName = 'sangafabrice'
Copyright = '© 2022 SangaFabrice. All rights reserved.'
Description = 'Set of helper functions for updating applications.'
PowerShellVersion = '7.0'
PowerShellHostVersion = '7.0'
FunctionsToExport = 'Expand-Installer','Expand-ChromiumInstaller', 
               'Expand-SquirrelInstaller','Expand-NsisInstaller', 
               'Get-ExecutableType','Save-Installer','Set-BatchRedirect', 
               'Set-ChromiumShortcut','Edit-TaskbarShortcut', 
               'Set-ChromiumVisualElementsManifest','New-RegCliUpdate', 
               'Test-InstallLocation','Test-InstallerLocation', 
               'Get-SavedInstallerVersion','Get-SavedInstallerLastModified', 
               'Get-SavedInstallerSigningTime','Select-NonEmptyObject', 
               'Import-CommonScript'
CmdletsToExport = @()
AliasesToExport = 'Set-SquirrelShortcut','Set-NsisShortcut'
FileList = 'en-US\RegCli-help.xml','RegCli.psm1','RegCli.psd1', 
               'class\RegCli.psm1','class\ValidationUtility.psm1', 
               'class\SigningTimeGetter.psm1'
PrivateData = @{
    PSData = @{
        Tags = 'Update','Chromium','RegCli'
        LicenseUri = 'https://github.com/sangafabrice/reg-cli/blob/main/LICENSE.md'
        ProjectUri = 'https://github.com/sangafabrice/reg-cli'
        IconUri = 'https://rawcdn.githack.com/sangafabrice/reg-cli/5dd6cdfa8202fbd95eaa6fbf219f906a3b83d130/icon.png'
        ReleaseNotes = 'Include the script to download 7zip in RegCli as a hidden method.
Change the Signing Time module name.
Change search zone of Installer Description automatically.
Remove UseSignature.
Use msi table to retrieve version and product name.
Remove code repetition. The code to filter file system items.
Change the version of common files.'
    }
}
}

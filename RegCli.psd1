@{
RootModule = 'RegCli.psm1'
ModuleVersion = '4.0.0'
GUID = '9d980765-e8a9-4dd6-b7b0-9142a7a6e704'
Author = 'Fabrice Sanga'
CompanyName = 'sangafabrice'
Copyright = '© 2022 SangaFabrice. All rights reserved.'
Description = 'Set of helper functions for updating applications.'
PowerShellVersion = '7.0'
PowerShellHostVersion = '7.0'
FunctionsToExport = 'Expand-Installer','Expand-ChromiumInstaller', 
               'Expand-SquirrelInstaller','Get-ExecutableType','Save-Installer', 
               'Set-BatchRedirect','Set-ChromiumShortcut','Edit-TaskbarShortcut', 
               'Set-ChromiumVisualElementsManifest','New-RegCliUpdate', 
               'Test-InstallLocation','Test-InstallerLocation', 
               'Get-SavedInstallerVersion','Get-SavedInstallerPublishDate', 
               'Select-NonEmptyObject','Get-AuthenticodeSignatureEx'
CmdletsToExport = @()
AliasesToExport = 'Set-SquirrelShortcut'
FileList = 'en-US\RegCli-help.xml','RegCli.psm1','RegCli.psd1'
PrivateData = @{
    PSData = @{
        Tags = 'Update','Chromium','RegCli'
        LicenseUri = 'https://github.com/sangafabrice/reg-cli/blob/main/LICENSE.md'
        ProjectUri = 'https://github.com/sangafabrice/reg-cli'
        IconUri = 'https://rawcdn.githack.com/sangafabrice/reg-cli/5dd6cdfa8202fbd95eaa6fbf219f906a3b83d130/icon.png'
        ReleaseNotes = 'Add function to install embedded nuget packages.
Remove 7zip intallation at the end of Module and do it at installer expansion time.
Add shortcuts creation of application installed using nuget packages.
Add 7za for expanding nuget packages.
Add ability to change extension of inner archive to expand.'
    }
}
}

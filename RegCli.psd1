@{
RootModule = 'RegCli.psm1'
ModuleVersion = '3.0.0'
GUID = '9d980765-e8a9-4dd6-b7b0-9142a7a6e704'
Author = 'Fabrice Sanga'
CompanyName = 'sangafabrice'
Copyright = '© 2022 SangaFabrice. All rights reserved.'
Description = 'Set of helper functions for updating applications.'
PowerShellVersion = '7.0'
PowerShellHostVersion = '7.0'
FunctionsToExport = 'Expand-Installer','Expand-ChromiumInstaller','Get-ExecutableType', 
               'Save-Installer','Set-BatchRedirect','Set-ChromiumShortcut', 
               'Edit-TaskbarShortcut','Set-ChromiumVisualElementsManifest', 
               'New-RegCliUpdate','Test-InstallLocation','Test-InstallerLocation', 
               'Get-SavedInstallerVersion','Get-SavedInstallerPublishDate', 
               'Select-NonEmptyObject','Get-AuthenticodeSignatureEx'
CmdletsToExport = @()
AliasesToExport = @()
FileList = 'en-US\RegCli-help.xml','RegCli.psm1','RegCli.psd1'
PrivateData = @{
    PSData = @{
        Tags = 'Update','Chromium','RegCli'
        LicenseUri = 'https://github.com/sangafabrice/reg-cli/blob/main/LICENSE.md'
        ProjectUri = 'https://github.com/sangafabrice/reg-cli'
        IconUri = 'https://rawcdn.githack.com/sangafabrice/reg-cli/5dd6cdfa8202fbd95eaa6fbf219f906a3b83d130/icon.png'
        ReleaseNotes = 'Extend function capabilities: Expand-ChromiumInstaller includes version comparison of current install and installing update.
Add Get-AuthenticodeSignatureEx that extends Get-AuthenticodeSignature by adding SigningTime property.
Add functions for validation script in Updater script
Add non-null object selection function
Add a function to get the latest saved installer version'
    }
}
}

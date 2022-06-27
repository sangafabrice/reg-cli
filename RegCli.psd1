@{
RootModule = 'RegCli.psm1'
ModuleVersion = '1.0.1'
GUID = '9d980765-e8a9-4dd6-b7b0-9142a7a6e704'
Author = 'Fabrice Sanga'
CompanyName = 'sangafabrice'
Copyright = '© 2022 SangaFabrice. All rights reserved.'
Description = 'Set of helper functions for updating applications.'
PowerShellVersion = '7.0'
PowerShellHostVersion = '7.0'
FunctionsToExport = 'Expand-ChromiumInstaller','Get-ExecutableType','Save-Installer', 
               'Set-BatchRedirect','Set-ChromiumShortcut', 
               'Set-ChromiumVisualElementsManifest'
CmdletsToExport = @()
AliasesToExport = @()
FileList = 'en-US\RegCli-help.xml','RegCli.psm1','RegCli.psd1'
PrivateData = @{
    PSData = @{
        Tags = 'Update','Chromium','RegCli'
        LicenseUri = 'https://github.com/sangafabrice/reg-cli/blob/main/LICENSE.md'
        ProjectUri = 'https://github.com/sangafabrice/reg-cli'
        IconUri = 'https://rawcdn.githack.com/sangafabrice/reg-cli/5dd6cdfa8202fbd95eaa6fbf219f906a3b83d130/icon.png'
        ReleaseNotes = 'Document the functions with the comment-help.'
    }
}
}

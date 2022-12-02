@{
RootModule = 'RegCli.psm1'
ModuleVersion = '7.0.0'
GUID = '9d980765-e8a9-4dd6-b7b0-9142a7a6e704'
Author = 'Fabrice Sanga'
CompanyName = 'sangafabrice'
Copyright = '© 2022 SangaFabrice. All rights reserved.'
Description = 'Set of helper functions for updating applications.'
PowerShellVersion = '7.0'
PowerShellHostVersion = '7.0'
FunctionsToExport = 'Get-ExecutableType','New-RCUpdate','Test-InstallerLocation', 
               'Test-InstallLocation','Test-InstallProcess','Start-RCUpdate'
CmdletsToExport = @()
AliasesToExport = @()
FileList = 'class\Install\Tester\RegCli.Install.psm1', 
               'class\Install\Utility\RegCli.Install.psm1', 
               'class\Installer\Downloader\RegCli.Installer.psm1', 
               'class\Installer\Expander\RegCli.Installer.psm1', 
               'class\Installer\Selector\RegCli.Installer.psm1', 
               'class\Installer\Selector\SigningTimeGetter.psm1', 
               'class\Installer\RegCli.psm1','class\Extended.IO.psm1', 
               'class\Extended.PS.psm1','class\RegCli.psm1','RegCli.psd1', 
               'RegCli.psm1'
PrivateData = @{
    PSData = @{
        Tags = 'Update','Chromium','NSIS','InnoSetup','Squirrel','RegCli'
        LicenseUri = 'https://github.com/sangafabrice/reg-cli/blob/main/LICENSE.md'
        ProjectUri = 'https://github.com/sangafabrice/reg-cli'
        IconUri = 'https://rawcdn.githack.com/sangafabrice/reg-cli/5dd6cdfa8202fbd95eaa6fbf219f906a3b83d130/icon.png'
        ReleaseNotes = '· Major refactoring of the code base.
· Organize the code base into pseudo-namespaces built upon the file system and module import.
· Add option to keep outdated installers.
· Add option to remove outdated install directory content from the disk.
· Minify the code base to reduce the load of the module.
· Add innosetup extractor for handling this type of installer.
· Convert common script to a function: Start-RCUpdate.
· Convert Help document to comment-based help douments.
· Move SigningTimeGetter module and 7zip and InnoExtract download code to GitHub.
→ Follow me and like this project on GitHub.com.'
    }
}
}

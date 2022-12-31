@{
RootModule = 'RegCli.psm1'
ModuleVersion = '7.0.0'
GUID = '9d980765-e8a9-4dd6-b7b0-9142a7a6e704'
Author = 'Fabrice Sanga'
CompanyName = 'sangafabrice'
Copyright = '© 2022 SangaFabrice. All rights reserved.'
Description = 'This module performs operations of identifying the latest version of an installer, downloading it, and installing the embedded software. The installation of the software consists of expanding a self-extracting executable. This way allows more control of the software that is thus used as a portable application. The published module is a minified version of the code base to reduce its load time. The full code base is available on GitHub.com.
→ To support this project, please visit and like: https://github.com/sangafabrice/reg-cli'
PowerShellVersion = '7.0'
PowerShellHostVersion = '7.0'
FunctionsToExport = 'Get-ExecutableType','New-RCUpdate','Test-InstallerLocation','Test-InstallLocation','Test-InstallProcess','Start-RCUpdate'
CmdletsToExport = @()
AliasesToExport = @()
FileList = 'RegCli.psd1','RegCli.psm1','lib\RegCli\RegCli.psd1','lib\RegCli\Updater.psm1','lib\RegCli\Installer\RegCli\Installer.psm1','lib\RegCli\Installer\RegCli\RegCli.psd1','lib\RegCli\Installer\RegCli.Installer\RegCli.Installer.psd1','lib\RegCli\Installer\RegCli.Installer\Root.psm1','lib\RegCli\PowerShell.DynamicParameter\DynamicParameter.psm1','lib\RegCli\PowerShell.DynamicParameter\PowerShell.DynamicParameter.psd1','lib\RegCli\PowerShell.Installer.AllowedList\AllowedList.psm1','lib\RegCli\PowerShell.Installer.AllowedList\PowerShell.Installer.AllowedList.psd1','lib\RegCli\PowerShell.ValidationScript\PowerShell.ValidationScript.psd1','lib\RegCli\PowerShell.ValidationScript\ValidationScript.psm1','lib\RegCli\RegCli.Install\RegCli.Install.psd1','lib\RegCli\RegCli.Install\Root.psm1','lib\RegCli\System.Extended.IO\Path.psm1','lib\RegCli\System.Extended.IO\System.Extended.IO.psd1'
PrivateData = @{
PSData = @{
Tags = 'updater','installer','setup','chromium','nsis','innosetup','squirrel','downloadinfo'
LicenseUri = 'https://github.com/sangafabrice/reg-cli/blob/main/LICENSE.md'
ProjectUri = 'https://github.com/sangafabrice/reg-cli'
IconUri = 'https://rawcdn.githack.com/sangafabrice/reg-cli/f5c95295edb894ff09e41f5b8923ea8ac1d4133a/icon.svg'
ReleaseNotes = '· Major refactoring of the code base.
· Organize the code base into pseudo-namespaces built upon the file system and module import.
· Add option to keep outdated installers using the boolean variable.
· Add option to remove outdated install directory content from the disk.
· Minify the code base to reduce the load of the module.
· Add innosetup extractor for handling this type of installer.
· Convert common script to a function: Start-RCUpdate.
· Protect the module by testing whether the installation location does not modify the module.
· Add option to remove a list of file define in REG_CLI_FILES.
· Convert Help document to comment-based help documents.
· Move SigningTimeGetter module and 7zip and InnoExtract download code to GitHub.
· Remove msi installer handling.'
}
}
}

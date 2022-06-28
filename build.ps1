$DevDependencies = @{
    PlatyPS    = '0.14.2'
    RemoteRepo = (git ls-remote --get-url) -replace '\.git$'
    Manifest   = { Invoke-Expression "$(Get-Content "$PSScriptRoot\RegCli.psd1" -Raw)" }
}

Filter New-RCManifest {
    <#
    .SYNOPSIS
        Create module manifest
    .NOTES
        Precondition:
        1. latest.json exists
    #>

    $GithubRepo = $DevDependencies.RemoteRepo
    $ModuleName = 'RegCli'
    Push-Location $PSScriptRoot
    Get-Content .\latest.json -Raw |
    ConvertFrom-Json |
    ForEach-Object {
        @{
            Path = "$ModuleName.psd1"
            RootModule = "$ModuleName.psm1"
            ModuleVersion = $_.version
            GUID = '9d980765-e8a9-4dd6-b7b0-9142a7a6e704'
            Author = 'Fabrice Sanga'
            CompanyName = 'sangafabrice'
            Copyright = "© $((Get-Date).Year) SangaFabrice. All rights reserved."
            Description = 'Set of helper functions for updating applications.'
            PowerShellVersion = '7.0'
            PowerShellHostVersion = '7.0'
            FunctionsToExport = @(
                (Get-Content ".\$ModuleName.psm1").Where({ $_ -like 'Function*' -or $_ -like 'Filter*' }) |
                ForEach-Object { ($_ -split ' ')[1] }
            )
            CmdletsToExport = @()
            VariablesToExport = @()
            AliasesToExport = @()
            FileList = @("en-US\$ModuleName-help.xml","$ModuleName.psm1","$ModuleName.psd1")
            Tags = @('Update','Chromium','RegCli')
            LicenseUri = "$GithubRepo/blob/main/LICENSE.md"
            ProjectUri = $GithubRepo
            IconUri = 'https://rawcdn.githack.com/sangafabrice/reg-cli/5dd6cdfa8202fbd95eaa6fbf219f906a3b83d130/icon.png'
            ReleaseNotes = $_.releaseNotes -join "`n"
        }
    } | ForEach-Object {
        New-ModuleManifest @_
        (Get-Content $_.Path |
        Where-Object { $_ -match '.+' } |
        Where-Object { $_ -notmatch '^\s*#\.*' }) -replace ' # End of .+' -replace ", '",",'" |
        Out-File "$ModuleName.psd1"
    }
    Pop-Location
}
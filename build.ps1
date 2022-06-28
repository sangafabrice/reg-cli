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

Filter New-RCMerge {
    <#
    .SYNOPSIS
        Merge module into main
    .NOTES
        Precondition:
        1. The current branch is main
        2. Module files are modified in main
        3. The module manifest is modified
    #>

    Param($CommitMessage)

    Push-Location $PSScriptRoot
    Try {
        If ((git branch --show-current) -ne 'main') { Throw 'BranchNotMain' }
        New-RCManifest
        $Manifest = & $DevDependencies.Manifest
        $FileList = $Manifest.FileList
        $ManifestFile = $FileList | Where-Object {$_ -like '*.psd1'}
        Test-ModuleManifest $ManifestFile
        If ($Null -eq $CommitMessage) {
            $CommitMessage = Switch ($Manifest.PrivateData.PSData.ReleaseNotes) {
                { ($_ -split "`n").Count -eq 1 } { "$_" }
                Default { "RELEASE: v$($Manifest.ModuleVersion)" }
            }
        }
        $GitDiffFiles = @(git diff --name-only --cached) + @(git diff --name-only)
        If ($GitDiffFiles.Count -eq 0) { Throw }
        ,($GitDiffFiles | Select-Object -Unique) |
        ForEach-Object {
            If ($_.Count -eq $_.Where({$_ -in $FileList}, 'Until').Count) { Throw 'ModuleFilesNotModified' }
            If ($Null -eq ($_ | Where-Object { $_ -eq $ManifestFile })) { Throw 'ModuleManifestNotModified' }
        }
        Invoke-Expression "git add $($FileList) latest.json Readme.md"
        git commit --message "$CommitMessage" --quiet
        git stash push --include-untracked --quiet
        git switch module --quiet 2> $Null
        If (!$?) {
            git stash pop --quiet > $Null 2>&1 
            Throw
        }
        git merge --no-commit main > $Null 2>&1 
        $IsMergeError = !$?
        $CDPattern = "$($PWD -replace '\\','\\')\\"
        Get-ChildItem -Recurse -File |
        Where-Object { ($_.FullName -replace $CDPattern) -inotin $FileList } |
        Remove-Item
        Get-ChildItem -Directory |
        Where-Object { ($_.FullName -replace $CDPattern) -inotin @($FileList |
            Where-Object { $_ -like '*\*' } |
            ForEach-Object { ($_ -split '\\')[0] }) } |
        Remove-Item -Recurse -Force
        If ($IsMergeError) {
            ,@(git diff --name-only) |
            ForEach-Object { If ($_ -in $FileList) { Throw 'MergeConflict' } }
            git add .
        }
        git commit --message "$CommitMessage" --quiet
        git switch main --quiet 2> $Null
        git stash pop --quiet > $Null 2>&1
    }
    Catch { "ERROR: $($_.Exception.Message)" }
    Pop-Location
}

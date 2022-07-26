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
            AliasesToExport = @(
                (Get-Content ".\$ModuleName.psm1").Where({ $_ -like 'Set-Alias*' }) |
                ForEach-Object { ($_ -split ' ')[2] }
            )
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

Filter Invoke-OnModuleBranch {
    <#
    .SYNOPSIS
        Process a scriptblock on module branch
    .NOTES
        Precondition:
        1. The current branch does not have unstaged changes.
        2. The script block does not modify module
    #>

    Param([Parameter(Mandatory=$true)] $ScriptBlock)

    Get-Module RegCli -ListAvailable |
    ForEach-Object {
        Push-Location $PSScriptRoot
        git branch --show-current |
        ForEach-Object {
            Try {
                git switch module --quiet 2> $Null
                If (!$?) { Throw "StayOn_$_" }
                git switch $_ --quiet 2> $Null
                git stash push --include-untracked --quiet
                git switch module --quiet
                & $ScriptBlock
            }
            Catch { "ERROR: $($_.Exception.Message)" }
            Finally {
                git switch $_ --quiet 2> $Null
                git stash pop --quiet > $Null 2>&1
            }
        }
        Pop-Location
    }
}

## TODO: Function must implement -WhatIf
Filter Publish-RCModule {
    <#
    .SYNOPSIS
        Publish module to PSGallery
    .NOTES
        Precondition:
        1. The current branch is module
        2. The NUGET_API_KEY environment variable is set.
    #>

    Invoke-OnModuleBranch {
        If ((git branch --show-current) -ne 'module') { Throw 'BranchNotPwshModule' }
        If ($null -eq $Env:NUGET_API_KEY) { Throw 'NUGET_API_KEY_IsNull' }
        @{
            Name = 'RegCli';
            NuGetApiKey = $Env:NUGET_API_KEY;
        } | ForEach-Object { Publish-Module @_ }
        Write-Host "RegCli@v$((& $DevDependencies.Manifest).ModuleVersion) published"
    }
}

## TODO: Function must implement -WhatIf
Filter Push-RCModule {
    <#
    .SYNOPSIS
        Push new module commit to GitHub
    .NOTES
        Precondition:
        1. The current branch is module
    .OUTPUTS
        Push details
    #>

    Invoke-OnModuleBranch {
        If ((git branch --show-current) -ne 'module') { Throw 'BranchNotPwhModule' }
        git push origin module --force
        If (!$?) { Throw 'PushModuleToGitHubFailed' }
        "v$((& $DevDependencies.Manifest).ModuleVersion)" |
        ForEach-Object {
            If ($_ -inotin @(git tag --list)) {
                git tag $_
                git push --tags
            }
        }
    }
}

Filter Deploy-RCModule {
    <#
    .SYNOPSIS
        Deploy module Everywhere
    #>

    Try {
        { If ((git branch --show-current) -ne 'main') { Throw 'BranchNotMain' } } |
        ForEach-Object {
            & $_
            New-RCMerge
            & $_
        }
        Push-RCModule
        Publish-RCModule
    }
    Catch { "ERROR: $($_.Exception.Message)" }
}

Function Initialize-RCHelp {
    <#
    .SYNOPSIS
        Generate RegCli help document to a temporary location
    .NOTES
        Precondition: PlatyPS is installed
    #>

    Begin {
        $PlatyPsModule = Get-Module | Where-Object Name -eq 'PlatyPS'
        Import-Module PlatyPS -RequiredVersion $DevDependencies.PlatyPS -Force
    }
    Process {
        Push-Location $PSScriptRoot
        Import-Module RegCli -Force
        @{
            Module = 'RegCli'
            OutputFolder = '.\en_us_1'
            AlphabeticParamsOrder = $true
            WithModulePage = $true
            ExcludeDontShow = $true
            Encoding = [System.Text.Encoding]::UTF8
        } | ForEach-Object { New-MarkdownHelp @_ }
        Pop-Location
    }
    End {
        Remove-Module PlatyPS -Force
        If ($PlatyPsModule.Count -gt 0) {
            Import-Module PlatyPS -RequiredVersion $PlatyPsModule.Version -Force
        }
    }
}

Function Update-RCHelp {
    <#
    .SYNOPSIS
        Update RegCli help document
    .NOTES
        Precondition: PlatyPS is installed
    #>

    Begin {
        $PlatyPsModule = Get-Module | Where-Object Name -eq 'PlatyPS'
        Import-Module PlatyPS -RequiredVersion $DevDependencies.PlatyPS -Force
    }
    Process {
        Push-Location $PSScriptRoot
        New-ExternalHelp -Path .\en_us\ -OutputPath en-US -Force
        Pop-Location
    }
    End {
        Remove-Module PlatyPS -Force
        If ($PlatyPsModule.Count -gt 0) {
            Import-Module PlatyPS -RequiredVersion $PlatyPsModule.Version -Force
        }
    }
}

Filter Install-BuildDependencies {
    <#
    .SYNOPSIS
        Install build modules
    #>

    {
        Param(
            $Name,
            $PreInstall
        )
        
        If ((Get-Module $Name -ListAvailable |
        Where-Object Version -eq $DevDependencies[$Name]).Count -eq 0) {
            If ($Null -ne $PreInstall) { & $PreInstall }
            Install-Module $Name -RequiredVersion $DevDependencies[$Name] -Force
        }
    } | ForEach-Object { & $_ PlatyPS }
}

Filter New-RCJunction {
    <#
    .SYNOPSIS
        Create the RegCli Junction in PSModulePath
    #>

    Param([switch] $Force)

    $FirstPath = "$(($env:PSModulePath -split ';')[0])\RegCli"
    If (Test-Path $FirstPath) {
        If ($Force) {
            Remove-Item $FirstPath -Force
        } Else {
            Return 'RegCli junction already exists'
        }
    }
    @{
        Path = $FirstPath;
        ItemType = 'Junction';
        Value = $PSScriptRoot
    } | ForEach-Object { New-Item @_ }
}
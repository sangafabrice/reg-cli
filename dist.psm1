$DevDependencies = @{
    ProgramName = 'Vivaldi'
    Description = 'The script installs or updates Vivaldi browser on Windows.'
    Guid = 'f15674db-9841-4822-b368-50354c387101'
    IconUri = 'https://rawcdn.githack.com/sangafabrice/reg-cli/88e8345bfd93c03273280405759b79dae697a7f0/icon.png'
    Tags = @('vivaldi','chromium','update','browser')
    RemoteRepo = (git ls-remote --get-url) -replace '\.git$'
}

Function New-UpdaterScript {
    <#
    .SYNOPSIS
        Create module manifest
    .NOTES
        Precondition:
        1. latest.json exists
    #>

    $GithubRepo = $DevDependencies.RemoteRepo
    $HeaderPath = '.\Header.ps1'
    Push-Location $PSScriptRoot
    Get-Content .\latest.json -Raw |
    ConvertFrom-Json |
    ForEach-Object {
        @{
            Path = $HeaderPath
            Version = $_.version
            GUID = $DevDependencies.Guid
            Author = 'Fabrice Sanga'
            CompanyName = 'sangafabrice'
            Copyright = "© $((Get-Date).Year) SangaFabrice. All rights reserved."
            Description = $DevDependencies.Description
            RequiredModules = @{
                ModuleName = 'RegCli'
                ModuleVersion = '2.3.2'
            }
            ExternalModuleDependencies = 'RegCli'
            Tags = $DevDependencies.Tags
            LicenseUri = "$GithubRepo/blob/main/LICENSE.md"
            ProjectUri = "$GithubRepo/tree/$(git branch --show-current)"
            IconUri = $DevDependencies.IconUri
            ReleaseNotes = $_.releaseNotes
        }
    } | ForEach-Object { New-ScriptFileInfo @_ -Force }
    ((Get-Content $HeaderPath).Where({$_ -like "`<`# "}, 'Until') +
    (Get-Content .\Update.ps1)) -join "`n" | Out-String
    Remove-Item $HeaderPath
    Pop-Location
}

Function Publish-UpdaterScript {
    <#
    .SYNOPSIS
        Publish script to PSGallery
    .NOTES
        Precondition:
        1. The NUGET_API_KEY environment variable is set.
    #>

    @{
        Path = "$PSScriptRoot\Update$($DevDependencies.ProgramName).ps1" |
            ForEach-Object {
                New-UpdaterScript | Out-File $_
                Return $_
            }
        NuGetApiKey = $Env:NUGET_API_KEY
    } | ForEach-Object { 
        Try {
            Publish-Script @_
            Write-Host "$((Get-Item $_.Path).Name) published"
        } Catch { }
        Remove-Item $_.Path -Exclude Update.ps1
    }
}
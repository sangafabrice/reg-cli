$DevDependencies = @{
    ProgramName = 'Local'
    Description = 'The script installs or updates Local on Windows.'
    Guid = 'c68d19be-5946-4955-8a04-35f6944d7abb'
    IconUri = 'https://rawcdn.githack.com/sangafabrice/reg-cli/81991b3ae3db9d9ad5cecc31fe33fd33c2ff5ce7/icon.png'
    Tags = @('local','nuget-package','update','wordpress')
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
            RequiredModules = @(@{
                ModuleName = 'DownloadInfo'
                ModuleVersion = '4.0.0'
            },@{
                ModuleName = 'RegCli'
                ModuleVersion = '4.1.0'
            })
            ExternalModuleDependencies = @('DownloadInfo','RegCli')
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
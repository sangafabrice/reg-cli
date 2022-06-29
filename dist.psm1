$DevDependencies = @{
    ProgramName = 'GoogleChrome'
    Description = 'The script updates Google Chrome Legacy browser.'
    Guid = '456d8a16-2f21-409a-91a1-b2bcb22353e3'
    IconUri = 'https://rawcdn.githack.com/sangafabrice/choco-packages/4a3f99c43c1c2529ebb27f5a6b68b4c2efa5d4eb/icon.svg'
    Tags = @('google','chrome','chromium','omaha','update','browser')
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
            RequiredModules = @('DownloadInfo','RegCli')
            ExternalModuleDependencies = @('DownloadInfo','RegCli')
            Tags = $DevDependencies.Tags
            LicenseUri = "$GithubRepo/blob/main/LICENSE.md"
            ProjectUri = "$GithubRepo/tree/$(git branch --show-current)"
            IconUri = $DevDependencies.IconUri
            ReleaseNotes = $_.releaseNotes
        }
    } | ForEach-Object { New-ScriptFileInfo @_ -Force }
    ((Get-Content $HeaderPath).Where({$_ -like 'Param()*'}, 'Until') +
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
        Publish-Script @_
        Write-Host "$((Get-Item $_.Path).Name) published"
        Remove-Item $_.Path -Exclude Update.ps1
    }
}
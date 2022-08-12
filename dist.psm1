$DevDependencies = @{
    ProgramName = 'MSEdge'
    Description = 'The script installs or updates Microsoft Edge browser on Windows.'
    Guid = '711fbaea-637f-4424-99e6-0a3c06e62874'
    IconUri = 'https://rawcdn.githack.com/sangafabrice/reg-cli/363ae3d7fb7b37a4bd4f523465361d000b8fc831/icon.png'
    Tags = @('edge','microsoft','chromium','update','browser')
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
                ModuleVersion = '6.0.0'
            })
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
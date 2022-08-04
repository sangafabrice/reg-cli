$DevDependencies = @{
    ProgramName = 'Messenger'
    Description = 'The script installs or updates Messenger by Facebook on Windows.'
    Guid = '588b3e32-0451-4f1a-9284-9568601217e8'
    IconUri = 'https://rawcdn.githack.com/sangafabrice/reg-cli/780c550dfdb0540db5fd67daa322cc1dcbbc5457/icon.png'
    Tags = @('messenger','nuget-package','update','facebook')
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
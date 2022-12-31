$DevDependencies = @{
    Pester = '5.3.3'
    RemoteRepo = (git ls-remote --get-url) -replace '\.git$'
    Manifest   = { Invoke-Expression "$(Get-Content "$PSScriptRoot\RegCli.psd1" -Raw)" }
}


# The set of manifest files for validation set
Class ModuleFiles : System.Management.Automation.IValidateSetValuesGenerator { [string[]] GetValidValues() { Return @((& $Script:DevDependencies.Manifest).FileList) } }

# The set of module scripts in the lib directory or subdirectories for validation set
Class LibraryModules : System.Management.Automation.IValidateSetValuesGenerator { [string[]] GetValidValues() { Return ((& $Script:DevDependencies.Manifest).FileList -like 'lib\*.psm1') } }

#Region : RegCli module manifest management.
Filter New-RCManifest {
    <#
    .SYNOPSIS
        Set the module manifest.
    .NOTES
        The latest.json file must exist to provide the version and the release notes.
    #>
    [CmdletBinding()]
    Param()
    $GithubRepo = $DevDependencies.RemoteRepo
    $ModuleName = 'RegCli'
    $VerboseFlag = $VerbosePreference -ine 'SilentlyContinue'
    Push-Location $PSScriptRoot
    Try {
        # Read the latest version and the release notes from the latest.json file
        $LatestJson = Get-Content .\latest.json -Raw -ErrorAction Stop -Verbose:$VerboseFlag | ConvertFrom-Json
        @{
            # Arguments built for New-ModuleManifest
            Path = "$ModuleName.psd1"
            RootModule = "$ModuleName.psm1"
            ModuleVersion = $LatestJson.version
            GUID = '9d980765-e8a9-4dd6-b7b0-9142a7a6e704'
            Author = 'Fabrice Sanga'
            CompanyName = 'sangafabrice'
            Copyright = "© $((Get-Date).Year) SangaFabrice. All rights reserved."
            Description = @'
This module performs operations of identifying the latest version of an installer, downloading it, and installing the embedded software. The installation of the software consists of expanding a self-extracting executable. This way allows more control of the software that is thus used as a portable application. The published module is a minified version of the code base to reduce its load time. The full code base is available on GitHub.com.
→ To support this project, please visit and like: https://github.com/sangafabrice/reg-cli
'@
            PowerShellVersion = '7.0'
            PowerShellHostVersion = '7.0'
            FunctionsToExport = @((Get-Content ".\$ModuleName.psm1").Where{ $_ -like 'Function*' -or $_ -like 'Filter*' }.ForEach{ ($_ -split ' ')[1] })
            CmdletsToExport = @()
            VariablesToExport = @()
            AliasesToExport = @((Get-Content ".\$ModuleName.psm1").Where{ $_ -like 'Set-Alias*' }.ForEach{ ($_ -split ' ')[2] })
            FileList = @(
                Get-ChildItem -Name -Include '*.ps?1'
                @(@(Get-ChildItem -Recurse -Name -Include '*.ps?1').Where{$_ -like 'lib\*'}.
                ForEach{ [System.IO.Path]::GetDirectoryName($_) } | Select-Object -Unique).
                ForEach{
                    ${Function:Get-ModuleFile} = { ForEach ($FileName in @(Get-ChildItem $args[0] -Name -Include $args[1])) { "$($args[0])\$FileName" } }
                    If ([System.IO.File]::Exists("$_\Root.psm1")) { Get-ModuleFile $_ @('*.psd1','Root.psm1') }
                    Else { ForEach ($FileName in @(Get-ChildItem $_ -Name -Include '*.ps?1')) { "$_\$FileName" } }
                }
            )
            Tags = @('updater','installer','setup','chromium','nsis','innosetup','squirrel','downloadinfo')
            LicenseUri = "$GithubRepo/blob/main/LICENSE.md"
            ProjectUri = $GithubRepo
            IconUri = 'https://rawcdn.githack.com/sangafabrice/reg-cli/f5c95295edb894ff09e41f5b8923ea8ac1d4133a/icon.svg'
            ReleaseNotes = $LatestJson.releaseNotes -join "`n"
        }.ForEach{
            New-ModuleManifest @_ -ErrorAction Stop -Verbose:$VerboseFlag
            # Strip out comments of the manifest script.
            $Content = @(((Get-Content $_.Path -ErrorAction Stop -Verbose:$VerboseFlag).Where{ $_ -match '.+' }.Where{ $_ -notmatch '^\s*#\.*' } -replace ' # End of .+' -replace ", '",",'").ForEach{ $_.Trim() })
            [void] $Content
            # Non-critical step: align functions list and files list on a single line.
            @(
                $ManifestParam = @('FunctionsToExport','CmdletsToExport','FileList','PrivateData','Tags','LicenseUri')
                # The minifier expression pattern: $Content.Where({ $_ -like "$PreviousParam =*" },'SkipUntil').Where({ $_ -like "$CurrentParam =*" },'Until') -join ''
                $JoinOperation = $False
                $PreviousParam = $Null
                $MinifierExpression = ($ManifestParam + @($Null)).ForEach{
                    "`$Content$($(ForEach ($Option in @(@{ Param = $PreviousParam; Operation = 'SkipUntil' },@{ Param = $_; Operation = 'Until' })) { If ($Option.Param) { ".Where({ `$_ -like '$($Option.Param) =*' },'$($Option.Operation)')" } }) -join '')$(If ($JoinOperation) { " -join ''" })"
                    $PreviousParam = $_
                    $JoinOperation = $JoinOperation ? ${False}:${True}
                } -join ';'
                Invoke-Expression $MinifierExpression
            ) | Out-File $_.Path -Verbose:$VerboseFlag
            (Test-ModuleManifest $_.Path).ExportedFunctions.Values
        }
    }
    Catch { $_ }
    Pop-Location
}

Filter Set-RCNestedRootModule {
    <#
    .SYNOPSIS
       Set nested module roots by combining multiple modules in the specified directory.
    #>
    [CmdletBinding()]
    Param(
        [System.IO.DirectoryInfo] $Path
    )
    $ListOfModules = @(Get-ChildItem "$Path\*.psm1" -Exclude 'Root.psm1')
    If($ListOfModules.Count -gt 0) {
        $UsingStatement = @()
        $CommandLines = @()
        @(Get-Content $ListOfModules.ForEach{ "$_" }).Where{ $_ -notlike '#Requires *' }.ForEach{
            If ($_ -match ' *using +module +(?<ModulePath>.*)') { $UsingStatement += 'using module {0}' -f $Matches.ModulePath }
            Else { $CommandLines += $_ }
        }
        $ModuleRootPath = "$Path\Root.psm1"
        $CommandLines = @(
            '#Requires -Version 7.0'
            '#Requires -RunAsAdministrator'
            $UsingStatement | Select-Object -Unique
            $CommandLines
        )
        $CommandLines | ConvertTo-RCMinifiedContent 
        Set-Content $ModuleRootPath $CommandLines
    }
}
#EndRegion

#Region: Function to help access a worktree from the main worktree
Filter Invoke-OnBranch {
    <#
    .SYNOPSIS
        Process a scriptblock on the module branch.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        # Specifies the scriptblock to process.
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,
        # Specifies the list of arguments to the scriptblock.
        [psobject[]] $ArgumentList,
        # Specifies the name of the worktree to process the scriptblock from.
        # The name of the worktree must be the same as its main branch name.
        [ValidateSet('module','test')]
        [string] $Branch = 'module'
    )
    Push-Location $PSScriptRoot
    $ModulePath = [System.IO.Path]::GetFullPath(((git worktree list --porcelain).Where{ $_ -like 'worktree*' }.ForEach{ ($_ -split ' ',2)[1] }.Where{ $_ -like "*/$Branch" }))
    If ([System.IO.Directory]::Exists($ModulePath)) {
        # Process the scriptblock if the RegCli module is installed and is a junction to the module worktree
        @(Get-Module RegCli -ListAvailable | Select-Object -First 1).ForEach{
            If (([System.IO.FileInfo] $_.Path).Directory.Target -ieq $ModulePath) {
                # Change directory to module worktree.
                Push-Location $ModulePath
                If ((git branch --show-current) -ieq $Branch) {
                    # Build arguments to script block.
                    $ScriptBlockArgs = @{}
                    For ($i = 0; $i -lt $ArgumentList.Count; $i++) { $ScriptBlockArgs[@($ScriptBlock.Ast.ParamBlock.Parameters.Name.VariablePath.UserPath)[$i]] = $ArgumentList[$i] }
                    # Process script block with built arguments.
                    If ($PSCmdlet.ShouldProcess("Arguments: $($ScriptBlockArgs.Keys.ForEach{ '-{0} {1}' -f $_,$ScriptBlockArgs.$_ } -join ' ')", "Call Scriptblock")) { Try { & $ScriptBlock @ScriptBlockArgs } Catch { $_ } }
                }
                Pop-Location
            }
        }
    }
    Pop-Location
}
#EndRegion

#Region: The MODULE worktree/branch management.
Filter Publish-RCModule {
    <#
    .SYNOPSIS
        Publish module to PSGallery.
    .NOTES
        Precondition: The NUGET_API_KEY environment variable is set.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    Param()
    Invoke-OnBranch {
        If ($null -eq $Env:NUGET_API_KEY) { Throw 'NUGET_API_KEY_IsNull' }
        Publish-Module -Name RegCli -NuGetApiKey $Env:NUGET_API_KEY -WhatIf:$([bool] $Script:WhatIfPreference)
        $ModuleVersion = [version] (& $DevDependencies.Manifest).ModuleVersion
        If ($ModuleVersion -eq ([version] (Find-Module RegCli).Version)) { Write-Host "RegCli@v$ModuleVersion published." -ForegroundColor Green }
    }.GetNewClosure() -Verbose:$($VerbosePreference -ine 'SilentlyContinue') -WhatIf:$False
}

Filter Push-RCModule {
    <#
    .SYNOPSIS
        Push last commit on module branch to GitHub.
    .OUTPUTS
        Git output details.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    Param()
    Invoke-OnBranch {
        [CmdletBinding(SupportsShouldProcess)]
        Param([hashtable] $ModuleManifest)
        $WhatIfPreference = [bool] $Script:WhatIfPreference
        $ModuleVersion = "v$($ModuleManifest.ModuleVersion)"
        $ShouldTarget = "RegCli $ModuleVersion module"
        # Throw an error if a module file does not exist
        $ModuleManifest.FileList.ForEach{ If (![System.IO.File]::Exists("$($PWD.Path)\$_")) { Throw 'ModuleFileDoesNotExist' } }
        # Delete files that are not module files.
        @(Get-ChildItem -Recurse -Name -File).Where{ $_ -inotin $ModuleManifest.FileList }.ForEach{ Remove-Item $_ -WhatIf:$WhatIfPreference }
        If ($PSCmdlet.ShouldProcess($ShouldTarget, "Stage Change")) { git add . }
        # Commit and push only if there is a change in the module directory and subdirectories.
        If ($WhatIfPreference -or @(git diff --name-only --cached).Count -gt 0) {
            If ($PSCmdlet.ShouldProcess($ShouldTarget, "Commit Change")) {
                git commit -m "RELEASE: $ModuleVersion`n$($ModuleManifest.PrivateData.PSData.ReleaseNotes)" --amend
                If (!$?) { Throw 'GitCommitModuleChangeFailed' }
            }
            If ($PSCmdlet.ShouldProcess($ShouldTarget, "Push Change")) {
                git push origin module --force
                If (!$?) { Throw 'PushModuleToGitHubFailed' }
            }
            If ($PSCmdlet.ShouldProcess($ShouldTarget, "Push Tag")) {
                If ($ModuleVersion -inotin @(git tag --list)) {
                    git tag $ModuleVersion
                    If (!$?) { Throw 'CreateModuleTagToGitHubFailed' }
                    git push --tags
                    If (!$?) { Throw 'PushModuleTagToGitHubFailed' }
                }
            }
        }
    }.GetNewClosure() (& $DevDependencies.Manifest) -Verbose:$($VerbosePreference -ine 'SilentlyContinue') -WhatIf:$False
}

Filter Deploy-RCModule {
    <#
    .SYNOPSIS
        Deploy module to GitHub and PowerShell Gallery.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    Param()
    Push-RCModule -WhatIf:$WarningPreference
    Publish-RCModule -WhatIf:$WhatIfPreference
}
#EndRegion

#Region : Build the minifier.
Function ConvertTo-RCMinifiedContent {
    <#
    .SYNOPSIS
        Remove comments from scripts.
    #>
    [CmdletBinding()]
	[OutputType([string])]
    Param(
        # Specifies a piece of script code string.
        [Parameter(ValueFromPipeline)]
        [string] $Code
    )
    # Start outside the block comment by default.
    Begin { $LineIsInCommentBlock = 0 }
    Process {
        # Split the code by line 
        ($Code -split [System.Environment]::NewLine).ForEach{
            # A comment is good to be stripped out of the script code if it is a line comment
            # that starts with a space '# ' or '#Region' or '#EndRegion.' 
            If ($_ -notmatch '^\s*#( |(\b(End)?Region\b))') {
                $Line = $_.Trim()
                # Block comments are kept as they are used to build comment-based help documentation of functions.
                If ($Line -like '<#*' -or $Line -like '#>*') { $LineIsInCommentBlock = (++$LineIsInCommentBlock) % 2 }
                If (!$LineIsInCommentBlock -and $Line -match '^\s*$') { $Null } Else { $Line }
            }
        }
    }
}

Function Start-RCMinify {
    <#
    .SYNOPSIS
       Minify the content of the module files.
    #>
    [CmdletBinding(DefaultParameterSetName='Name')]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, Position=0, ParameterSetName='Name')]
        [ValidateSet([ModuleFiles])]
        [string] $Name,
        [Parameter(ParameterSetName='All')]
        [switch] $All
    )
    Begin {
        $DistModule = '{0}\module' -f [System.IO.Path]::GetDirectoryName($PSScriptRoot)
        If ($All) {
            $FileList = @((& $DevDependencies.Manifest).FileList)
            (Get-ChildItem $DistModule -Recurse -File -Name).Where{ $_ -inotin $FileList }.ForEach{ Remove-Item "$DistModule\$_" -Force }
            $DistModuleDirs =  @((Get-ChildItem $DistModule -Name -Recurse -Directory).ForEach{ "$DistModule\$_" })
            Try {
                Try { [array]::Reverse($DistModuleDirs) } Catch { }
                ForEach ($Dir in $DistModuleDirs) {
                    If (@(Get-ChildItem $Dir).Count -gt 0) { Continue }
                    Remove-Item $Dir -ErrorAction SilentlyContinue
                }
            }
            Catch { }
            $FileList | Start-RCMinify
        }
    }
    Process {
        $ProjectFilePath = "$PSScriptRoot\$Name"
        If ([System.IO.File]::Exists($ProjectFilePath)) {
            Try {
                $SetContentArgs = @{
                    Path = "$DistModule\$Name"
                    Value = @(
                        $StreamReader = [System.IO.StreamReader]::New($ProjectFilePath)
                        While ($StreamReader.Peek() -ge 0) { $StreamReader.ReadLine() }
                        $StreamReader.Close()
                        $StreamReader.Dispose()
                    )
                    ErrorAction = 'Stop'
                    Verbose = $VerbosePreference -ine 'SilentlyContinue'
                }
                $SetContentArgs.Value = $SetContentArgs.Value.ForEach{ ConvertTo-RCMinifiedContent $_ }
                Try { Set-Content @SetContentArgs }
                Catch {
                    Try {
                        @{
                            Path = [System.IO.Path]::GetDirectoryName($SetContentArgs.Path)
                            ItemType = 'Directory'
                            Verbose = $SetContentArgs.Verbose
                            ErrorAction = 'SilentlyContinue'
                        } | ForEach-Object { $Null = New-Item @_ }
                        Set-Content @SetContentArgs
                    }
                    Catch { }
                }
            }
            Catch { Write-Output (Get-Date -Format 'MM/dd/yyy : HH:mm.ss') }
        }
    }
}

Filter Register-RCAutominifier {
    <#
    .SYNOPSIS
        Install build modules
    #>
    [CmdletBinding()]
	[OutputType([pscustomobject])]
    Param()
    ((& $DevDependencies.Manifest).FileList |
    ForEach-Object -Begin { $List = @() } -Process {
        $Current = @{
            Path = [System.IO.DirectoryInfo][System.IO.Path]::GetDirectoryName("$PSScriptRoot\$_")
            Name = [System.IO.Path]::GetDirectoryName($_)
            Files = @([System.IO.Path]::GetFileName($_))
        }
        If (${List}?[-1].Path.FullName -ieq $Current.Path.FullName) { $List[-1].Files += @($Current.Files) }
        Else { $List += @([pscustomobject] $Current) }
    } -End { $List }
    ).ForEach{
        [System.IO.FileSystemWatcher] $Watcher = $_.Path.FullName
        $_.Files.ForEach{ $Watcher.Filters.Add($_) }
        $Watcher.NotifyFilter = 'LastWrite'
        $Watcher.IncludeSubdirectories = $True
        $Watcher.EnableRaisingEvents = $True
        $Current = @{
            EvtName = (Register-ObjectEvent -InputObject $Watcher -EventName Changed -Action {
            $DoubleChangeFlag = $DoubleChangeFlag ? ($False):($True)
            If (!$DoubleChangeFlag) { Try { Start-RCMinify ("$TargetDirectory\$(($Event.SourceArgs)[1].Name)" -replace '^\\+') } Catch { } }
            }).Name
            Target = $_.Path.Name
        }
        & (Get-EventSubscriber -SourceIdentifier $Current.EvtName).Action.Module { Set-Variable 'TargetDirectory' $args[0] -Scope Script -Option Constant } $_.Name
        [pscustomobject] $Current
    }  
}
#EndRegion

#Region: The TEST worktree/branch management.

#EndRegion

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
    } | ForEach-Object {
        & $_ Pester {
            If ($PSVersionTable.PSVersion.Major -eq 5) {
                Install-PackageProvider Nuget -Force | Out-Null
                'PackageManagement','PowershellGet' |
                ForEach-Object { Import-Module $_ -RequiredVersion 1.0.0.1 -Force }
                @(
                    "${Env:ProgramFiles(x86)}\WindowsPowerShell\Modules\Pester\3.4.0"
                    "${Env:ProgramFiles}\WindowsPowerShell\Modules\Pester\3.4.0"
                ) | ForEach-Object {
                    $TakeOwn = {
                        Param($Path)
                        $FileAcl = Get-Acl $Path
                        $Identity = 'BUILTIN\Administrators'
                        $FileAcl.SetOwner([System.Security.Principal.NTAccount]::new($Identity))
                        $FileAcl.SetAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($Identity, 'FullControl', 'Allow'))
                        Set-Acl $Path -AclObject $FileAcl
                    }
                } {
                    If (Test-Path $_) {
                        Try {
                            & $TakeOwn $_
                            (Get-ChildItem $_ -Recurse).FullName |
                            ForEach-Object { & $TakeOwn $_ }
                            Remove-Item $_ -Recurse -Force
                        }
                        Catch { }
                    }
                }
            }
        }
    }
}

#Region : Organize the RegCli project into multiple directories.
Filter Set-RCCodeWorkspaceSettingFile {
    <#
    .SYNOPSIS
        Updates the vscode workspace setting file.
    .NOTES
        It is important to keep the setting file stripped out of any comment to maintain a clean JSON format.
    #>
    [CmdletBinding()]
	[OutputType([void])]
    Param()
    # The path to the vscode workspace setting file.
    '{0}\REGCLI.code-workspace' -f $PSScriptRoot |
    ForEach-Object {
        Set-Content $_ (
            Get-Content $_ -Raw |
            ConvertFrom-Json |
            ForEach-Object {
                # Updates vscode-powershell extension default working directory. 
                $_.settings.'powershell.cwd' = $PSScriptRoot -replace '\\+','/'
                # List of primary worktree file names, the main directory excluded.
                $Script:CodeWorkspaceFolders = @(
                    $_.folders.path |
                    Where-Object { $_ -ine '.' } |
                    ForEach-Object { [System.IO.Path]::GetFileName($_) }
                )
                $_ | ConvertTo-Json
            }
        ) -Verbose:$($VerbosePreference -ine 'SilentlyContinue')
    }
}

Filter Set-RCCodeWorkspaceFolders {
    <#
    .SYNOPSIS
        Install the missing workspace folders.
    .NOTES
        The main project folder is excluded.
    #>
    [CmdletBinding(SupportsShouldProcess)]
	[OutputType([void])]
    Param()
    # List of primary worktree file names, the main directory excluded.
    $Script:CodeWorkspaceFolders |
    ForEach-Object -Begin { $ProjectParent = [System.IO.Path]::GetDirectoryName($PSScriptRoot) } -Process {
        $GitWorktree = "$ProjectParent\$_"
        If ($PSCmdlet.ShouldProcess("Path: $GitWorktree", "Add Worktree")) {
            # The git command to add the worktree
            git worktree add "$GitWorktree" $_ > $Null 2>&1
            If ($?) { [void] $PSCmdlet.ShouldProcess("Branch: $_", "Checkout Branch") }
        }
    }
}

Filter New-RCJunction {
    <#
    .SYNOPSIS
        Creates a junction to the RegCli module directory in the first module path.
    #>
	[CmdletBinding()]
	[OutputType([void])]
    Param(
        # Specified that the junction creation be forced.
        [switch] $Force
    )
	$NewItemArgs = @{
        # The path to RegCli module in the first powershell module path.
		Path = '{0}\RegCli' -f ($env:PSModulePath -split ';')[0]
		ItemType = 'Junction'
        # The path to the git worktree where the module branch is checked out.
		Value = '{0}\module' -f [System.IO.Path]::GetDirectoryName($PSScriptRoot)
		Force = $Force
		ErrorAction = 'Stop'
		Verbose = $VerbosePreference -ine 'SilentlyContinue'
		Confirm = $False
	}
    Try { New-Item @NewItemArgs }
	Catch {
		If ($Force) {
			Try {
				@{
					Path = $NewItemArgs.Path
					Recurse = $True
					Force = $True
					Verbose = $NewItemArgs.Verbose
				}.ForEach{ Remove-Item @_ }
				New-Item @NewItemArgs
			}
			Catch { Write-Error $_.Exception.Message }
		}
		Else { Write-Error ('{0} Use -Force parameter to reset it.' -f $_.Exception.Message ) }
	}
}

Filter Set-RCProject {
    <#
    .SYNOPSIS
        Organize the RegCli project into multiple directories.
    #>
	[CmdletBinding()]
	[OutputType([void])]
    Param(
        # Specified that the junction creation be forced.
        [switch] $Force
    )
    $VerboseFlag = $VerbosePreference -ine 'SilentlyContinue'
    Set-RCCodeWorkspaceSettingFile -Verbose:$VerboseFlag
    Set-RCCodeWorkspaceFolders -Verbose:$VerboseFlag
    New-RCJunction -Force:$Force -Verbose:$VerboseFlag
}
#EndRegion
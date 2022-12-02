Class Minifier {
    Static [void] Minify([System.IO.FileInfo] $ScriptPath) {
        # Flag notifying that the line being read is within a block comment.
        $LineIsInCommentBlock = 0
        # Delete commented lines with one space between the character # and the first character of the comment.
        $MinifiedModuleContent = (Get-Content "$ScriptPath").Where({ $_ -notmatch '^\s*# ' }).ForEach({ $_.Trim() }).
        ForEach{
            If ($_ -like '<#*' -or $_ -like '#>*') { $LineIsInCommentBlock = (++$LineIsInCommentBlock) % 2 }
            # Delete lines that are not block comments and are empty lines.
            If (!$LineIsInCommentBlock -and $_ -match '^\s*$') { $Null } Else { $_ }
        }
        # Copy the minified content to the final module script file which name is obtained by removing the leading '__'.
        Set-Content "$PSScriptRoot\$($ScriptPath.Name.Substring(2))" -Value $MinifiedModuleContent
    }
    # Get the list of modules to minify and they all start with '__'.
    Static [System.IO.FileInfo[]] GetModuleList() { Return @(Get-ChildItem "$PSScriptRoot\*" -Include '__*.psm1') }
}

# Register AutoMinifier event that is triggered when the specified modules are changed.
@{
    InputObject = [System.IO.FileSystemWatcher] $PSScriptRoot
    EventName = 'Changed'
    Action = {
        $WatchedModule = ($Event.SourceArgs)[1]
        If ($WatchedModule.Name -iin [Minifier]::GetModuleList().Name) { [Minifier]::Minify($WatchedModule.FullPath) }
    }
    SourceIdentifier = 'AutoMinifier'
} | ForEach-Object { $Null = Register-ObjectEvent @_ }

<#
.SYNOPSIS
    Minifies the content of the specified module.
#>
Filter Set-MinifiedContent {
    [CmdletBinding(DefaultParameterSetName = 'One')]
    Param (
        # Specifies the name of the module to minify.
        [Parameter(ParameterSetName = 'One', Position = 0)]
        [string[]] $Module,
        # Specifies that all the modules in the class directory be minified.
        [Parameter(ParameterSetName = 'All')]
        [switch] $All
    )
    If ($PSCmdlet.ParameterSetName -like 'One') { [System.IO.FileInfo[]] $Module = $Module.ForEach{ "$PSScriptRoot\__$_.psm1" } }
    ($All ? ([Minifier]::GetModuleList().FullName):($Module.Where{ $_.BaseName -like '__*' })).ForEach{ "$_"; [Minifier]::Minify($_) }
}

# Auto-complete the values of the -Module parameter in Set-MinifiedContent.
Register-ArgumentCompleter -CommandName Set-MinifiedContent -ParameterName Module -ScriptBlock {
    Param(
        $CommandName,
        $ParameterName,
        $wordToComplete,
        $CommandAst,
        $FakeBoundParameters
    )
    [Minifier]::GetModuleList().BaseName.Where{ $_.Substring(2) -like "$wordToComplete*" }.ForEach{ $_.Substring(2) }
}.GetNewClosure()

# Remove AutoMinifier event.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = { Unregister-Event -SourceIdentifier AutoMinifier }
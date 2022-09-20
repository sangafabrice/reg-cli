using module ".\RegCli.psm1"

Class ValidationUtility {
    Static [bool] ValidateFileSystem($Path) {
        Return (Get-Item -LiteralPath $Path).PSDrive.Name -iin @((Get-PSDrive -PSProvider FileSystem).Name)
    }

    Static [bool] ValidatePathString($Path) {
        $Pattern = '(?<Drive>^.+):'
        If ($Path -match $Pattern -or $PWD -match $Pattern) {
            Return $Matches.Drive -iin @((Get-PSDrive -PSProvider FileSystem).Name)
        }
        Return $False
    }

    Static [bool] ValidateSsl($Url) { Return $Url.Scheme -ieq 'https' }

    Static [bool] ValidateVersion($Version) { Return $Version.GetType() -iin @('String','Version','DateTime') }
}

$__GetCommonApis = {
    $Script:__CommonApis = $(
        Try {
            ("$(Invoke-WebRequest ("$(Invoke-WebRequest 'https://api.github.com/repos/sangafabrice/reg-cli/git/trees/main')" |
            ConvertFrom-Json).tree.Where({ $_.path -like 'common' }).url)" |
            ConvertFrom-Json).tree.Where({ $_.path -like "*@$([RegCli]::CommonScriptVersion).ps1" }).path |
            ForEach-Object { ($_ -split '@')?[0] }
        }
        Catch { }
    )
    Return $__CommonApis
}

Class CommonName : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        Return [string[]] $(
            $Script:__CommonApis ?? (& $Script:__GetCommonApis) ??
            (Get-ChildItem "$PSScriptRoot\..\common" -ErrorAction SilentlyContinue -Exclude '*.ps1').Name
        )
    }
}
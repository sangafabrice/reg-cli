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
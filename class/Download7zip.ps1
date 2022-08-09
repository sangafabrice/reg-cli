& {
    $PSScriptRoot |
    ForEach-Object {
        Set-Variable -Name '7Z_EXE' -Value '7z.exe' -Option Constant
        Set-Variable -Name '7Z_DLL' -Value '7z.dll' -Option Constant
        If ((Test-Path "$_\$7Z_EXE","$_\$7Z_DLL").Where({ $_ }).Count -lt 2) {
            Set-Variable -Name 'CHECKSUM' -Value @{
                '7z' = '8C8FBCF80F0484B48A07BD20E512B103969992DBF81B6588832B08205E3A1B43'
                '7z_x64' = 'B055FEE85472921575071464A97A79540E489C1C3A14B9BDFBDBAB60E17F36E4'
                '7zr' = '5E47D0900FB0AB13059E0642C1FFF974C8340C0029DECC3CE7470F9AA78869AB'
            } -Option Constant
            Set-Variable -Name 'CURRENT_DIRECTORY' -Value $PWD -Option Constant
            Set-Location $_
            Try {
                Set-Variable -Name '7Z_URL' -Value (
                    'https://www.7-zip.org/a/7z2201{0}.exe' -f ([Environment]::Is64BitOperatingSystem ? '-x64':'')
                ) -Option Constant
                Set-Variable -Name '7ZR_URL' -Value 'https://www.7-zip.org/a/7zr.exe' -Option Constant
                Start-BitsTransfer $7ZR_URL,$7Z_URL
                Set-Variable -Name '7Z_SETUP' -Value ([uri] $7Z_URL).Segments?[-1] -Option Constant
                Set-Variable -Name '7ZR_SETUP' -Value ([uri] $7ZR_URL).Segments?[-1] -Option Constant
                Set-Variable -Name 'REMOVE_SETUP' -Value { 
                    Remove-Item $7Z_SETUP,$7ZR_SETUP -Force -ErrorAction SilentlyContinue 
                } -Option Constant
                Set-Variable -Name 'COMPARE_SHA' -Value {
                    Param($File, $Hash)
                    If ((Get-FileHash $File -Algorithm SHA256).Hash -ine $Hash) { 
                        & $REMOVE_SETUP
                        Throw
                    }
                } -Option Constant
                Switch ($7Z_SETUP) {
                    { $_ -like '*-x64.exe' } { & $COMPARE_SHA $_ $CHECKSUM.'7z_x64' }
                    Default { & $COMPARE_SHA $_ $CHECKSUM.'7z' }
                }
                & $COMPARE_SHA $7ZR_SETUP $CHECKSUM.'7zr'
                . ".\$7ZR_SETUP" x -aoa -o"$_" $7Z_SETUP '7z.exe' '7z.dll' | Out-Null
                & $REMOVE_SETUP
            }
            Finally { Set-Location $CURRENT_DIRECTORY }
        }
    }
}
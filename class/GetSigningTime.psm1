Function Get-AuthenticodeSigningTime {
    [CmdletBinding(HelpUri = 'https://www.sysadmins.lv/blog-en/retrieve-timestamp-attribute-from-digital-signature.aspx')]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]] $FilePath
    )
    Begin {
        $Signature = @"
            [DllImport("crypt32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern bool CryptQueryObject(
                int dwObjectType,
                [MarshalAs(UnmanagedType.LPWStr)]string pvObject,
                int dwExpectedContentTypeFlags,
                int dwExpectedFormatTypeFlags,
                int dwFlags,
                ref int PdwMsgAndCertEncodingType,
                ref int PdwContentType,
                ref int PdwFormatType,
                ref IntPtr phCertStore,
                ref IntPtr phMsg,
                ref IntPtr ppvContext
            );
            [DllImport("crypt32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern bool CryptMsgGetParam(
                IntPtr hCryptMsg,
                int dwParamType,
                int dwIndex,
                byte[] pvData,
                ref int pcbData
            );
            [DllImport("crypt32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern bool CryptMsgClose(IntPtr hCryptMsg);
            [DllImport("crypt32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern bool CertCloseStore(IntPtr hCertStore, int dwFlags);
"@
        Add-Type -AssemblyName System.Security
        Add-Type -MemberDefinition $Signature -Namespace PKI -Name Crypt32
    }
    Process {
        (Get-AuthenticodeSignature @PSBoundParameters).Where({ $_.SignerCertificate }) |
        ForEach-Object {
            $PdwMsgAndCertEncodingType =  0
            $PdwContentType =  0
            $PdwFormatType =  0
            [IntPtr] $PhCertStore = [IntPtr]::Zero
            [IntPtr] $PhMsg = [IntPtr]::Zero
            [IntPtr] $PpvContext = [IntPtr]::Zero
            [void] [PKI.Crypt32]::CryptQueryObject(
                1,
                $_.Path,
                16382,
                14,
                $Null,
                [ref] $PdwMsgAndCertEncodingType,
                [ref] $PdwContentType,
                [ref] $PdwFormatType,
                [ref] $PhCertStore,
                [ref] $PhMsg,
                [ref] $PpvContext
            )
            $PcbData = 0
            [void] [PKI.Crypt32]::CryptMsgGetParam($PhMsg, 29, 0, $Null, [ref] $PcbData)
            $PvData = New-Object byte[] -ArgumentList $PcbData
            [void] [PKI.Crypt32]::CryptMsgGetParam($PhMsg, 29, 0, $PvData, [ref] $PcbData)
            $SignedCms = New-Object Security.Cryptography.Pkcs.SignedCms
            $SignedCms.Decode($PvData)
            Foreach ($Infos In $SignedCms.SignerInfos) {
                Foreach ($CounterSignerInfos In $Infos.CounterSignerInfos) {
                    $STime = ($CounterSignerInfos.SignedAttributes |
                    Where-Object { $_.Oid.Value -eq '1.2.840.113549.1.9.5' }).Values |
                    Where-Object { $Null -ne $_.SigningTime }
                }
            }
            $STime.SigningTime
            [void][PKI.Crypt32]::CryptMsgClose($PhMsg)
            [void][PKI.Crypt32]::CertCloseStore($PhCertStore, 0)
        }
    }
    End { }
}
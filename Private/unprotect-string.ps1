function Unprotect-String {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$EncryptedString,

        [Parameter(Mandatory = $true)]
        [ValidateSet('DPAPI', 'SharedKey')]
        [string]$ProtectionType
    )
    
    $BSTR = $null # Initialize $BSTR
    try {
        $secureString = $null
        if ($ProtectionType -eq 'DPAPI') {
            # Use DPAPI (user/machine scope) - no key
            $secureString = ConvertTo-SecureString -String $EncryptedString
        }
        elseif ($ProtectionType -eq 'SharedKey') {
             # Use AES with the hardcoded shared key
            $secureString = ConvertTo-SecureString -String $EncryptedString -Key (1..16)
        }
        
        if ($null -eq $secureString) {
            throw "Failed to convert encrypted string to SecureString using method '$($ProtectionType)'."
        }

        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    finally {
        if ($BSTR) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }
    }
}
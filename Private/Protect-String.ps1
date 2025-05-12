function Protect-String {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$String,

        [Parameter(Mandatory = $true)]
        [ValidateSet('DPAPI', 'SharedKey')]
        [string]$ProtectionType
    )
    
    $secureString = ConvertTo-SecureString -String $String -AsPlainText -Force
    
    if ($ProtectionType -eq 'DPAPI') {
        # Use DPAPI (user/machine scope) - no key
        $encrypted = $secureString | ConvertFrom-SecureString
    }
    elseif ($ProtectionType -eq 'SharedKey') {
        # Use AES with the hardcoded shared key
        $encrypted = $secureString | ConvertFrom-SecureString -Key (1..16)
    }
    # Note: ValidationSet ensures we don't need an else here
    
    return $encrypted
}
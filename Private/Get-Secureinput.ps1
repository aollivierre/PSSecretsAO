function Get-SecureInput {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )
    
    $secureString = Read-Host -Prompt $Prompt -AsSecureString
    return $secureString
}
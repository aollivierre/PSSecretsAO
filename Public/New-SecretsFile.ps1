<#
.SYNOPSIS
Creates a new encrypted secrets file.

.DESCRIPTION
Creates a new secrets file at the specified path. 
It can use either Windows DPAPI (recommended, tied to user/machine) or a less secure shared key (for portability) for encryption.
If the -Data parameter is provided, it encrypts the values in the hashtable and saves them.
If -Data is not provided, it interactively prompts the user for TenantID, ClientID, and ClientSecret (using the chosen encryption method).

.PARAMETER FilePath
The full path where the secrets file will be created.

.PARAMETER Data
A hashtable containing the key-value pairs to encrypt and save to the file.
Values that are strings will be encrypted; other types will be stored as-is.

.PARAMETER EncryptionMethod
Specifies the encryption method to use.
- DPAPI (Default): Uses Windows DPAPI, tying encryption to the current user and machine. More secure.
- Portable: Uses AES with a shared, hardcoded key. Less secure, but allows the file to be decrypted on other machines or by other users if they have the module code.

.EXAMPLE
New-SecretsFile -FilePath C:\temp\mysecrets.psd1
# Prompts interactively, encrypts using DPAPI (default).

.EXAMPLE
$mySecrets = @{ ApiKey = 'abc'; Timeout = 30 }
New-SecretsFile -FilePath C:\temp\apisecrets.psd1 -Data $mySecrets -EncryptionMethod Portable
# Creates the file non-interactively with encrypted ApiKey (using shared key) and plain Timeout.

.OUTPUTS
Hashtable. Returns a hashtable containing the original, unencrypted key-value pairs.
#>
function New-SecretsFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter()]
        [hashtable]$Data,

        [Parameter()]
        [ValidateSet('DPAPI', 'Portable')]
        [string]$EncryptionMethod = 'DPAPI' # Default to more secure DPAPI
    )

    # Determine the internal ProtectionType based on user choice
    $protectionTypeForFunc = if ($EncryptionMethod -eq 'DPAPI') { 'DPAPI' } else { 'SharedKey' }
    Write-Verbose "Using protection type: $protectionTypeForFunc"

    #Ensure the directory exists
    $directory = Split-Path -Path $FilePath -Parent
    if (-not (Test-Path -Path $directory)) {
        try {
            New-Item -Path $directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Verbose "Created directory $directory"
        }
        catch {
             Write-Error "Failed to create directory '$directory'. Error: $($_.Exception.Message)"
             return $null # Indicate failure
        }
    }

    $returnData = $null
    $objectToSave = $null
    $encryptionMethodUsed = $EncryptionMethod # Use the parameter value for metadata

    # Non-interactive mode: Use provided -Data
    if ($PSBoundParameters.ContainsKey('Data')) {
        Write-Verbose "Processing -Data parameter for non-interactive file creation using '$($EncryptionMethod)' method."
        $encryptedData = @{}
        foreach ($key in $Data.Keys) {
            $value = $Data[$key]
            # Only encrypt strings, store others as-is (simplistic approach)
            if ($value -is [string]) {
                 try {
                     # Pass the determined protection type to Protect-String
                     $encryptedData[$key] = Protect-String -String $value -ProtectionType $protectionTypeForFunc
                 }
                 catch {
                      Write-Error "Failed to protect string for key '$key' using method '$($EncryptionMethod)'. Error: $($_.Exception.Message)"
                      return $null # Indicate failure
                 }
            }
            else {
                 $encryptedData[$key] = $value
                 Write-Warning "Value for key '$key' is not a string and was not encrypted."
            }
        }
        $objectToSave = $encryptedData
        $returnData = $Data # Return the original data
    }
    # Interactive mode: Prompt user (original behavior)
    else {
        Write-Host "`nCreating secrets file interactively: $FilePath (Encryption: $($EncryptionMethod))" -ForegroundColor Yellow
        Write-Host "Please enter the following information:" -ForegroundColor Cyan

        $tenantId = Read-Host -Prompt "Enter your Tenant ID"
        $clientId = Read-Host -Prompt "Enter your Application (Client) ID"
        $clientSecretSecure = Get-SecureInput -Prompt "Enter your Client Secret"

        # Check if Get-SecureInput returned a secure string
        if ($null -eq $clientSecretSecure -or -not ($clientSecretSecure -is [System.Security.SecureString])) {
            Write-Error "Failed to get secure input for Client Secret."
            return $null
        }

        # Convert SecureString to plain text for encryption & return value
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientSecretSecure)
        $plainSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

        # Encrypt values for saving using the chosen method
        try {
             $encryptedTenantId = Protect-String -String $tenantId -ProtectionType $protectionTypeForFunc
             $encryptedClientId = Protect-String -String $clientId -ProtectionType $protectionTypeForFunc
             $encryptedClientSecret = Protect-String -String $plainSecret -ProtectionType $protectionTypeForFunc
        }
        catch {
             Write-Error "Failed to protect one or more secret strings using method '$($EncryptionMethod)'. Error: $($_.Exception.Message)"
             # Clear potentially sensitive variable
             Clear-Variable plainSecret -ErrorAction SilentlyContinue
             return $null
        }

        # Create object with encrypted values
        $secretsToSave = @{
            TenantID     = $encryptedTenantId
            ClientID     = $encryptedClientId
            ClientSecret = $encryptedClientSecret
        }
        $objectToSave = $secretsToSave

        # Prepare plain text data for return
        $returnData = @{
            TenantID     = $tenantId
            ClientID     = $clientId
            ClientSecret = $plainSecret # Return the plain text version gathered
        }
        # Clear potentially sensitive variable after use
        Clear-Variable plainSecret -ErrorAction SilentlyContinue
    }

    # Save the object (either from $Data or interactive prompts) to file
    if ($null -ne $objectToSave) {
         # Add metadata key for encryption method
         $metadataKey = '_PSSecretsAO_EncryptionMethod' # Choose a unique prefix
         $objectToSave[$metadataKey] = $encryptionMethodUsed
         
         try {
             # Build PSD1 content line by line
             $psd1Lines = @(
                 "# PowerShell Data File for Encrypted Secrets",
                 "# Generated by PSSecretsAO on $(Get-Date)",
                 "@{"
             )
             foreach ($key in $objectToSave.Keys) {
                 $value = $objectToSave[$key]
                 # Escape single quotes within the value if necessary
                 $escapedValue = $value -replace "'","''"
                 # Quote the value - assumes string or simple type representable as string
                 # Add line to the array, ensuring proper quoting and indentation
                 $psd1Lines += "    '$key' = '$escapedValue'"
             }
             $psd1Lines += "}"

             # Join lines with OS-appropriate newline and save
             $fileContent = $psd1Lines -join [System.Environment]::NewLine
             Set-Content -Path $FilePath -Value $fileContent -Encoding UTF8 -Force -ErrorAction Stop
             
             Write-Host "Secrets file saved successfully to '$FilePath'! (Encryption: $($encryptionMethodUsed))" -ForegroundColor Green
             # Return the original/plain data
             return $returnData
         }
         catch {
             Write-Error "Failed to save secrets file '$FilePath': $($_.Exception.Message)"
             return $null # Indicate failure
         }
    }
    else {
         Write-Error "No data was prepared to be saved to the secrets file."
         return $null
    }
}
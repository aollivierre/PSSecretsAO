<#
.SYNOPSIS
Imports and decrypts secrets from a specified PSD1 file.

.DESCRIPTION
Reads a PSD1 file created by New-SecretsFile, determines the encryption method used,
decrypts the string values, and returns a hashtable with the plain text secrets.

.PARAMETER FilePath
The full path to the secrets file to import.

.EXAMPLE
$secrets = Import-SecretsFile -FilePath C:\temp\mysecrets.psd1
$apiKey = $secrets.ApiKey

.OUTPUTS
Hashtable. Returns a hashtable containing the decrypted key-value pairs.
#>
function Import-Secretsfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    # Check if file exists - Throw terminating error if not
    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        throw "Secrets file does not exist: $FilePath"
    }

    # Try reading and parsing the file - Throw terminating error on parse failure
    $encryptedHashtable = $null
    try {
        $fileContent = Get-Content -Path $FilePath -Raw -ErrorAction Stop
        # Use Invoke-Expression to parse the PSD1 content
        # WARNING: Ensure $FilePath comes from a trusted source or is validated,
        # as Invoke-Expression executes code.
        $encryptedHashtable = Invoke-Expression -Command $fileContent
    }
    catch {
        throw "Failed to import/parse secrets file '$FilePath': $($_.Exception.Message)"
    }

    if ($null -eq $encryptedHashtable -or -not ($encryptedHashtable -is [hashtable])) {
         throw "Parsed data from file '$FilePath' is null or not a valid hashtable."
    }
    
    # Determine encryption method used
    $metadataKey = '_PSSecretsAO_EncryptionMethod'
    $protectionTypeToUse = 'SharedKey' # Default for legacy files or if key is missing
    $encryptionMethod = 'Portable' # Default for legacy files

    if ($encryptedHashtable.ContainsKey($metadataKey)) {
        $storedMethod = $encryptedHashtable[$metadataKey]
        $encryptionMethod = $storedMethod
        if ($storedMethod -eq 'DPAPI') {
            $protectionTypeToUse = 'DPAPI'
        }
        elseif ($storedMethod -eq 'Portable') {
            $protectionTypeToUse = 'SharedKey'
        }
        else {
            Write-Warning "Unknown encryption method '$($storedMethod)' specified in secrets file '$FilePath'. Defaulting to SharedKey decryption."
        }
        Write-Verbose "Determined protection type for decryption: $protectionTypeToUse (from file metadata: $storedMethod)"
        # Remove the metadata key from the hashtable to be processed for decryption
        $encryptedHashtable.Remove($metadataKey) | Out-Null
    }
    else {
        Write-Warning "Secrets file '$FilePath' does not contain an encryption method hint. Assuming legacy SharedKey encryption. Re-save with New-SecretsFile for enhanced security options."
        Write-Verbose "Using default protection type for decryption: $protectionTypeToUse (metadata hint missing)"
    }

    # Decrypt values
    $decryptedSecrets = @{}
    
    # Add back the encryption method metadata to the returned hashtable
    $decryptedSecrets[$metadataKey] = $encryptionMethod
    
    if ($null -ne $encryptedHashtable) {
        foreach ($entry in $encryptedHashtable.GetEnumerator()) {
            $key = $entry.Name
            $encryptedValue = $entry.Value

            if ($encryptedValue -is [string] -and $encryptedValue.Length -gt 0) {
                try {
                    $decryptedSecrets[$key] = Unprotect-String -EncryptedString $encryptedValue -ProtectionType $protectionTypeToUse -ErrorAction Stop
                }
                catch {
                    throw "Failed to decrypt value for key '$key' using method '$protectionTypeToUse'. Error: $($_.Exception.Message)"
                }
            }
            else {
                $decryptedSecrets[$key] = $encryptedValue
                Write-Verbose "Value for key '$key' was $($encryptedValue.GetType().Name) or empty string, not decrypted."
            }
        }
    }
    else {
        Write-Verbose "Secrets file '$FilePath' contained no properties to decrypt after processing metadata."
    }

    Write-Verbose "Import-Secretsfile: Returning decrypted secrets: $($decryptedSecrets | ConvertTo-Json -Depth 3 -Compress)"
    return $decryptedSecrets
}
# PSSecretsAO Module

**Version:** 1.2.0 (Updated)
**Author:** Abdullah Ollivierre
**Minimum PowerShell Version:** 5.1

## Description

The PSSecretsAO module provides basic functions for creating and reading simple encrypted secrets files in PowerShell. It now supports two encryption methods:

1.  **DPAPI (Default & Recommended):** Uses Windows Data Protection API. Secrets are encrypted using the current user's context and can typically only be decrypted by the same user on the same machine. This is the most secure method offered by this module.
2.  **Portable (Legacy):** Uses AES encryption with a static, hardcoded key (`1..16`) defined within the private functions. This method is **insecure** but allows the encrypted file to be potentially decrypted on other machines or by other users *if* they have access to the module's code (specifically the key).

**\\\\\\*\\\\\\*\\\\\\* WARNING: SECURITY RISK (Portable Method) \\\\\\*\\\\\\*\\\\\\***

The `Portable` encryption method uses a **static, hardcoded key**. This means:

1.  **The encryption is weak.** Anyone with access to the module's source code (specifically `Protect-String.ps1` and `Unprotect-String.ps1`) can easily decrypt secrets created using this method.
2.  The encryption is **not tied** to the user account or machine.
3.  **DO NOT USE THE `Portable` METHOD FOR STORING SENSITIVE PRODUCTION SECRETS.** It only provides basic obfuscation, not robust security. Use `DPAPI` whenever possible.

**\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\*\\\\\\***

## Functions

### Public Functions

*   `New-SecretsFile`:
    *   Creates a new secrets file.
    *   Uses the `-EncryptionMethod` parameter (`DPAPI` [default] or `Portable`) to choose the encryption strategy.
    *   Can operate interactively (prompting for TenantID, ClientID, ClientSecret by default) or non-interactively using the `-Data` parameter to encrypt a provided hashtable.
    *   Stores a hint (`_PSSecretsAO_EncryptionMethod`) in the file to indicate the method used.
*   `Import-Secretsfile`:
    *   Reads an existing secrets file created by this module.
    *   Automatically detects the encryption method used (DPAPI or Portable/SharedKey) based on the stored hint.
    *   Decrypts the string values accordingly.
    *   Warns if importing a legacy file without a hint (assumes insecure Portable/SharedKey method).

### Private Functions

*   `Protect-String`: Encrypts a string using either DPAPI (no key) or AES with a hardcoded key, based on the `-ProtectionType` parameter (`DPAPI` or `SharedKey`).
*   `Unprotect-String`: Decrypts a string using either DPAPI (no key) or AES with a hardcoded key, based on the `-ProtectionType` parameter (`DPAPI` or `SharedKey`).
*   `Get-SecureInput`: Helper function for securely prompting for password input (masks input).

## File Structure

*   `PSSecretsAO.psd1`: Module manifest.
*   `PSSecretsAO.psm1`: Root module script (imports functions).
*   `Public/`: Contains functions exported for user use (`New-SecretsFile`, `Import-Secretsfile`).
*   `Private/`: Contains internal helper functions (`Protect-String`, `Unprotect-String`, `Get-SecureInput`).
*   `Tests/`: Contains tests for the module functions (structure suggests script-based tests).
*   `Examples/`: (Should contain example scripts like `UsemySecrets.ps1` showing how to use the module - currently external).

## Usage Example

See the example script `PSSecretsAO/Examples/UsemySecrets.ps1` (relative path assumed) for a demonstration.

## Testing

To run the tests for this module, use one of the following approaches:

### Running Specific Tests

For testing encryption methods specifically:

```powershell
# Run the encryption tests
.\Tests\Run-EncryptionTest.ps1 -Verbose
```

### Best Practices for Testing

When running tests:
1. Always run the test scripts from the module root directory
2. Use the provided wrapper scripts for testing specific functionality
3. Include `-Verbose` flag to get detailed output

### Troubleshooting Tests

If you encounter issues with the tests:
1. Make sure you're running from the root module directory
2. Ensure the module can be imported correctly
3. Check that required private functions are accessible

Some test failures are expected in specific environments:
- DPAPI encryption tests may fail when run in different user contexts
- Tests using system-specific encryption might fail in CI/CD pipelines

## Installation

Import the module directly using its manifest file:

```powershell
Import-Module .\PSSecretsAO\PSSecretsAO.psd1 -Force
```

Or place the `PSSecretsAO` folder in one of your `$env:PSModulePath` directories and import by name:

```powershell
Import-Module PSSecretsAO -Force
```

## Example Usage

```powershell
# Example: Create secrets using DPAPI (default, recommended)
$secureData = @{ ApiKey = "MyDPAPISecret"; Timeout = 60 }
New-SecretsFile -FilePath ".\config\secure-app-secrets.psd1" -Data $secureData
# $secrets = Import-Secretsfile -FilePath ".\config\secure-app-secrets.psd1" # This will work only for the same user/machine

# Example: Create secrets using Portable (less secure, shared key)
$portableData = @{ ApiKey = "MyPortableSecret"; Setting = "Value" }
New-SecretsFile -FilePath ".\config\portable-app-secrets.psd1" -Data $portableData -EncryptionMethod Portable
# $secrets = Import-Secretsfile -FilePath ".\config\portable-app-secrets.psd1" # This can be decrypted by anyone with the module code

# Example: Importing secrets (method is detected automatically)
$secrets1 = Import-Secretsfile -FilePath ".\config\secure-app-secrets.psd1"
$secrets2 = Import-Secretsfile -FilePath ".\config\portable-app-secrets.psd1"

Write-Host "DPAPI API Key: $($secrets1.ApiKey)"
Write-Host "Portable API Key: $($secrets2.ApiKey)"
``` 
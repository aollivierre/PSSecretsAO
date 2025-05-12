#Requires -Version 5.1
    $VerbosePreference = 'Continue'

[CmdletBinding()]
<#
.SYNOPSIS
A practical example demonstrating the PSSecretsAO module.
Creates/Imports an encrypted secrets file and uses the secrets.

.DESCRIPTION
This script shows how to use the PSSecretsAO module for basic secret management.
1. Defines a path for a secrets file specific to this application/script.
2. Imports the PSSecretsAO module.
3. Checks if the secrets file exists.
4. If the file exists, it imports the encrypted secrets using Import-Secretsfile.
5. If the file DOES NOT exist, it calls New-SecretsFile (interactively) to prompt
   the user for the necessary secrets (TenantID, ClientID, ClientSecret in this example)
   and creates the encrypted file.
6. Demonstrates accessing and using the retrieved secrets.
#>

# --- Configuration ---
# Define where the secrets file for this specific script/application will live.
# Using a subdirectory within the script's location is a good practice.
# $scriptRoot = Split-Path -Script $MyInvocation.MyCommand.Path # <- This requires PS 6+
$scriptRoot = $PSScriptRoot # <- Correct variable for PS 5.1+
$secretsDir = Join-Path -Path $scriptRoot -ChildPath ".app-secrets" # Hidden-like directory
# Use .psd1 extension for PowerShell Data File format
$secretsFilePath = Join-Path -Path $secretsDir -ChildPath "secrets.psd1" # Ensure this ends in .psd1

Write-Verbose "Script Root: $scriptRoot"
Write-Verbose "Secrets File Path: $secretsFilePath"

# Ensure the directory for secrets exists
if (-not (Test-Path -Path $secretsDir)) {
    Write-Verbose "Creating secrets directory: $secretsDir"
    try {
        New-Item -Path $secretsDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Fatal: Could not create secrets directory '$secretsDir'. Error: $($_.Exception.Message)"
        exit 1
    }
}

# Define the path to your PSSecretsAO module.
# Option 1: If installed in standard PSModulePath (like Documents\PowerShell\Modules)
$moduleName = "PSSecretsAO"
# Option 2: If located at a specific relative path from this script
# $relativeModulePath = "C:\Code\Modulesv2\PSSecretsAO\PSSecretsAO.psd1" # ADJUST THIS PATH IF NEEDED
$absoluteModulePath = "C:\Code\Modulesv2\PSSecretsAO\PSSecretsAO.psd1" 


# --- Import Module ---
Write-Verbose "Attempting to import PSSecretsAO module..."
try {
    if ($absoluteModulePath -and (Test-Path $absoluteModulePath)) {
        Import-Module $absoluteModulePath -Force -ErrorAction Stop
        Write-Verbose "Imported module from path: $absoluteModulePath"
    }
    elseif (Get-Module -ListAvailable -Name $moduleName) {
        Import-Module $moduleName -Force -ErrorAction Stop
        Write-Verbose "Imported module '$moduleName' from PSModulePath."
    }
    else {
        throw "Module '$moduleName' not found at '$absoluteModulePath' or in standard PowerShell module paths."
    }
    Write-Host "PSSecretsAO module loaded successfully." -ForegroundColor Green
}
catch {
    Write-Error "Fatal: Failed to import the PSSecretsAO module. Please ensure it's installed or the path is correct. Error: $($_.Exception.Message)"
    exit 1
}

# --- Load or Create Secrets ---
$secrets = $null

if (Test-Path -Path $secretsFilePath -PathType Leaf) {
    # Secrets file exists - Import it
    Write-Host "`nSecrets file found at '$secretsFilePath'. Importing..." -ForegroundColor Cyan
    try {
        # Import-Secretsfile decrypts the values
        $secrets = Import-Secretsfile -FilePath $secretsFilePath -ErrorAction Stop
        Write-Verbose "Secrets imported successfully."
    }
    catch {
        Write-Error "Failed to import existing secrets file '$secretsFilePath'. It might be corrupted or inaccessible. Error: $($_.Exception.Message)"
        # Consider recovery options here? For now, we exit.
        exit 1
    }
}
else {
    # Secrets file doesn't exist - Create it interactively
    Write-Host "`nSecrets file not found. We need to create it." -ForegroundColor Yellow
    Write-Host "You will be prompted for the required secrets." -ForegroundColor Yellow
    try {
         # Call New-SecretsFile WITHOUT the -Data parameter to trigger interactive prompts.
         # It creates the encrypted file AND returns the PLAINTEXT secrets for immediate use in this session.
         $secrets = New-SecretsFile -FilePath $secretsFilePath -ErrorAction Stop

         # Check if the function succeeded and returned the secrets
         if ($null -eq $secrets) {
             throw "New-SecretsFile did not return the expected secrets hashtable after creation."
         }
         Write-Host "New secrets file created and encrypted at '$secretsFilePath'." -ForegroundColor Green
         Write-Verbose "Initial secrets retrieved for current session."
    }
    catch {
         Write-Error "Failed to create new secrets file '$secretsFilePath'. Error: $($_.Exception.Message)"
         exit 1
    }
}

# --- Use the Secrets ---
if ($null -ne $secrets) {
    Write-Host "`nSecrets are loaded and ready to use." -ForegroundColor Green

    # Example: Access specific secrets (using keys from the interactive mode)
    $tenantId = $secrets.TenantID
    $clientId = $secrets.ClientID
    $clientSecretValue = $secrets.ClientSecret # This is the PLAIN TEXT secret

    if ($tenantId -and $clientId -and $clientSecretValue) {
        Write-Host "Successfully retrieved TenantID, ClientID, and ClientSecret."
        Write-Host "(Secret values are not displayed here for security, check Verbose output if needed)"
        Write-Verbose "TenantID: $tenantId"
        Write-Verbose "ClientID: $clientId"
        Write-Verbose "ClientSecret: $clientSecretValue" # Be careful with verbose output of secrets

        # --- PLACEHOLDER: Use the secrets ---
        Write-Host "`n--- Simulating API Call ---" -ForegroundColor Cyan
        Write-Host "Connecting to imaginary service using ClientID '$clientId'..."
        # Simulate using the secret securely
        # Connect-MyImaginaryService -Tenant $tenantId -ClientId $clientId -Secret $clientSecretValue
        Start-Sleep -Seconds 1
        Write-Host "Successfully authenticated (Simulated)." -ForegroundColor Green
        Write-Host "--------------------------" -ForegroundColor Cyan

    }
    else {
        Write-Warning "One or more expected secrets (TenantID, ClientID, ClientSecret) were not found in the loaded data."
        Write-Host "Available keys:"
        $secrets.Keys | ForEach-Object { Write-Host "- $_" }
    }
}
else {
    Write-Error "Failed to load or create secrets. Cannot proceed."
    exit 1
}

Write-Host "`nScript finished."


    # --- !!! DEBUGGING ONLY - REMOVE FOR PRODUCTION !!! ---
    if ($null -ne $secrets) {
        Write-Host "`n--- DECIPHERED SECRETS (DEBUG) ---" -ForegroundColor Red
        $secrets | Format-List # Or ConvertTo-Json or Out-String
        Write-Host "---------------------------------" -ForegroundColor Red
    }
    # --- !!! END DEBUGGING ONLY !!! ---
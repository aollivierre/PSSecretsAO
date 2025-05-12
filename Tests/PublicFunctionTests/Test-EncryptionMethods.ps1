#
# Test-EncryptionMethods.ps1
# Tests for encryption and decryption methods in PSSecretsAO
#
# IMPORTANT: This test should ideally be run using .\Tests\Run-EncryptionTest.ps1
# which ensures all required dependencies are available.
#

# Test script root to find helpers
$testScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
. "$testScriptRoot/../TestHelpers.ps1"
. "$testScriptRoot/../TestConfig.ps1"

# Import the module and necessary private functions
$moduleRoot = Split-Path -Path (Split-Path -Path $testScriptRoot -Parent) -Parent
Write-Verbose "Module root path: $moduleRoot"

# Ensure module is loaded
if (-not (Get-Module -Name PSSecretsAO)) {
    Write-Verbose "Importing module from $moduleRoot\PSSecretsAO.psd1"
    Import-Module -Name "$moduleRoot\PSSecretsAO.psd1" -Force
}

# Make private functions accessible for testing
Import-PrivateFunctionsForTesting -Verbose

$passCount = 0
$failCount = 0
$testEnvPath = $null
$testData = @{
    MethodTestKey    = "ValueToEncrypt-($([Guid]::NewGuid()))" # Unique value per run
    AnotherSecret    = "MoreData!@#$%^&" 
    NonString        = 9876
}

# Setup: Create a temporary environment
$testEnvPath = New-TestEnvironment
Write-Verbose "Test Environment for EncryptionMethods: $testEnvPath"

# Ensure required commands exist
Assert-NotNull -Actual (Get-Command New-SecretsFile -ErrorAction SilentlyContinue) -Message "Dependency New-SecretsFile must exist."
Assert-NotNull -Actual (Get-Command Import-Secretsfile -ErrorAction SilentlyContinue) -Message "Dependency Import-Secretsfile must exist."

# Create a function reference to make sure we have Protect-String
if (-not (Get-Command Protect-String -ErrorAction SilentlyContinue)) {
    $protectStringPath = Join-Path -Path $moduleRoot -ChildPath "Private\Protect-String.ps1"
    if (Test-Path -Path $protectStringPath) {
        . $protectStringPath
        Write-Verbose "Loaded private function Protect-String directly from: $protectStringPath"
    }
    else {
        Write-Error "Cannot find the required private function Protect-String.ps1 at $protectStringPath. Test will fail."
    }
}

# --- Test Case 1: DPAPI Encryption/Decryption --- 
$result = Invoke-Test -Name "New/Import should work with DPAPI (Default)" -TestScript {
    $dpapiFilePath = Join-Path -Path $testEnvPath -ChildPath "secrets_dpapi.psd1"
    $metadataKey = '_PSSecretsAO_EncryptionMethod'

    # 1a. Create with DPAPI (default)
    $returnedData = New-SecretsFile -FilePath $dpapiFilePath -Data $testData # EncryptionMethod defaults to DPAPI
    Assert-True -Condition (Test-Path -Path $dpapiFilePath) -Message "DPAPI: Secrets file should be created."
    Assert-Equal -Expected $testData.MethodTestKey -Actual $returnedData.MethodTestKey -Message "DPAPI: New-SecretsFile should return original data."

    # 1b. Verify Metadata Hint in raw file
    $rawContent = Get-Content -Path $dpapiFilePath -Raw
    Assert-True -Condition ($rawContent -match "'$metadataKey'\s*=\s*'DPAPI'") -Message "DPAPI: Raw file should contain '$metadataKey' = 'DPAPI' hint."
    
    # 1c. Import and Verify Decryption
    # NOTE: This step will only succeed if run by the same user on the same machine that created the file.
    try {
        $importedData = Import-Secretsfile -FilePath $dpapiFilePath -ErrorAction Stop
        
        Assert-NotNull -Actual $importedData -Message "DPAPI: Imported data should not be null."
        Assert-Equal -Expected $testData.MethodTestKey -Actual $importedData.MethodTestKey -Message "DPAPI: Decrypted MethodTestKey should match original."
        Assert-Equal -Expected $testData.AnotherSecret -Actual $importedData.AnotherSecret -Message "DPAPI: Decrypted AnotherSecret should match original."
        Assert-Equal -Expected $testData.NonString -Actual $importedData.NonString -Message "DPAPI: NonString value should be preserved."
    }
    catch {
        # Catch potential decryption failure if run in different context
        Write-Warning "DPAPI decryption failed. This is expected if the test runner user/machine differs from the encryption user/machine. Error: $($_.Exception.Message)"
        # Mark as inconclusive or pass with warning? For now, let Assert handle failure.
        throw $_ # Re-throw to fail the test explicitly if decryption fails under the same user.
    }
}
if ($result) { $passCount++ } else { $failCount++ }

# --- Test Case 2: Portable Encryption/Decryption --- 
$result = Invoke-Test -Name "New/Import should work with Portable (SharedKey)" -TestScript {
    $portableFilePath = Join-Path -Path $testEnvPath -ChildPath "secrets_portable.psd1"
    $metadataKey = '_PSSecretsAO_EncryptionMethod'

    # 2a. Create with Portable
    $returnedData = New-SecretsFile -FilePath $portableFilePath -Data $testData -EncryptionMethod Portable
    Assert-True -Condition (Test-Path -Path $portableFilePath) -Message "Portable: Secrets file should be created."
    Assert-Equal -Expected $testData.MethodTestKey -Actual $returnedData.MethodTestKey -Message "Portable: New-SecretsFile should return original data."

    # 2b. Verify Metadata Hint
    $rawContent = Get-Content -Path $portableFilePath -Raw
    Assert-True -Condition ($rawContent -match "'$metadataKey'\s*=\s*'Portable'") -Message "Portable: Raw file should contain '$metadataKey' = 'Portable' hint."

    # 2c. Import and Verify Decryption
    $importedData = Import-Secretsfile -FilePath $portableFilePath -ErrorAction Stop
    Assert-NotNull -Actual $importedData -Message "Portable: Imported data should not be null."
    Assert-Equal -Expected $testData.MethodTestKey -Actual $importedData.MethodTestKey -Message "Portable: Decrypted MethodTestKey should match original."
    Assert-Equal -Expected $testData.AnotherSecret -Actual $importedData.AnotherSecret -Message "Portable: Decrypted AnotherSecret should match original."
    Assert-Equal -Expected $testData.NonString -Actual $importedData.NonString -Message "Portable: NonString value should be preserved."
}
if ($result) { $passCount++ } else { $failCount++ }

# --- Test Case 3: Legacy File Import (No Hint) --- 
$result = Invoke-Test -Name "Import should handle legacy files (no hint, uses SharedKey)" -TestScript {
    $legacyFilePath = Join-Path -Path $testEnvPath -ChildPath "secrets_legacy.psd1"
    $legacyData = @{ LegacyKey = "LegacyValue-($([Guid]::NewGuid()))" }

    # 3a. Manually create legacy file content (using SharedKey protection directly, NO metadata hint)
    $encryptedLegacyKey = Protect-String -String $legacyData.LegacyKey -ProtectionType SharedKey
    $psd1Content = "@{{ 
    'LegacyKey' = '{0}'
 }}" -f ($encryptedLegacyKey -replace "'","''") # Basic PSD1 format
    Set-Content -Path $legacyFilePath -Value $psd1Content -Encoding UTF8
    Assert-True -Condition (Test-Path -Path $legacyFilePath) -Message "Legacy: Secrets file should be created."
    Assert-False -Condition (($psd1Content) -match "_PSSecretsAO_EncryptionMethod") -Message "Legacy: Raw file should NOT contain metadata hint."

    # 3b. Import and Verify Decryption (should default to SharedKey)
    # We might expect a Warning here, but testing for warnings is complex.
    $importedData = Import-Secretsfile -FilePath $legacyFilePath -ErrorAction Stop
    Assert-NotNull -Actual $importedData -Message "Legacy: Imported data should not be null."
    Assert-Equal -Expected $legacyData.LegacyKey -Actual $importedData.LegacyKey -Message "Legacy: Decrypted LegacyKey should match original (using SharedKey default)."
}
if ($result) { $passCount++ } else { $failCount++ }

# Cleanup: Remove the test environment
if ($null -ne $testEnvPath) {
    Remove-TestEnvironment -TestPath $testEnvPath
    Write-Verbose "Cleaned up test environment: $testEnvPath"
}

# Output summary for this file
Write-Host "`nTest File Summary ($($MyInvocation.MyCommand.Name)): $passCount passed, $failCount failed" -ForegroundColor Cyan 
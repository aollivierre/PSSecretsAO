<#
.SYNOPSIS
Tests for the public New-SecretsFile function.
#>

# Test script root to find helpers
$testScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
. "$testScriptRoot/../TestHelpers.ps1"

$passCount = 0
$failCount = 0
$testEnvPath = $null

# Setup: Create a temporary environment for test files
$testEnvPath = New-TestEnvironment
Write-Verbose "Test Environment for NewSecretsFile: $testEnvPath"

# Test case: Create a new secrets file with valid data
$result = Invoke-Test -Name "New-SecretsFile should create a file with valid data" -TestScript {
    $filePath = Join-Path -Path $testEnvPath -ChildPath "test_secrets_valid.json"
    $data = @{
        ApiKey    = "TestApiKey123"
        ApiSecret = "TestApiSecret456"
        IntValue  = 12345
    }

    # Ensure the function exists (module loaded by runner)
    Assert-NotNull -Actual (Get-Command New-SecretsFile -ErrorAction SilentlyContinue) -Message "New-SecretsFile command should exist."

    # Execute the function
    New-SecretsFile -FilePath $filePath -Data $data

    # Assertions
    Assert-True -Condition (Test-Path -Path $filePath) -Message "Secrets file should be created at $filePath."
    
    $content = Get-Content -Path $filePath -Raw | ConvertFrom-Json
    Assert-NotNull -Actual $content -Message "File content should be valid JSON."
    
    # Verify keys exist (values are encrypted)
    Assert-True -Condition ($content.PSObject.Properties.Name -contains 'ApiKey') -Message "JSON should contain ApiKey key."
    Assert-True -Condition ($content.PSObject.Properties.Name -contains 'ApiSecret') -Message "JSON should contain ApiSecret key."
    Assert-True -Condition ($content.PSObject.Properties.Name -contains 'IntValue') -Message "JSON should contain IntValue key."

    # Verify values are encrypted (not equal to original) for STRINGS ONLY
    Assert-NotEqual -Expected $data.ApiKey -Actual $content.ApiKey -Message "ApiKey value should be encrypted."
    Assert-NotEqual -Expected $data.ApiSecret -Actual $content.ApiSecret -Message "ApiSecret value should be encrypted."
    # Verify non-string value is preserved (equal to original)
    Assert-Equal -Expected $data.IntValue -Actual $content.IntValue -Message "IntValue value should be preserved as-is."
}

if ($result) { $passCount++ } else { $failCount++ }

# Test case: Handle empty data hashtable
$result = Invoke-Test -Name "New-SecretsFile should handle an empty data hashtable" -TestScript {
    $filePath = Join-Path -Path $testEnvPath -ChildPath "test_secrets_empty.json"
    $data = @{}

    New-SecretsFile -FilePath $filePath -Data $data

    Assert-True -Condition (Test-Path -Path $filePath) -Message "Empty secrets file should be created."
    $content = Get-Content -Path $filePath -Raw | ConvertFrom-Json
    Assert-NotNull -Actual $content -Message "File content should be valid JSON (NotNull)."
    Assert-Equal -Expected 0 -Actual ($content.PSObject.Properties | Measure-Object).Count -Message "JSON object should have no properties."
}

if ($result) { $passCount++ } else { $failCount++ }

# Test case: Null or empty FilePath should throw error
$result = Invoke-Test -Name "New-SecretsFile should throw an error for null or empty FilePath" -TestScript {
    $data = @{ Key = "Value" }
    Assert-Throws -ScriptBlock { New-SecretsFile -FilePath $null -Data $data } -Message "Should throw for null FilePath."
    Assert-Throws -ScriptBlock { New-SecretsFile -FilePath '' -Data $data } -Message "Should throw for empty FilePath."
}

if ($result) { $passCount++ } else { $failCount++ }

# Test case: Null data should throw error (or create empty? check function behavior)
# REMOVED: Function now handles null Data by falling back to interactive mode, not throwing.
# $result = Invoke-Test -Name "New-SecretsFile should throw an error for null Data" -TestScript {
#     $filePath = Join-Path -Path $testEnvPath -ChildPath "test_secrets_nulldata.json"
#     Assert-Throws -ScriptBlock { New-SecretsFile -FilePath $filePath -Data $null } -Message "Should throw for null Data parameter."
# }
# 
# if ($result) { $passCount++ } else { $failCount++ }

# Cleanup: Remove the test environment
if ($null -ne $testEnvPath) {
    Remove-TestEnvironment -TestPath $testEnvPath
    Write-Verbose "Cleaned up test environment: $testEnvPath"
}

# Output summary for this file
Write-Host "`nTest File Summary ($($MyInvocation.MyCommand.Name)): $passCount passed, $failCount failed" -ForegroundColor Cyan 
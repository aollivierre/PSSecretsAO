<#
.SYNOPSIS
Tests for the private Unprotect-String function.
Works in conjunction with Test-ProtectString.ps1.
#>

# Test script root to find helpers
$testScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
. "$testScriptRoot/../TestHelpers.ps1"

# Module Root and Path
$moduleRoot = Resolve-Path -Path "$testScriptRoot/../../"

$passCount = 0
$failCount = 0

# Helper to get private function scriptblocks
function Get-PrivateFunctionScriptBlock {
    param(
        [Parameter(Mandatory)]
        [string]$FunctionName, # Should match the base name of the .ps1 file
        [Parameter(Mandatory)]
        [string]$ModuleRootPath
    )
    $privateFuncFilePath = Join-Path -Path $ModuleRootPath -ChildPath "Private\$FunctionName.ps1"
    if (-not (Test-Path -Path $privateFuncFilePath)) {
         throw "Private function file '$privateFuncFilePath' not found for function '$FunctionName'."
    }
    $functionContent = Get-Content -Path $privateFuncFilePath -Raw
    try {
        return [ScriptBlock]::Create($functionContent)
    }
    catch {
        throw "Failed to create scriptblock from '$privateFuncFilePath'. Error: $($_.Exception.Message)"
    }
}

# Get and define the functions scriptblocks to test
$protectStringFuncScriptBlock = $null
$unprotectStringFuncScriptBlock = $null
try {
    # Get scriptblocks
    $protectStringFuncScriptBlock = Get-PrivateFunctionScriptBlock -FunctionName "Protect-String" -ModuleRootPath $moduleRoot
    $unprotectStringFuncScriptBlock = Get-PrivateFunctionScriptBlock -FunctionName "Unprotect-String" -ModuleRootPath $moduleRoot
    
    # Dot-source to define them in the current scope
    . $protectStringFuncScriptBlock
    . $unprotectStringFuncScriptBlock
    Write-Verbose "Defined Protect-String and Unprotect-String in test scope."
}
catch {
    Write-TestResult -Name "Setup: Access Protect/Unprotect private functions" -Result FAIL -ErrorMessage $_.Exception.Message
    return # Stop test execution
}

# Test case: Decrypt a valid protected string
$result = Invoke-Test -Name "Unprotect-String should decrypt a string protected by Protect-String" -TestScript {
    Assert-NotNull -Actual (Get-Command Protect-String -ErrorAction SilentlyContinue) -Message "Protect-String function must be defined."
    Assert-NotNull -Actual (Get-Command Unprotect-String -ErrorAction SilentlyContinue) -Message "Unprotect-String function must be defined."

    $originalString = "PasswordToTestEncryption123$%^"
    $protectedString = Protect-String -String $originalString
    Assert-NotNull -Actual $protectedString -Message "Protection must succeed first."

    $decryptedString = Unprotect-String -EncryptedString $protectedString

    Assert-Equal -Expected $originalString -Actual $decryptedString -Message "Decrypted string should match the original."
}

if ($result) { $passCount++ } else { $failCount++ }

# Test case: Handle the protected version of an empty string (should fail protection)
$result = Invoke-Test -Name "Unprotect-String test adjusted for empty string protection failure" -TestScript {
    Assert-NotNull -Actual (Get-Command Protect-String -ErrorAction SilentlyContinue) -Message "Protect-String function must be defined."
    Assert-NotNull -Actual (Get-Command Unprotect-String -ErrorAction SilentlyContinue) -Message "Unprotect-String function must be defined."

    # We now expect Protect-String to throw for an empty string
    Assert-Throws -ScriptBlock { Protect-String -String '' } -Message "Protecting an empty string should throw, so Unprotect cannot be tested with it."
    
    # Therefore, we don't proceed to call Unprotect-String with the (non-existent) result
}

if ($result) { $passCount++ } else { $failCount++ }

# Test case: Handle null input
$result = Invoke-Test -Name "Unprotect-String should throw for \$null input" -TestScript {
    Assert-NotNull -Actual (Get-Command Unprotect-String -ErrorAction SilentlyContinue) -Message "Unprotect-String function must be defined."

    # Function likely requires non-empty input
    Assert-Throws -ScriptBlock { Unprotect-String -EncryptedString $null } -Message "Should throw an error when unprotecting null."
    # Also test empty string
    Assert-Throws -ScriptBlock { Unprotect-String -EncryptedString '' } -Message "Should throw an error when unprotecting an empty string."
}

if ($result) { $passCount++ } else { $failCount++ }

# Test case: Handle invalid/corrupted input
$result = Invoke-Test -Name "Unprotect-String should handle invalid base64/corrupted input" -TestScript {
    Assert-NotNull -Actual (Get-Command Unprotect-String -ErrorAction SilentlyContinue) -Message "Unprotect-String function must be defined."

    $invalidString = "ThisIsNotValidBase64==="

    # Expecting it to either throw an error or return null/empty
    Assert-Throws -ScriptBlock {
        $decrypted = Unprotect-String -EncryptedString $invalidString
        # If it doesn't throw, check if output is null or empty
        if ($null -ne $decrypted -and $decrypted.Length -gt 0) {
            throw "Expected an error or null/empty output for invalid input, but got '$decrypted'."
        }
    } -Message "Should throw an error or handle invalid input without crashing."
    # If specific exception is expected (e.g., FormatException), add -ExpectedExceptionType
}

if ($result) { $passCount++ } else { $failCount++ }

# Output summary for this file
Write-Host "`nTest File Summary ($($MyInvocation.MyCommand.Name)): $passCount passed, $failCount failed" -ForegroundColor Cyan 
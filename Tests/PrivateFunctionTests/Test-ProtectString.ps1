<#
.SYNOPSIS
Tests for the private Protect-String function.
#>

# Test script root to find helpers
$testScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
. "$testScriptRoot/../TestHelpers.ps1"

# Module Root and Path
$moduleRoot = Resolve-Path -Path "$testScriptRoot/../../"

$passCount = 0
$failCount = 0

# Helper to get the private function's scriptblock
function Get-PrivateFunctionScriptBlock {
    param(
        [Parameter(Mandatory)]
        [string]$FunctionName, # Should match the base name of the .ps1 file
        [Parameter(Mandatory)]
        [string]$ModuleRootPath
    )

    # Construct the path to the specific private function file
    $privateFuncFilePath = Join-Path -Path $ModuleRootPath -ChildPath "Private\$FunctionName.ps1"
    if (-not (Test-Path -Path $privateFuncFilePath)) {
         throw "Private function file could not be found at '$privateFuncFilePath' for function '$FunctionName'."
    }

    # Read the content of the private function file
    $functionContent = Get-Content -Path $privateFuncFilePath -Raw

    # Create and return the scriptblock directly
    try {
        $scriptBlock = [ScriptBlock]::Create($functionContent)
        return $scriptBlock
    }
    catch {
        throw "Failed to create scriptblock from '$privateFuncFilePath'. Error: $($_.Exception.Message)"
    }
}

# Get the function scriptblock to test
$protectStringFuncScriptBlock = $null
try {
    $protectStringFuncScriptBlock = Get-PrivateFunctionScriptBlock -FunctionName "Protect-String" -ModuleRootPath $moduleRoot
    # Dot-source the scriptblock to define the function in the current scope for invocation
    . $protectStringFuncScriptBlock
}
catch {
    Write-TestResult -Name "Setup: Access Protect-String private function" -Result FAIL -ErrorMessage $_.Exception.Message
    # Stop execution of this test file if setup fails
    return
}

# Test case: Basic string protection
$result = Invoke-Test -Name "Protect-String should encrypt a non-empty string" -TestScript {
    Assert-NotNull -Actual (Get-Command Protect-String -ErrorAction SilentlyContinue) -Message "Protect-String function must be defined."
    $originalString = "MySecretPassword123!@#"
    # Invoke using the function name now defined in scope
    $protectedString = Protect-String -String $originalString

    Assert-NotNull -Actual $protectedString -Message "Protected string should not be null."
    Assert-NotEqual -Expected $originalString -Actual $protectedString -Message "Protected string should be different from the original."
    Assert-True -Condition ($protectedString.Length -gt 0) -Message "Protected string should have content."
    Assert-True -Condition ($protectedString -match '^[A-Za-z0-9+/=]+$') -Message "Protected string should appear Base64 encoded."
}

if ($result) { $passCount++ } else { $failCount++ }

# Test case: Protect empty string
$result = Invoke-Test -Name "Protect-String should throw for an empty string" -TestScript {
    Assert-NotNull -Actual (Get-Command Protect-String -ErrorAction SilentlyContinue) -Message "Protect-String function must be defined."
    Assert-Throws -ScriptBlock { Protect-String -String '' } -Message "Should throw an error when protecting an empty string."
    # Optionally check for specific exception type like [System.ArgumentException]
}

if ($result) { $passCount++ } else { $failCount++ }

# Test case: Protect null input
$result = Invoke-Test -Name "Protect-String should throw for \$null input" -TestScript {
    Assert-NotNull -Actual (Get-Command Protect-String -ErrorAction SilentlyContinue) -Message "Protect-String function must be defined."
    # Assuming the function (or underlying API) throws for null input.
    Assert-Throws -ScriptBlock { Protect-String -String $null } -Message "Should throw an error when protecting null."
    # Optionally check for specific exception type like [System.ArgumentNullException]
}

if ($result) { $passCount++ } else { $failCount++ }

# Output summary for this file
Write-Host "`nTest File Summary ($($MyInvocation.MyCommand.Name)): $passCount passed, $failCount failed" -ForegroundColor Cyan

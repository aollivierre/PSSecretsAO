<#
.SYNOPSIS
Tests if the PSSecretsAO module exports the expected public functions.
#>

# Test script root to find helpers
$testScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
. "$testScriptRoot/../TestHelpers.ps1"

$passCount = 0
$failCount = 0

# Expected public functions (Base names from Public directory)
$expectedExports = @(
    'Import-Secretsfile',
    'New-SecretsFile'
) | Sort-Object

# Test case: Verify Exported Functions
$result = Invoke-Test -Name "Module should export correct public functions" -TestScript {
    $moduleName = 'PSSecretsAO'
    $module = Get-Module -Name $moduleName -ErrorAction SilentlyContinue
    Assert-NotNull -Actual $module -Message "Module '$moduleName' should be loaded."

    # Get actual exported functions
    $actualExports = (Get-Command -Module $moduleName).Name | Sort-Object

    Assert-Equal -Expected $expectedExports -Actual $actualExports -Message "List of exported functions should match expected."
}

if ($result) { $passCount++ } else { $failCount++ }

# Output summary for this file
Write-Host "`nTest File Summary ($($MyInvocation.MyCommand.Name)): $passCount passed, $failCount failed" -ForegroundColor Cyan

# Store results for TestRunner (if TestRunner is adapted to collect them)
# $script:FileResults = @{ Passed = $passCount; Failed = $failCount } 
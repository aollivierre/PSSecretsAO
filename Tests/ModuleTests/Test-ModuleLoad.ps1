<#
.SYNOPSIS
Tests if the PSSecretsAO module loads correctly.
#>

#Requires -Modules @{ ModuleName = 'PSSecretsAO'; ModuleVersion = '1.0.0' } # Adjust version as needed

# Test script root to find helpers
$testScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
. "$testScriptRoot/../TestHelpers.ps1"

$passCount = 0
$failCount = 0

# Test case: Module Import
$result = Invoke-Test -Name "Module should import without errors" -TestScript {
    # The module should already be imported by TestRunner.ps1
    # We just check if it's present.
    $module = Get-Module -Name PSSecretsAO -ErrorAction SilentlyContinue
    Assert-NotNull -Actual $module -Message "PSSecretsAO module should be loaded."

    # Optional: Check specific properties if needed
    # Assert-Equal -Expected '1.1.0' -Actual $module.Version.ToString() -Message "Module version check"
}

if ($result) { $passCount++ } else { $failCount++ }

# Output summary for this file
Write-Host "`nTest File Summary ($($MyInvocation.MyCommand.Name)): $passCount passed, $failCount failed" -ForegroundColor Cyan

# Store results for TestRunner (if TestRunner is adapted to collect them)
# $script:FileResults = @{ Passed = $passCount; Failed = $failCount } 
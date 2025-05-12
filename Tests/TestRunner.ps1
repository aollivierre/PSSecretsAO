<#
.SYNOPSIS
Test runner script for the PSSecretsAO module.
Finds and executes all .ps1 test files within the Tests directory structure.

.PARAMETER PrivateOnly
Run only tests located in the PrivateFunctionTests directory.

.PARAMETER PublicOnly
Run only tests located in the PublicFunctionTests directory.

.PARAMETER ModuleOnly
Run only tests located in the ModuleTests directory.

.PARAMETER SpecificTest
Run only a specific test file (provide the base name without .ps1 extension).

.EXAMPLE
. ./Tests/TestRunner.ps1
# Runs all tests

.EXAMPLE
. ./Tests/TestRunner.ps1 -PublicOnly
# Runs only tests for public functions

.EXAMPLE
. ./Tests/TestRunner.ps1 -SpecificTest Test-NewSecretsFile
# Runs only the Test-NewSecretsFile.ps1 test
#>
param(
    [switch]$PrivateOnly,
    [switch]$PublicOnly,
    [switch]$ModuleOnly,
    [string]$SpecificTest
)

# Determine the script root dynamically
$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

# Import helper functions
. "$scriptRoot/TestHelpers.ps1"

# Find test files based on parameters
$testPaths = @()

Write-Verbose "Script Root: $scriptRoot"
Write-Verbose "Looking for tests..."

if ($SpecificTest) {
    # Try finding the specific test in any of the test subdirectories
    $foundTest = Get-ChildItem -Path "$scriptRoot/PrivateFunctionTests", "$scriptRoot/PublicFunctionTests", "$scriptRoot/ModuleTests" -Filter "$SpecificTest.ps1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($foundTest) {
        $testPaths += $foundTest.FullName
        Write-Verbose "Found specific test: $($foundTest.FullName)"
    }
    else {
        Write-Warning "Specific test file '$SpecificTest.ps1' not found in standard test directories."
        return
    }
}
else {
    # Build paths based on flags
    $searchPaths = @()
    if (-not $PublicOnly -and -not $ModuleOnly) {
        $searchPaths += "$scriptRoot/PrivateFunctionTests"
    }
    if (-not $PrivateOnly -and -not $ModuleOnly) {
        $searchPaths += "$scriptRoot/PublicFunctionTests"
    }
    if (-not $PrivateOnly -and -not $PublicOnly) {
        $searchPaths += "$scriptRoot/ModuleTests"
    }

    # Get test files from selected directories
    foreach ($searchPath in $searchPaths) {
        if (Test-Path -Path $searchPath) {
            $testPaths += Get-ChildItem -Path $searchPath -Filter "*.ps1" -File | Select-Object -ExpandProperty FullName
        }
    }
    Write-Verbose "Found $($testPaths.Count) test files based on flags."
}

# Check if any tests were found
if ($testPaths.Count -eq 0) {
    Write-Warning "No test files found to execute."
    return
}

# Initialize counters
$overallPassed = 0
$overallFailed = 0
$testResults = @{}

Write-Host "Starting test run... Module: PSSecretsAO" -ForegroundColor Cyan
Write-Host ("-" * 60) -ForegroundColor Cyan

# Import the module being tested - ensure it's found relative to the Tests directory
$moduleRoot = Resolve-Path -Path "$scriptRoot/.."
$moduleManifest = Join-Path -Path $moduleRoot -ChildPath "PSSecretsAO.psd1"

if (-not (Test-Path -Path $moduleManifest)) {
    Write-Error "Module manifest not found at '$moduleManifest'. Cannot run tests."
    return
}

Write-Verbose "Importing module from '$moduleManifest'"
Import-Module $moduleManifest -Force -ErrorAction Stop

# Run the tests
foreach ($testPath in $testPaths) {
    $testFile = Split-Path -Path $testPath -Leaf
    Write-Host "Executing Test File: $testFile" -ForegroundColor Yellow

    # Execute the test script file
    # Reset counters for each file; the file itself should report summary
    $filePassed = 0
    $fileFailed = 0
    $testResults[$testFile] = @{ Passed = 0; Failed = 0; Results = @() }

    # Using Invoke-Command to run in a clean scope, passing necessary items
    # Note: This adds complexity but isolates test runs better.
    # Simpler alternative: just run `$output = & $testPath` but risks scope pollution.
    # For now, keeping it simpler with direct execution.

    try {
        # Dot-source the test file to run it in the current scope
        # This allows tests to use helper functions and access module commands
        . $testPath

        # Logic to gather results would typically be inside the test file itself.
        # The test file should use Invoke-Test which calls Write-TestResult.
        # We need a way to aggregate results back here if TestRunner needs a summary.
        # Let's assume Test files output PASS/FAIL counts at the end for now.
        # A more robust way would be for Invoke-Test to return objects or update a global hash.

        # Placeholder: Assume test files output their own summary
        # We'll capture the output to parse later if needed, but for now rely on visual output.
    }
    catch {
        Write-Host "[ERROR] Failed to execute test file '$testFile': $($_.Exception.Message)" -ForegroundColor Red
        $overallFailed += 1 # Count the file itself as failed if it errors out catastrophically
    }
    Write-Host ("-" * 60) -ForegroundColor Cyan
}

# Final Summary (needs refinement based on how results are collected)
Write-Host "Test Run Summary (Overall - Based on Visual Output)" -ForegroundColor Cyan
# This summary is currently basic. A real implementation would require
# Invoke-Test to store results in a shared scope variable or return structured data.
# For now, instruct the user to review the output above.
Write-Host "Please review the [PASS]/[FAIL] messages above for detailed results." -ForegroundColor Yellow

# Clean up the imported module (optional)
# Remove-Module PSSecretsAO -Force -ErrorAction SilentlyContinue 
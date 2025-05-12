#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TestName = "*",
    
    [Parameter()]
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }

# Get module root
$moduleRoot = $PSScriptRoot
Write-Verbose "Module root: $moduleRoot"

# Import module
if (-not (Get-Module -Name PSSecretsAO -ErrorAction SilentlyContinue)) {
    $modulePath = Join-Path -Path $moduleRoot -ChildPath "PSSecretsAO.psd1"
    Write-Verbose "Importing module from: $modulePath"
    
    # Use scriptblock to pass parameters to the module script
    $importParams = @{
        Name = $modulePath
        Force = $true
        ArgumentList = @($true, $true)  # EnableDebug = $true, ForTesting = $true
    }
    
    if ($Verbose) {
        $importParams.Add('Verbose', $true)
    }
    
    Import-Module @importParams
}

# Check if module imported successfully
if (-not (Get-Module -Name PSSecretsAO)) {
    Write-Error "Failed to import PSSecretsAO module!"
    return
}

# Get available functions
$availableFunctions = Get-Command -Module PSSecretsAO | Select-Object -ExpandProperty Name
Write-Verbose "Available module functions: $($availableFunctions -join ', ')"

# Run specific test or all tests
$testPath = Join-Path -Path $moduleRoot -ChildPath "Tests\PublicFunctionTests"
if ($TestName -eq "*") {
    Write-Verbose "Running all tests in: $testPath"
    $testScripts = Get-ChildItem -Path $testPath -Filter "Test-*.ps1"
    foreach ($script in $testScripts) {
        Write-Host "Running test: $($script.Name)" -ForegroundColor Cyan
        & $script.FullName -Verbose:$Verbose
    }
}
else {
    $specificTest = Join-Path -Path $testPath -ChildPath "Test-$TestName.ps1"
    if (Test-Path -Path $specificTest) {
        Write-Verbose "Running specific test: $specificTest"
        & $specificTest -Verbose:$Verbose
    }
    else {
        Write-Error "Test not found: $specificTest"
    }
} 
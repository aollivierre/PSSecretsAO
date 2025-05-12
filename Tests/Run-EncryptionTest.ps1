#Requires -Version 5.1
[CmdletBinding()]
param()

$VerbosePreference = if ($PSBoundParameters['Verbose']) { 'Continue' } else { 'SilentlyContinue' }

# Resolve path to module
$moduleRoot = Split-Path -Path $PSScriptRoot -Parent
Write-Verbose "Module root: $moduleRoot"

# Import module if not already loaded
if (-not (Get-Module -Name PSSecretsAO)) {
    $modulePath = Join-Path -Path $moduleRoot -ChildPath "PSSecretsAO.psd1"
    Write-Verbose "Importing module from: $modulePath"
    
    $importParams = @{
        Name = $modulePath
        Force = $true
    }
    
    if ($PSBoundParameters.ContainsKey('Verbose')) {
        $importParams.Add('Verbose', $true)
    }
    
    Import-Module @importParams
}

# Make sure private functions are available to test
$protectStringPath = Join-Path -Path $moduleRoot -ChildPath "Private\Protect-String.ps1"
if (Test-Path -Path $protectStringPath) {
    . $protectStringPath
    Write-Verbose "Loaded private function: Protect-String"
}
else {
    Write-Error "Cannot find required file: $protectStringPath"
    return
}

# Run the encryption test
$testPath = Join-Path -Path $PSScriptRoot -ChildPath "PublicFunctionTests\Test-EncryptionMethods.ps1"
if (Test-Path -Path $testPath) {
    & $testPath -Verbose:($PSBoundParameters.ContainsKey('Verbose'))
}
else {
    Write-Error "Test script not found: $testPath"
} 
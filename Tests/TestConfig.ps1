# Configuration file for tests
# This script is sourced by the TestHelpers.ps1 to provide module-specific configuration

# Dot-source private functions that are needed for tests
function Import-PrivateFunctionsForTesting {
    [CmdletBinding()]
    param()

    $modulePath = Get-Module -Name PSSecretsAO -ListAvailable | Select-Object -First 1 -ExpandProperty Path
    if (-not $modulePath) {
        $moduleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent)
        $modulePath = Join-Path -Path $moduleRoot -ChildPath "PSSecretsAO.psd1"
        
        # Import module if not already imported
        if (-not (Get-Module -Name PSSecretsAO)) {
            Import-Module -Name $modulePath -Force
        }
    }
    
    # Get root folder containing all module files, not just the .psd1 file
    if ($modulePath -match '\.psd1$') {
        $moduleRoot = Split-Path -Path $modulePath -Parent
    } else {
        $moduleRoot = $modulePath
    }
    
    # Dot-source the private functions needed for tests
    $protectStringPath = Join-Path -Path $moduleRoot -ChildPath "Private\Protect-String.ps1"
    if (Test-Path -Path $protectStringPath) {
        Write-Verbose "Dot-sourcing private function from: $protectStringPath"
        . $protectStringPath
    }
    else {
        Write-Warning "Could not find Protect-String.ps1 at: $protectStringPath"
    }
} 
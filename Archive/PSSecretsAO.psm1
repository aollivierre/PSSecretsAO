# AutopilotModule.psm1

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Script-level variable to store module version
$script:Version = "1.1.0"

# Get the current path of the module
$PSModuleRoot = $PSScriptRoot

# Define paths to private and public functions
$PrivateFunctionsPath = Join-Path -Path $PSModuleRoot -ChildPath "Private"
$PublicFunctionsPath = Join-Path -Path $PSModuleRoot -ChildPath "Public"

# Helper function to load scripts from a given path
function Import-ModuleFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (Test-Path -Path $Path) {
        $files = Get-ChildItem -Path $Path -Filter "*.ps1" -Recurse
        
        # First, import all private functions
        foreach ($file in $files) {
            try {
                . $file.FullName
                Write-Verbose "Imported module file: $($file.FullName)"
            }
            catch {
                Write-Error "Failed to import module file $($file.FullName): $_"
            }
        }
    }
    else {
        Write-Warning "Path does not exist: $Path"
    }
}

# Load all private functions first (dependencies for public functions)
Import-ModuleFile -Path $PrivateFunctionsPath

# Load all public functions
Import-ModuleFile -Path $PublicFunctionsPath

# Define module-level variables and settings
$script:DefaultSecretsFilePath = Join-Path -Path $PSModuleRoot -ChildPath "secrets.psd1"

# Export variables that should be accessible to module users
Export-ModuleMember -Variable Version

# Export function that will handle the main functionality
# Export-ModuleMember -Function Register-DeviceWithPromptedCredentials

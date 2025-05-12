# DotNetFrameworkDiscovery.psm1
# Main module file that loads all functions and exports the public ones

# Get the directory where this script is located
# $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load all private functions
$privateFunctions = Get-ChildItem -Path "$PSScriptRoot\Private" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
foreach ($function in $privateFunctions) {
    . $function.FullName
}

# Load all public functions
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
foreach ($function in $publicFunctions) {
    . $function.FullName
}

# Export the public functions
$functionsToExport = $publicFunctions.BaseName

# Export all functions in a single call
Export-ModuleMember -Function $functionsToExport
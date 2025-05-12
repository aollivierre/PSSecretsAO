# Main module file that loads all functions and exports the public ones

# Simple debugging switch - defaults to false (disabled)
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$EnableDebug = $true,
    
    [Parameter()]
    [switch]$ForTesting = $false
)

# Internal function for debug messages
function Write-PSSecretsAODebug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message
    )
    
    if ($EnableDebug) {
        # Get caller information from call stack
        $callStack = Get-PSCallStack | Select-Object -Skip 1 -First 1
        $caller = if ($null -ne $callStack) {
            $command = $callStack.Command
            $scriptName = if ($callStack.ScriptName) {
                Split-Path -Leaf $callStack.ScriptName
            } else {
                "Unknown"
            }
            $lineNumber = $callStack.ScriptLineNumber
            
            "[$scriptName]:$lineNumber [$command]"
        } else {
            "[Unknown]"
        }
        
        Write-Host "[PSSecretsAO-Debug] $caller - $Message" -ForegroundColor Cyan
    }
}

# Load all private functions
$privateFunctions = Get-ChildItem -Path "$PSScriptRoot\Private" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
foreach ($function in $privateFunctions) {
    . $function.FullName
    Write-PSSecretsAODebug "Loaded private function: $($function.BaseName)"
}

# Load all public functions
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
foreach ($function in $publicFunctions) {
    . $function.FullName
    Write-PSSecretsAODebug "Loaded public function: $($function.BaseName)"
}

# Export the public functions
$functionsToExport = $publicFunctions.BaseName

# When running tests, also export Protect-String
if ($ForTesting) {
    Write-PSSecretsAODebug "Running in testing mode - exporting additional private functions for tests"
    $functionsToExport += "Protect-String"
}

Write-PSSecretsAODebug "Exporting functions: $($functionsToExport -join ', ')"

# Export all functions in a single call
Export-ModuleMember -Function $functionsToExport
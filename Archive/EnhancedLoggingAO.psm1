<#
.SYNOPSIS
    Script that initiates the module.

.DESCRIPTION
    This script dynamically loads functions from the Public and Private directories.
    Functions in the 'Public' directory are exported and available for external use.
    Functions in the 'Private' directory are intended for internal module use only.

.NOTES
    Author: Abdullah Ollivierre
    Contact:
    Website:
#>

[CmdletBinding()]
Param()

Process {
    # Retrieve function script files from Public and Private directories
    $publicDir = Join-Path -Path $PSScriptRoot -ChildPath "Public"
    $privateDir = Join-Path -Path $PSScriptRoot -ChildPath "Private"
    $PublicFunctions = @(Get-ChildItem -Path $publicDir -Filter "*.ps1" -ErrorAction SilentlyContinue)
    $PrivateFunctions = @(Get-ChildItem -Path $privateDir -Filter "*.ps1" -ErrorAction SilentlyContinue)

    # Verbose logging of function files found
    Write-EnhancedLog -Message "Public Functions found: $($PublicFunctions.Count)"
    Write-EnhancedLog -Message "Private Functions found: $($PrivateFunctions.Count)"

    # Inform if no function files are found to dot-source
    if ($PublicFunctions.Count -eq 0 -and $PrivateFunctions.Count -eq 0) {
        Write-EnhancedLog -Message "No function files found to dot-source in either Public or Private directories."
    }
    else {
        # Dot-source the function files
        foreach ($FunctionFile in @($PublicFunctions + $PrivateFunctions)) {
            try {
                Write-EnhancedLog -Message "Dot-sourcing: $($FunctionFile.FullName)" -Level INFO
                . $FunctionFile.FullName
            }
            catch {
                Write-Error "Failed to import function from $($FunctionFile.FullName) with error: $($_.Exception.Message)"
            }
        }
    }

    # Export functions defined in the Public directory
    $functionNamesToExport = $PublicFunctions | ForEach-Object { $_.BaseName }
    if ($functionNamesToExport) {
        Write-EnhancedLog -Message "Exporting public functions which you can call in your script: $($functionNamesToExport -join ', ')"
        Export-ModuleMember -Function $functionNamesToExport -Alias *
    }
    else {
        Write-EnhancedLog -Message "No public functions to export. Move functions to Public folder if you want them to be available and called in your scripts"
    }
}

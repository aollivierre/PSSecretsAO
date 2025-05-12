# Module loader script for DotNetFrameworkDiscovery

# Get the directory where this script is located
$ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import all the private functions
Get-ChildItem -Path "$ModuleRoot\Private\*.ps1" | ForEach-Object {
    . $_.FullName
}

# Import all the public functions
Get-ChildItem -Path "$ModuleRoot\Public\*.ps1" | ForEach-Object {
    . $_.FullName
}

# Export the public functions
Export-ModuleMember -Function @(
    'Get-InstalledDotNetFrameworks',
    'Get-DotNetFrameworkFeatures',
    'Test-DotNetFrameworkEOL',
    'Test-DotNetFrameworkDependency',
    'Get-DotNetFrameworkDependencies',
    'Export-DotNetDependencyGraph',
    'Test-DotNetFrameworkRemovable',
    'Test-DotNetCoreEOL'
)


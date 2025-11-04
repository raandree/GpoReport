# Module prefix - runs before loading functions
Write-Verbose 'Loading GpoReport module...'

# Initialize module variables
$script:ModuleRoot = $PSScriptRoot

# Add .NET types if needed
try {
    Add-Type -AssemblyName System.Web
}
catch {
    Write-Warning 'Could not load System.Web assembly. HTML encoding may not work properly.'
}

# Module initialization complete
Write-Verbose 'GpoReport module initialization complete.'

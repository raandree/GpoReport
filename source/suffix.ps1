# Module suffix - runs after loading functions

# Final module setup
Write-Verbose 'GpoReport module loaded successfully.'
Write-Verbose "Available functions: $($(Get-Command -Module GpoReport).Name -join ', ')"

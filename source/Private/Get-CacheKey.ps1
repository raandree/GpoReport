function Get-CacheKey {
    <#
    .SYNOPSIS
        Generates a cache key for the given parameters
        
    .DESCRIPTION
        Internal helper function to generate cache keys for search operations
        
    .PARAMETER Path
        The search path
        
    .PARAMETER SearchString
        The search string pattern
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$SearchString
    )
    
    try {
        # Create a unique key based on path and search string
        $combinedString = "$Path::$SearchString"
        $hash = [System.Security.Cryptography.SHA256]::Create()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($combinedString)
        $hashBytes = $hash.ComputeHash($bytes)
        $hashString = [BitConverter]::ToString($hashBytes) -replace '-', ''
        $hash.Dispose()
        
        return $hashString.Substring(0, 16)  # Use first 16 chars for shorter filenames
    }
    catch {
        Write-Warning "Failed to generate cache key: $($_.Exception.Message)"
        return [Guid]::NewGuid().ToString('N').Substring(0, 16)
    }
}

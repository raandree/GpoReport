function Get-CachedResults {
    <#
    .SYNOPSIS
        Retrieves cached search results
        
    .DESCRIPTION
        Internal helper function to retrieve cached search results if they exist and are valid
        
    .PARAMETER CacheKey
        The cache key to look up
        
    .PARAMETER CacheDirectory
        The cache directory path
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CacheKey,
        
        [Parameter(Mandatory = $true)]
        [string]$CacheDirectory
    )
    
    try {
        $cacheFile = Join-Path (Join-Path $CacheDirectory 'Results') "$CacheKey.json"
        
        if (Test-Path $cacheFile) {
            $cacheData = Get-Content $cacheFile -Raw | ConvertFrom-Json
            
            # Check if cache is still valid (less than 1 hour old)
            $cacheAge = (Get-Date) - [DateTime]$cacheData.Timestamp
            if ($cacheAge.TotalHours -lt 1) {
                Write-Verbose "Cache hit for key: $CacheKey"
                return $cacheData.Results
            }
            else {
                Write-Verbose "Cache expired for key: $CacheKey"
                Remove-Item $cacheFile -ErrorAction SilentlyContinue
            }
        }
        
        return $null
    }
    catch {
        Write-Warning "Failed to retrieve cached results: $($_.Exception.Message)"
        return $null
    }
}

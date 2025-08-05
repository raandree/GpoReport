function Set-CachedResults {
    <#
    .SYNOPSIS
        Stores search results in cache
        
    .DESCRIPTION
        Internal helper function to store search results in the cache
        
    .PARAMETER CacheKey
        The cache key to store under
        
    .PARAMETER Results
        The results to cache
        
    .PARAMETER CacheDirectory
        The cache directory path
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CacheKey,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results,
        
        [Parameter(Mandatory = $true)]
        [string]$CacheDirectory
    )
    
    try {
        $cacheFile = Join-Path (Join-Path $CacheDirectory "Results") "$CacheKey.json"
        
        $cacheData = @{
            Timestamp = Get-Date
            ResultCount = $Results.Count
            Results = $Results
        }
        
        $cacheData | ConvertTo-Json -Depth 10 | Out-File $cacheFile -Encoding UTF8
        Write-Verbose "Cached $($Results.Count) results with key: $CacheKey"
    }
    catch {
        Write-Warning "Failed to cache results: $($_.Exception.Message)"
    }
}

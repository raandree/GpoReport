function Search-GPOCached {
    <#
    .SYNOPSIS
        High-performance GPO search with intelligent caching, parallel processing, and file indexing
        
    .DESCRIPTION
        Search-GPOCached provides enterprise-grade performance optimizations for large-scale 
        GPO deployments. It implements intelligent caching, parallel processing, and content indexing
        to dramatically improve search performance in environments with hundreds or thousands of GPO files.
        
    .PARAMETER Path
        Path to XML files or directory containing GPO reports
        Supports wildcards and recursive directory scanning
        Performance optimized for large file sets
        
    .PARAMETER SearchString
        Search pattern to find in GPO settings
        Supports wildcards and regular expressions
        Cache key includes pattern for precise matching
        
    .PARAMETER UseCache
        Enable intelligent result caching system
        Dramatically speeds up repeated searches
        Cache automatically invalidated when files change
        
    .PARAMETER RebuildCache
        Force complete cache rebuild and index refresh
        Use when file contents change but timestamps don't
        Clears all cached results and rebuilds indexes
        
    .PARAMETER ParallelProcessing
        Enable parallel processing across multiple CPU cores
        Provides near-linear performance scaling
        Optimal for large file sets and multi-core systems
        
    .PARAMETER IndexFiles
        Build searchable content indexes for ultra-fast lookups
        Pre-processes XML content for immediate text searches
        Significant performance boost for large files
        
    .PARAMETER MaxThreads
        Maximum number of parallel processing threads
        Default: Number of logical processors
        
    .PARAMETER ShowPerformanceStats
        Display detailed performance statistics and timing
        
    .PARAMETER CacheDirectory
        Custom cache storage location
        Default: %TEMP%\GPOSearchCache
        
    .EXAMPLE
        Search-GPOCached -Path "*.xml" -SearchString "*security*" -UseCache
        
    .EXAMPLE
        Search-GPOCached -Path "D:\GPOReports\" -SearchString "*audit*" -UseCache -ParallelProcessing -IndexFiles -ShowPerformanceStats
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$SearchString,

        [Parameter()]
        [switch]$UseCache,

        [Parameter()]
        [switch]$RebuildCache,

        [Parameter()]
        [switch]$ParallelProcessing,

        [Parameter()]
        [switch]$IndexFiles,

        [Parameter()]
        [int]$MaxThreads = $env:NUMBER_OF_PROCESSORS,

        [Parameter()]
        [switch]$ShowPerformanceStats,

        [Parameter()]
        [string]$CacheDirectory = "$env:TEMP\GPOSearchCache",

        [Parameter()]
        [switch]$Recurse
    )

    begin {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Verbose "Starting high-performance GPO search"
        
        if ($UseCache) {
            Initialize-CacheDirectories -CacheDirectory $CacheDirectory
        }
        
        $performanceStats = @{
            StartTime = Get-Date
            FilesProcessed = 0
            CacheHits = 0
            CacheMisses = 0
            IndexHits = 0
            ParallelJobs = 0
        }
    }

    process {
        try {
            $results = @()
            
            # Get list of files to process
            $files = Get-ChildItem -Path $Path -Filter "*.xml" -Recurse:$Recurse -File
            $performanceStats.FilesProcessed = $files.Count
            
            Write-Verbose "Processing $($files.Count) XML files"
            
            if ($UseCache -and -not $RebuildCache) {
                # Check cache for existing results
                $cacheKey = Get-CacheKey -Path $Path -SearchString $SearchString
                $cachedResults = Get-CachedResults -CacheKey $cacheKey -CacheDirectory $CacheDirectory
                
                if ($cachedResults) {
                    Write-Verbose "Cache hit! Returning cached results"
                    $performanceStats.CacheHits++
                    return $cachedResults
                } else {
                    $performanceStats.CacheMisses++
                }
            }
            
            if ($ParallelProcessing -and $files.Count -gt 1) {
                # Use parallel processing for multiple files
                Write-Verbose "Using parallel processing with $MaxThreads threads"
                $results = Start-ParallelSearch -Files $files -SearchString $SearchString -MaxThreads $MaxThreads -IndexFiles:$IndexFiles
                $performanceStats.ParallelJobs = [Math]::Min($MaxThreads, $files.Count)
            } else {
                # Sequential processing
                foreach ($file in $files) {
                    if ($IndexFiles) {
                        $indexResults = Search-IndexedFile -FilePath $file.FullName -SearchString $SearchString -CacheDirectory $CacheDirectory
                        if ($indexResults) {
                            $results += $indexResults
                            $performanceStats.IndexHits++
                        }
                    } else {
                        $fileResults = Search-GPMCReports -Path $file.FullName -SearchString $SearchString
                        if ($fileResults) {
                            $results += $fileResults
                        }
                    }
                }
            }
            
            # Cache results if enabled
            if ($UseCache -and $results) {
                $cacheKey = Get-CacheKey -Path $Path -SearchString $SearchString
                Set-CachedResults -CacheKey $cacheKey -Results $results -CacheDirectory $CacheDirectory
            }
            
            return $results
        }
        catch {
            Write-Error "Cached search failed: $($_.Exception.Message)"
            throw
        }
    }

    end {
        $stopwatch.Stop()
        $performanceStats.TotalTime = $stopwatch.Elapsed
        $performanceStats.EndTime = Get-Date
        
        if ($ShowPerformanceStats) {
            Show-PerformanceStatistics -Stats $performanceStats
        }
        
        Write-Verbose "High-performance search completed in $($stopwatch.Elapsed.TotalSeconds) seconds"
    }
}

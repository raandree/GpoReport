function Initialize-CacheDirectories {
    <#
    .SYNOPSIS
        Initializes cache directories for GPO search caching
        
    .DESCRIPTION
        Internal helper function to create and initialize cache directories
        
    .PARAMETER CacheDirectory
        The base cache directory path
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CacheDirectory
    )
    
    try {
        if (-not (Test-Path $CacheDirectory)) {
            New-Item -Path $CacheDirectory -ItemType Directory -Force | Out-Null
            Write-Verbose "Created cache directory: $CacheDirectory"
        }
        
        $subDirs = @('Results', 'Indexes', 'Metadata')
        foreach ($subDir in $subDirs) {
            $path = Join-Path $CacheDirectory $subDir
            if (-not (Test-Path $path)) {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                Write-Verbose "Created cache subdirectory: $path"
            }
        }
    }
    catch {
        Write-Warning "Failed to initialize cache directories: $($_.Exception.Message)"
    }
}

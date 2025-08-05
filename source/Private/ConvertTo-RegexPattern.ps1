function ConvertTo-RegexPattern {
    <#
    .SYNOPSIS
        Converts wildcard pattern to regex pattern
        
    .DESCRIPTION
        Internal helper function to convert wildcard patterns (* and ?) to proper regex patterns
        
    .PARAMETER WildcardPattern
        The wildcard pattern to convert
        
    .PARAMETER CaseSensitive
        Whether the pattern should be case sensitive
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WildcardPattern,
        
        [Parameter()]
        [bool]$CaseSensitive = $false
    )
    
    # Escape special regex characters except * and ?
    $escaped = [regex]::Escape($WildcardPattern)
    
    # Convert wildcards to regex
    $pattern = $escaped -replace '\\\*', '.*' -replace '\\\?', '.'
    
    if (-not $CaseSensitive) {
        return "(?i)$pattern"
    }
    return $pattern
}

function Get-PerformanceAnalysis {
    <#
    .SYNOPSIS
        Performs performance analysis on GPO search results
        
    .DESCRIPTION
        Internal helper function to analyze search results for performance implications
        
    .PARAMETER Results
        The search results to analyze
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results
    )
    
    try {
        $performanceFindings = @()
        
        # Group results by GPO to analyze performance impact
        $gpoGroups = $Results | Group-Object GPOName
        
        foreach ($group in $gpoGroups) {
            $gpoName = $group.Name
            $settingCount = $group.Count
            
            # Analyze performance impact based on setting count and types
            $impact = 'Low'
            $recommendation = 'No performance concerns identified'
            
            if ($settingCount -gt 100) {
                $impact = 'High'
                $recommendation = 'Consider splitting large GPO into smaller, focused policies'
            }
            elseif ($settingCount -gt 50) {
                $impact = 'Medium'
                $recommendation = 'Monitor GPO processing time and consider optimization'
            }
            
            # Check for settings that may impact performance
            $heavySettings = $group.Group | Where-Object {
                $_.CategoryPath -match '(?i)(script|startup|logon)' -or
                $_.SettingName -match '(?i)(script|executable|program)'
            }
            
            if ($heavySettings.Count -gt 0) {
                $impact = 'Medium'
                $recommendation = "Review $($heavySettings.Count) script/executable settings for performance impact"
            }
            
            $finding = [PSCustomObject]@{
                GPOName                 = $gpoName
                SettingCount            = $settingCount
                PerformanceImpact       = $impact
                ProcessingCategory      = 'Policy Processing'
                Recommendation          = $recommendation
                OptimizationOpportunity = $settingCount -gt 25
                AnalysisDate            = Get-Date
            }
            
            $performanceFindings += $finding
        }
        
        return $performanceFindings
    }
    catch {
        Write-Error "Performance analysis failed: $($_.Exception.Message)"
        return @()
    }
}

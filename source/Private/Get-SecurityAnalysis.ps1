function Get-SecurityAnalysis {
    <#
    .SYNOPSIS
        Performs security analysis on GPO search results
        
    .DESCRIPTION
        Internal helper function to analyze search results for security implications
        
    .PARAMETER Results
        The search results to analyze
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results
    )
    
    try {
        $securityFindings = @()
        
        foreach ($result in $Results) {
            # Basic security pattern matching
            $riskLevel = 'Low'
            $recommendation = 'Review setting for compliance'
            
            # Check for high-risk patterns
            if ($result.SettingValue -match '(?i)(password|secret|key|credential)') {
                $riskLevel = 'High'
                $recommendation = 'Review password/credential settings for security compliance'
            }
            elseif ($result.SettingValue -match '(?i)(guest|anonymous|everyone)') {
                $riskLevel = 'Medium'
                $recommendation = 'Review guest/anonymous access settings'
            }
            elseif ($result.CategoryPath -match '(?i)(audit|log)') {
                $riskLevel = 'Medium'
                $recommendation = 'Ensure proper audit logging is configured'
            }
            
            $finding = [PSCustomObject]@{
                GPOName = $result.GPOName
                CategoryPath = $result.CategoryPath
                SettingName = $result.SettingName
                SettingValue = $result.SettingValue
                RiskLevel = $riskLevel
                SecurityDomain = 'Access Control'
                Recommendation = $recommendation
                AnalysisDate = Get-Date
            }
            
            $securityFindings += $finding
        }
        
        return $securityFindings
    }
    catch {
        Write-Error "Security analysis failed: $($_.Exception.Message)"
        return @()
    }
}

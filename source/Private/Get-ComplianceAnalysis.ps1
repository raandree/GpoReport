function Get-ComplianceAnalysis {
    <#
    .SYNOPSIS
        Performs compliance analysis on GPO search results
        
    .DESCRIPTION
        Internal helper function to analyze search results for compliance frameworks
        
    .PARAMETER Results
        The search results to analyze
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results
    )
    
    try {
        $complianceFindings = @()
        
        foreach ($result in $Results) {
            # Basic compliance framework mapping
            $frameworks = @()
            $complianceStatus = 'Unknown'
            
            # Map to common compliance frameworks
            if ($result.CategoryPath -match '(?i)(audit|log)') {
                $frameworks += 'SOX', 'HIPAA', 'PCI-DSS'
                $complianceStatus = 'Requires Review'
            }
            
            if ($result.SettingValue -match '(?i)(password|authentication)') {
                $frameworks += 'NIST', 'CIS', 'ISO 27001'
                $complianceStatus = 'Critical Review Required'
            }
            
            if ($result.CategoryPath -match '(?i)(security|access)') {
                $frameworks += 'CIS', 'NIST'
                $complianceStatus = 'Security Review Required'
            }
            
            if ($frameworks.Count -eq 0) {
                $frameworks += 'General'
                $complianceStatus = 'Standard Review'
            }
            
            $finding = [PSCustomObject]@{
                GPOName              = $result.GPOName
                CategoryPath         = $result.CategoryPath
                SettingName          = $result.SettingName
                SettingValue         = $result.SettingValue
                ComplianceFrameworks = ($frameworks -join ', ')
                ComplianceStatus     = $complianceStatus
                RequiredAction       = 'Review against compliance requirements'
                AnalysisDate         = Get-Date
            }
            
            $complianceFindings += $finding
        }
        
        return $complianceFindings
    }
    catch {
        Write-Error "Compliance analysis failed: $($_.Exception.Message)"
        return @()
    }
}

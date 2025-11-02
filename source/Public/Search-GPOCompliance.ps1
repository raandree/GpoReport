function Search-GPOCompliance {
    <#
    .SYNOPSIS
        Advanced GPO compliance and security analysis with pre-built security patterns
        
    .DESCRIPTION
        Search-GPOCompliance provides security-focused GPO analysis using pre-built compliance 
        templates and risk assessment frameworks. This function goes beyond basic searching to provide
        intelligent security analysis mapped to industry compliance frameworks.
        
    .PARAMETER Path
        Path to XML files or directory containing GPO reports
        Supports wildcards and recursive directory scanning
        
    .PARAMETER ComplianceTemplate
        Pre-built compliance template to use for analysis:
        • CIS - Center for Internet Security benchmarks
        • NIST - NIST Cybersecurity Framework patterns
        • SOX - Sarbanes-Oxley financial compliance
        • HIPAA - Healthcare data protection requirements
        • Custom - Load custom patterns from file
        
    .PARAMETER SecurityLevel
        Security analysis focus level:
        • Basic - General security settings only
        • Standard - Common security configurations
        • High - Advanced security and audit settings
        • Critical - High-risk settings requiring immediate attention
        
    .PARAMETER RiskAssessment
        Enable comprehensive risk assessment scoring
        
    .EXAMPLE
        Search-GPOCompliance -Path "*.xml" -ComplianceTemplate CIS -SecurityLevel High
        
    .EXAMPLE
        Search-GPOCompliance -Path "." -ComplianceTemplate NIST -RiskAssessment
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [ValidateSet('CIS', 'NIST', 'SOX', 'HIPAA', 'Custom')]
        [string]$ComplianceTemplate = 'CIS',

        [Parameter()]
        [ValidateSet('Basic', 'Standard', 'High', 'Critical')]
        [string]$SecurityLevel = 'Standard',

        [Parameter()]
        [switch]$RiskAssessment,

        [Parameter()]
        [string]$CustomPatternFile,

        [Parameter()]
        [switch]$Recurse
    )

    begin {
        Write-Verbose "Starting compliance analysis with template: $ComplianceTemplate, Security Level: $SecurityLevel"
        $compliancePatterns = Get-CompliancePatterns -Template $ComplianceTemplate -SecurityLevel $SecurityLevel -CustomFile $CustomPatternFile
    }

    process {
        try {
            $results = @()
            
            foreach ($pattern in $compliancePatterns) {
                Write-Verbose "Searching for compliance pattern: $($pattern.Name)"
                
                $searchResults = Search-GPMCReports -Path $Path -SearchString $pattern.SearchString -Recurse:$Recurse
                
                foreach ($result in $searchResults) {
                    # Enhance result with compliance information
                    $enhancedResult = $result | Select-Object *, ComplianceFramework, RiskLevel, ComplianceRule, Recommendation
                    $enhancedResult.ComplianceFramework = $ComplianceTemplate
                    $enhancedResult.RiskLevel = $pattern.RiskLevel
                    $enhancedResult.ComplianceRule = $pattern.Name
                    $enhancedResult.Recommendation = $pattern.Recommendation
                    
                    if ($RiskAssessment) {
                        $enhancedResult | Add-Member -NotePropertyName 'RiskScore' -NotePropertyValue (Get-RiskScore -Result $enhancedResult)
                        $enhancedResult | Add-Member -NotePropertyName 'ComplianceStatus' -NotePropertyValue (Get-ComplianceStatus -Result $enhancedResult -Template $ComplianceTemplate)
                    }
                    
                    $results += $enhancedResult
                }
            }
            
            return $results
        }
        catch {
            Write-Error "Compliance search failed: $($_.Exception.Message)"
            throw
        }
    }
}

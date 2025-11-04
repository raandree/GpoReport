function Get-GPOInsights {
    <#
    .SYNOPSIS
        AI-powered analysis engine providing intelligent security, compliance, and operational insights
        
    .DESCRIPTION
        Get-GPOInsights provides advanced analysis of GPO search results, transforming raw data into
        actionable intelligence. It uses pattern recognition, risk assessment algorithms, and compliance
        mapping to provide comprehensive insights that would typically require expert manual analysis.
        
    .PARAMETER Results
        Array of GPO search results from Search-GPMCReports or related functions
        Can accept piped input for seamless integration
        
    .PARAMETER AnalysisType
        Type of intelligent analysis to perform:
        • Security - Focus on security risks, vulnerabilities, and hardening opportunities
        • Compliance - Framework-specific compliance assessment and gap analysis
        • Performance - Configuration optimization and performance recommendations
        • Conflicts - Cross-GPO setting contradiction detection and resolution
        • All - Comprehensive analysis combining all analysis types
        
    .PARAMETER GenerateReport
        Generate comprehensive HTML analysis report with visual charts and recommendations
        
    .PARAMETER OutputPath
        Path for generated reports (optional)
        
    .EXAMPLE
        $results = Search-GPMCReports -Path "*.xml" -SearchString "*security*"
        Get-GPOInsights -Results $results -AnalysisType Security
        
    .EXAMPLE
        Search-GPMCReports -Path "." -SearchString "*audit*" | Get-GPOInsights -AnalysisType All -GenerateReport -OutputPath "security-analysis"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject[]]$Results,

        [Parameter()]
        [ValidateSet('Security', 'Compliance', 'Performance', 'Conflicts', 'All')]
        [string]$AnalysisType = 'All',

        [Parameter()]
        [switch]$GenerateReport,

        [Parameter()]
        [string]$OutputPath
    )

    begin {
        Write-Verbose "Starting GPO insights analysis: $AnalysisType"
        $allResults = @()
        $analysisResults = @{
            Security    = @()
            Compliance  = @()
            Performance = @()
            Conflicts   = @()
            Summary     = @{}
        }
    }

    process {
        $allResults += $Results
    }

    end {
        if ($allResults.Count -eq 0) {
            Write-Warning 'No results to analyze'
            return
        }

        Write-Verbose "Analyzing $($allResults.Count) GPO settings"

        try {
            # Perform requested analysis
            if ($AnalysisType -in @('Security', 'All')) {
                Write-Verbose 'Performing security analysis...'
                $analysisResults.Security = Get-SecurityAnalysis -Results $allResults
            }

            if ($AnalysisType -in @('Compliance', 'All')) {
                Write-Verbose 'Performing compliance analysis...'
                $analysisResults.Compliance = Get-ComplianceAnalysis -Results $allResults
            }

            if ($AnalysisType -in @('Performance', 'All')) {
                Write-Verbose 'Performing performance analysis...'
                $analysisResults.Performance = Get-PerformanceAnalysis -Results $allResults
            }

            if ($AnalysisType -in @('Conflicts', 'All')) {
                Write-Verbose 'Performing conflict analysis...'
                $analysisResults.Conflicts = Get-ConflictAnalysis -Results $allResults
            }

            # Generate summary
            $analysisResults.Summary = @{
                TotalSettings     = $allResults.Count
                SecurityIssues    = $analysisResults.Security.Count
                ComplianceIssues  = $analysisResults.Compliance.Count
                PerformanceIssues = $analysisResults.Performance.Count
                Conflicts         = $analysisResults.Conflicts.Count
                AnalysisDate      = Get-Date
            }

            # Generate report if requested
            if ($GenerateReport) {
                if (-not $OutputPath) {
                    $OutputPath = "GPO-Insights-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                }
                
                Write-Verbose 'Generating analysis report...'
                New-AnalysisReport -AnalysisResults $analysisResults -OutputPath $OutputPath
            }

            return $analysisResults
        }
        catch {
            Write-Error "Analysis failed: $($_.Exception.Message)"
            throw
        }
    }
}

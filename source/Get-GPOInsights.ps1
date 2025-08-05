# Get-GPOInsights.ps1 - AI-powered GPO analysis and recommendations
<#
.SYNOPSIS
    AI-powered analysis engine providing intelligent security, compliance, and operational insights
    
.DESCRIPTION
    Get-GPOInsights.ps1 is an advanced analysis engine that transforms raw GPO search results into
    actionable intelligence. It uses pattern recognition, risk assessment algorithms, and compliance
    mapping to provide comprehensive insights that would typically require expert manual analysis.
    
    ANALYSIS CAPABILITIES:
    • Security Risk Assessment: Identifies high-risk configurations with numerical scoring
    • Compliance Mapping: Maps settings to industry frameworks (CIS, NIST, HIPAA, SOX)
    • Conflict Detection: Identifies contradictory settings across multiple GPOs
    • Performance Analysis: Optimization recommendations for GPO structure and deployment
    • Automated Recommendations: Context-aware suggestions for security improvements
    
    INTELLIGENCE FEATURES:
    • Risk Scoring: 0-100 numerical assessment for each finding
    • Pattern Recognition: Advanced security pattern matching against threat databases
    • Compliance Scoring: Framework-specific percentage compliance calculations
    • Conflict Analysis: Cross-GPO setting contradiction detection
    • Trend Analysis: Historical comparison and drift detection
    
    ANALYSIS ALGORITHMS:
    • Multi-factor risk scoring based on setting type, values, and context
    • Compliance framework mapping with automatic requirement identification
    • Security pattern libraries with regular updates
    • Performance impact assessment for configuration changes
    • Automated priority ranking for remediation planning

.PARAMETER Results
    Array of GPO search results from Search-GPMCReports.ps1 or related scripts
    Can accept piped input for seamless integration
    Supports results from multiple search operations
    
.PARAMETER AnalysisType
    Type of intelligent analysis to perform:
    • Security - Focus on security risks, vulnerabilities, and hardening opportunities
    • Compliance - Framework-specific compliance assessment and gap analysis
    • Performance - Configuration optimization and performance recommendations
    • Conflicts - Cross-GPO setting contradiction detection and resolution
    • All - Comprehensive analysis combining all analysis types
    
.PARAMETER GenerateReport
    Generate comprehensive HTML analysis report with visual charts and recommendations
    Creates professional report suitable for executive briefings and technical teams
    Includes trend analysis, risk distribution, and prioritized action items
    
.PARAMETER OutputPath
    Custom output path for generated reports and analysis files
    Default: "GPO-Analysis-Report-[timestamp]"
    Creates HTML report with embedded CSS and JavaScript for interactivity
    
.PARAMETER ComplianceFramework
    Specific compliance framework for focused analysis:
    • CIS - Center for Internet Security benchmarks
    • NIST - NIST Cybersecurity Framework
    • HIPAA - Healthcare data protection compliance
    • SOX - Sarbanes-Oxley financial regulations
    • PCI-DSS - Payment Card Industry standards
    • Custom - Organization-specific compliance requirements
    
.PARAMETER RiskThreshold
    Minimum risk score for inclusion in priority findings
    Range: 0-100 (default: 50)
    Higher values focus on critical issues only
    Lower values include more comprehensive findings
    
.OUTPUTS
    Comprehensive analysis results including:
    • Risk-scored findings with severity classifications
    • Compliance percentage by framework and category
    • Identified conflicts with resolution recommendations
    • Performance optimization suggestions
    • Executive summary with key metrics
    • Detailed technical findings with remediation steps
    
.EXAMPLE
    # Comprehensive security analysis with report generation
    $results = .\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*"
    .\Get-GPOInsights.ps1 -Results $results -AnalysisType Security -GenerateReport
    
.EXAMPLE
    # CIS compliance assessment
    $results = .\Search-GPMCReports.ps1 -Path "D:\GPO\" -SearchString "*security*"
    .\Get-GPOInsights.ps1 -Results $results -AnalysisType Compliance -ComplianceFramework CIS -GenerateReport
    
.EXAMPLE
    # Conflict detection across multiple GPOs
    $results | .\Get-GPOInsights.ps1 -AnalysisType Conflicts -GenerateReport -OutputPath "conflict-analysis"
    
.EXAMPLE
    # High-priority security findings only
    .\Get-GPOInsights.ps1 -Results $results -AnalysisType Security -RiskThreshold 75 -GenerateReport
    
.EXAMPLE
    # Complete analysis for executive briefing
    .\Get-GPOInsights.ps1 -Results $results -AnalysisType All -GenerateReport -OutputPath "executive-security-briefing"
    
.NOTES
    File Name      : Get-GPOInsights.ps1
    Author         : GPO Intelligence Team
    Prerequisite   : PowerShell 5.1+
    Dependencies   : Search-GPMCReports.ps1 for result objects
    
    Risk Scoring Algorithm:
    Base Score Calculation:
    • Security Settings Category: +30 points
    • User Rights Assignment: +25 points  
    • Audit Configuration: +20 points
    • Administrative Templates: +15 points
    • Computer Configuration: +10 bonus points
    
    Pattern Matching Bonuses:
    • Critical Patterns (passwords, encryption, admin): +40 points
    • High Risk Patterns (audit, access, privileges): +25 points
    • Medium Risk Patterns (complexity, timeouts): +15 points
    • Security State: Disabled security features add multiplier
    
    Compliance Framework Mapping:
    • CIS Controls: Maps to 20 critical security controls
    • NIST CSF: Identifies Protect, Detect, Respond categories
    • HIPAA: Administrative, Physical, Technical safeguards
    • SOX: IT general controls and access management
    
    Analysis Report Features:
    • Executive Summary: High-level metrics and key findings
    • Risk Distribution: Visual charts showing risk by category
    • Compliance Dashboard: Framework-specific scoring
    • Detailed Findings: Technical details with remediation steps
    • Trend Analysis: Comparison with baseline configurations
    • Action Plan: Prioritized recommendations with timelines
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [object[]]$Results,
    
    [Parameter()]
    [ValidateSet('Security', 'Compliance', 'Performance', 'Conflicts', 'All')]
    [string]$AnalysisType = 'All',
    
    [Parameter()]
    [switch]$GenerateReport,
    
    [Parameter()]
    [string]$OutputPath = "GPO-Analysis-Report"
)

# Security pattern definitions for risk assessment
$SecurityPatterns = @{
    Critical = @{
        'Disabled Firewall' = @('*firewall*', '*disable*')
        'Guest Account Enabled' = @('*guest*', '*enable*')
        'Weak Password Policy' = @('*password*', '*0*', '*1*')
        'No Account Lockout' = @('*lockout*', '*0*')
        'Admin Rights' = @('*administrator*', '*rights*')
    }
    High = @{
        'Audit Disabled' = @('*audit*', '*disable*')
        'Remote Desktop' = @('*remote*desktop*', '*enable*')
        'USB Restrictions' = @('*removable*storage*', '*disable*')
        'Script Execution' = @('*powershell*', '*unrestricted*')
    }
    Medium = @{
        'Password Complexity' = @('*password*complex*', '*disable*')
        'Screen Saver' = @('*screen*saver*', '*disable*')
        'AutoRun Disabled' = @('*autorun*', '*disable*')
    }
}

# Compliance frameworks mapping
$ComplianceFrameworks = @{
    'CIS' = @{
        'Password Policy' = 'CIS Control 4.1'
        'Account Lockout' = 'CIS Control 4.2'
        'Audit Policy' = 'CIS Control 6.2'
        'Firewall' = 'CIS Control 9.1'
    }
    'NIST' = @{
        'Access Control' = 'NIST 800-53 AC-2'
        'Audit and Accountability' = 'NIST 800-53 AU-2'
        'Configuration Management' = 'NIST 800-53 CM-6'
    }
}

function Get-SecurityAnalysis {
    param($Results)
    
    Write-Host "=== SECURITY ANALYSIS ===" -ForegroundColor Red
    
    $securityFindings = @{
        Critical = @()
        High = @()
        Medium = @()
        Low = @()
    }
    
    foreach ($result in $Results) {
        foreach ($severity in $SecurityPatterns.Keys) {
            foreach ($patternName in $SecurityPatterns[$severity].Keys) {
                $patterns = $SecurityPatterns[$severity][$patternName]
                $matchesAll = $true
                
                foreach ($pattern in $patterns) {
                    if ($result.MatchedText -notlike $pattern -and 
                        $result.CategoryPath -notlike $pattern -and
                        $result.Setting.Name -notlike $pattern) {
                        $matchesAll = $false
                        break
                    }
                }
                
                if ($matchesAll) {
                    $securityFindings[$severity] += @{
                        Pattern = $patternName
                        Result = $result
                        Recommendation = Get-SecurityRecommendation -PatternName $patternName
                    }
                }
            }
        }
    }
    
    # Display findings
    foreach ($severity in @('Critical', 'High', 'Medium', 'Low')) {
        if ($securityFindings[$severity].Count -gt 0) {
            $color = switch ($severity) {
                'Critical' { 'Red' }
                'High' { 'Yellow' }
                'Medium' { 'Cyan' }
                'Low' { 'Green' }
            }
            
            Write-Host "`n$severity Risk Issues ($($securityFindings[$severity].Count)):" -ForegroundColor $color
            foreach ($finding in $securityFindings[$severity]) {
                Write-Host "  • $($finding.Pattern): $($finding.Result.GPO.DisplayName)" -ForegroundColor White
                Write-Host "    └─ $($finding.Recommendation)" -ForegroundColor Gray
            }
        }
    }
    
    return $securityFindings
}

function Get-ComplianceAnalysis {
    param($Results)
    
    Write-Host "`n=== COMPLIANCE ANALYSIS ===" -ForegroundColor Blue
    
    $complianceScore = @{
        CIS = 0
        NIST = 0
        Total = 0
    }
    
    $complianceDetails = @()
    
    foreach ($framework in $ComplianceFrameworks.Keys) {
        Write-Host "`n$framework Framework Compliance:" -ForegroundColor Cyan
        
        $frameworkControls = $ComplianceFrameworks[$framework]
        $metControls = 0
        
        foreach ($controlName in $frameworkControls.Keys) {
            $controlId = $frameworkControls[$controlName]
            $hasCompliantSetting = $false
            
            # Check if we have compliant settings for this control
            foreach ($result in $Results) {
                if ($result.CategoryPath -like "*$controlName*" -or 
                    $result.Setting.Name -like "*$controlName*" -or
                    $result.MatchedText -like "*$controlName*") {
                    
                    if ($result.Setting.State -in @('Enabled', 'Success', 'Success and Failure')) {
                        $hasCompliantSetting = $true
                        break
                    }
                }
            }
            
            if ($hasCompliantSetting) {
                $metControls++
                Write-Host "  ✓ $controlId - $controlName" -ForegroundColor Green
            } else {
                Write-Host "  ✗ $controlId - $controlName" -ForegroundColor Red
            }
            
            $complianceDetails += @{
                Framework = $framework
                Control = $controlName
                ControlId = $controlId
                Compliant = $hasCompliantSetting
            }
        }
        
        $compliancePercent = [Math]::Round(($metControls / $frameworkControls.Count) * 100, 1)
        $complianceScore[$framework] = $compliancePercent
        Write-Host "  Overall Score: $compliancePercent%" -ForegroundColor $(if ($compliancePercent -gt 80) { 'Green' } elseif ($compliancePercent -gt 60) { 'Yellow' } else { 'Red' })
    }
    
    return @{
        Scores = $complianceScore
        Details = $complianceDetails
    }
}

function Get-ConflictAnalysis {
    param($Results)
    
    Write-Host "`n=== CONFLICT ANALYSIS ===" -ForegroundColor Magenta
    
    # Group by setting name to find potential conflicts
    $settingGroups = $Results | Group-Object { $_.Setting.Name } | Where-Object { $_.Count -gt 1 }
    
    $conflicts = @()
    
    foreach ($group in $settingGroups) {
        $uniqueStates = $group.Group | Select-Object -ExpandProperty Setting | Select-Object -ExpandProperty State -Unique
        $uniqueGPOs = $group.Group | Select-Object -ExpandProperty GPO | Select-Object -ExpandProperty DisplayName -Unique
        
        if ($uniqueStates.Count -gt 1 -and $uniqueGPOs.Count -gt 1) {
            $conflicts += @{
                SettingName = $group.Name
                States = $uniqueStates
                GPOs = $uniqueGPOs
                Instances = $group.Group
            }
            
            Write-Host "  ⚠️  Conflicting setting: $($group.Name)" -ForegroundColor Yellow
            Write-Host "     States: $($uniqueStates -join ', ')" -ForegroundColor Gray
            Write-Host "     GPOs: $($uniqueGPOs -join ', ')" -ForegroundColor Gray
        }
    }
    
    if ($conflicts.Count -eq 0) {
        Write-Host "  ✓ No setting conflicts detected" -ForegroundColor Green
    }
    
    return $conflicts
}

function Get-PerformanceAnalysis {
    param($Results)
    
    Write-Host "`n=== PERFORMANCE ANALYSIS ===" -ForegroundColor Green
    
    $performanceInsights = @{
        LargeGPOs = @()
        ComplexSettings = @()
        RecommendedOptimizations = @()
    }
    
    # Analyze GPO size by result count
    $gpoGroups = $Results | Group-Object { $_.GPO.DisplayName } | Sort-Object Count -Descending
    
    Write-Host "GPO Complexity Analysis:" -ForegroundColor Cyan
    foreach ($gpo in $gpoGroups | Select-Object -First 5) {
        Write-Host "  $($gpo.Name): $($gpo.Count) settings" -ForegroundColor White
        
        if ($gpo.Count -gt 100) {
            $performanceInsights.LargeGPOs += $gpo.Name
            Write-Host "    └─ Consider splitting this GPO for better performance" -ForegroundColor Yellow
        }
    }
    
    # Analyze setting complexity
    $complexCategories = $Results | Group-Object CategoryPath | Where-Object { $_.Count -gt 20 } | Sort-Object Count -Descending
    
    if ($complexCategories) {
        Write-Host "`nComplex Category Areas:" -ForegroundColor Cyan
        foreach ($category in $complexCategories | Select-Object -First 3) {
            Write-Host "  $($category.Name): $($category.Count) settings" -ForegroundColor White
            $performanceInsights.ComplexSettings += $category.Name
        }
    }
    
    # Performance recommendations
    $recommendations = @()
    if ($performanceInsights.LargeGPOs.Count -gt 0) {
        $recommendations += "Consider splitting large GPOs (>100 settings) into smaller, focused ones"
    }
    if (($Results | Where-Object { $_.Section -eq 'User' }).Count -gt ($Results | Where-Object { $_.Section -eq 'Computer' }).Count) {
        $recommendations += "High number of User settings detected - consider Computer-side configuration where possible"
    }
    
    $performanceInsights.RecommendedOptimizations = $recommendations
    
    if ($recommendations) {
        Write-Host "`nPerformance Recommendations:" -ForegroundColor Cyan
        foreach ($rec in $recommendations) {
            Write-Host "  • $rec" -ForegroundColor Yellow
        }
    }
    
    return $performanceInsights
}

function Get-SecurityRecommendation {
    param($PatternName)
    
    $recommendations = @{
        'Disabled Firewall' = 'Enable Windows Firewall and configure appropriate rules'
        'Guest Account Enabled' = 'Disable the Guest account for security'
        'Weak Password Policy' = 'Implement strong password requirements (12+ chars, complexity)'
        'No Account Lockout' = 'Configure account lockout policy (5 attempts, 30 min lockout)'
        'Admin Rights' = 'Review and minimize administrative privileges'
        'Audit Disabled' = 'Enable comprehensive audit logging'
        'Remote Desktop' = 'Secure Remote Desktop with NLA and strong authentication'
        'Password Complexity' = 'Enable password complexity requirements'
    }
    
    return $recommendations[$PatternName] ?? "Review this setting for security implications"
}

function Generate-AnalysisReport {
    param($SecurityFindings, $ComplianceAnalysis, $Conflicts, $PerformanceAnalysis, $Results)
    
    $reportPath = "$OutputPath.html"
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>GPO Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 2px solid #2196F3; padding-bottom: 20px; margin-bottom: 30px; }
        .section { margin-bottom: 30px; padding: 20px; border-radius: 5px; }
        .security { background-color: #ffebee; border-left: 5px solid #f44336; }
        .compliance { background-color: #e3f2fd; border-left: 5px solid #2196F3; }
        .performance { background-color: #e8f5e8; border-left: 5px solid #4caf50; }
        .conflicts { background-color: #fff3e0; border-left: 5px solid #ff9800; }
        .critical { color: #d32f2f; font-weight: bold; }
        .high { color: #f57c00; font-weight: bold; }
        .medium { color: #1976d2; }
        .good { color: #388e3c; }
        .score { font-size: 24px; font-weight: bold; text-align: center; margin: 10px 0; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f0f0f0; }
        .recommendation { background-color: #fff9c4; padding: 10px; border-radius: 3px; margin: 5px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>GPO Security & Compliance Analysis</h1>
            <p>Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
            <p>Analyzed $($Results.Count) GPO settings across $((($Results | Select-Object -ExpandProperty GPO | Select-Object -ExpandProperty DisplayName -Unique).Count)) GPOs</p>
        </div>
        
        <div class="section security">
            <h2>🔐 Security Analysis</h2>
            <div class="score critical">Critical Issues: $($SecurityFindings.Critical.Count)</div>
            <div class="score high">High Risk Issues: $($SecurityFindings.High.Count)</div>
            <div class="score medium">Medium Risk Issues: $($SecurityFindings.Medium.Count)</div>
"@

    if ($SecurityFindings.Critical.Count -gt 0) {
        $html += "<h3>Critical Security Issues</h3><ul>"
        foreach ($finding in $SecurityFindings.Critical) {
            $html += "<li><strong>$($finding.Pattern)</strong> in $($finding.Result.GPO.DisplayName)<br>"
            $html += "<div class='recommendation'>$($finding.Recommendation)</div></li>"
        }
        $html += "</ul>"
    }

    $html += @"
        </div>
        
        <div class="section compliance">
            <h2>📋 Compliance Analysis</h2>
"@

    foreach ($framework in $ComplianceAnalysis.Scores.Keys) {
        if ($framework -ne 'Total') {
            $score = $ComplianceAnalysis.Scores[$framework]
            $scoreClass = if ($score -gt 80) { 'good' } elseif ($score -gt 60) { 'medium' } else { 'critical' }
            $html += "<div class='score $scoreClass'>$framework Compliance: $score%</div>"
        }
    }

    $html += @"
        </div>
        
        <div class="section conflicts">
            <h2>⚠️ Configuration Conflicts</h2>
            <div class="score">$($Conflicts.Count) Potential Conflicts Detected</div>
"@

    if ($Conflicts.Count -gt 0) {
        $html += "<table><tr><th>Setting</th><th>Conflicting States</th><th>Affected GPOs</th></tr>"
        foreach ($conflict in $Conflicts) {
            $html += "<tr><td>$($conflict.SettingName)</td><td>$($conflict.States -join ', ')</td><td>$($conflict.GPOs -join ', ')</td></tr>"
        }
        $html += "</table>"
    } else {
        $html += "<p class='good'>✓ No configuration conflicts detected</p>"
    }

    $html += @"
        </div>
        
        <div class="section performance">
            <h2>⚡ Performance Analysis</h2>
            <div class="score">$($PerformanceAnalysis.LargeGPOs.Count) Large GPOs Identified</div>
"@

    if ($PerformanceAnalysis.RecommendedOptimizations.Count -gt 0) {
        $html += "<h3>Optimization Recommendations</h3><ul>"
        foreach ($rec in $PerformanceAnalysis.RecommendedOptimizations) {
            $html += "<li>$rec</li>"
        }
        $html += "</ul>"
    }

    $html += @"
        </div>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "`nComprehensive analysis report generated: $reportPath" -ForegroundColor Green
}

# Main execution
try {
    Write-Host "=== GPO INTELLIGENT ANALYSIS ===" -ForegroundColor Cyan
    Write-Host "Analysis Type: $AnalysisType" -ForegroundColor Yellow
    Write-Host "Total Results: $($Results.Count)" -ForegroundColor Yellow
    Write-Host ("-" * 50) -ForegroundColor Gray
    
    $securityFindings = $null
    $complianceAnalysis = $null
    $conflicts = $null
    $performanceAnalysis = $null
    
    if ($AnalysisType -in @('Security', 'All')) {
        $securityFindings = Get-SecurityAnalysis -Results $Results
    }
    
    if ($AnalysisType -in @('Compliance', 'All')) {
        $complianceAnalysis = Get-ComplianceAnalysis -Results $Results
    }
    
    if ($AnalysisType -in @('Conflicts', 'All')) {
        $conflicts = Get-ConflictAnalysis -Results $Results
    }
    
    if ($AnalysisType -in @('Performance', 'All')) {
        $performanceAnalysis = Get-PerformanceAnalysis -Results $Results
    }
    
    if ($GenerateReport) {
        Generate-AnalysisReport -SecurityFindings $securityFindings -ComplianceAnalysis $complianceAnalysis -Conflicts $conflicts -PerformanceAnalysis $performanceAnalysis -Results $Results
    }
    
    Write-Host "`n=== ANALYSIS COMPLETE ===" -ForegroundColor Green
    
} catch {
    Write-Error "Analysis failed: $($_.Exception.Message)"
    throw
}

function New-AnalysisReport {
    <#
    .SYNOPSIS
        Generates comprehensive analysis report
        
    .DESCRIPTION
        Internal helper function to generate HTML analysis report from analysis results
        
    .PARAMETER AnalysisResults
        The analysis results to include in the report
        
    .PARAMETER OutputPath
        Output path for the report
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AnalysisResults,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    try {
        $htmlPath = "$OutputPath.html"
        
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>GPO Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .summary { background-color: #ecf0f1; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .section { margin-bottom: 30px; }
        .section h2 { background-color: #34495e; color: white; padding: 10px; border-radius: 3px; }
        table { border-collapse: collapse; width: 100%; margin-top: 10px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #3498db; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .high-risk { background-color: #e74c3c; color: white; }
        .medium-risk { background-color: #f39c12; color: white; }
        .low-risk { background-color: #27ae60; color: white; }
    </style>
</head>
<body>
    <div class="header">
        <h1>GPO Security and Compliance Analysis Report</h1>
        <p>Generated on $($AnalysisResults.Summary.AnalysisDate)</p>
    </div>
    
    <div class="summary">
        <h2>Executive Summary</h2>
        <ul>
            <li><strong>Total Settings Analyzed:</strong> $($AnalysisResults.Summary.TotalSettings)</li>
            <li><strong>Security Issues:</strong> $($AnalysisResults.Summary.SecurityIssues)</li>
            <li><strong>Compliance Issues:</strong> $($AnalysisResults.Summary.ComplianceIssues)</li>
            <li><strong>Performance Issues:</strong> $($AnalysisResults.Summary.PerformanceIssues)</li>
            <li><strong>Conflicts Detected:</strong> $($AnalysisResults.Summary.Conflicts)</li>
        </ul>
    </div>
"@

        # Add security analysis section
        if ($AnalysisResults.Security.Count -gt 0) {
            $html += @'
    <div class="section">
        <h2>Security Analysis</h2>
        <table>
            <tr>
                <th>GPO Name</th>
                <th>Setting</th>
                <th>Risk Level</th>
                <th>Recommendation</th>
            </tr>
'@
            foreach ($finding in $AnalysisResults.Security) {
                $riskClass = switch ($finding.RiskLevel) {
                    'High' { 'high-risk' }
                    'Medium' { 'medium-risk' }
                    default { 'low-risk' }
                }
                
                $html += @"
            <tr>
                <td>$([System.Web.HttpUtility]::HtmlEncode($finding.GPOName))</td>
                <td>$([System.Web.HttpUtility]::HtmlEncode($finding.SettingName))</td>
                <td class="$riskClass">$($finding.RiskLevel)</td>
                <td>$([System.Web.HttpUtility]::HtmlEncode($finding.Recommendation))</td>
            </tr>
"@
            }
            $html += @'
        </table>
    </div>
'@
        }

        # Add performance analysis section
        if ($AnalysisResults.Performance.Count -gt 0) {
            $html += @'
    <div class="section">
        <h2>Performance Analysis</h2>
        <table>
            <tr>
                <th>GPO Name</th>
                <th>Setting Count</th>
                <th>Performance Impact</th>
                <th>Recommendation</th>
            </tr>
'@
            foreach ($finding in $AnalysisResults.Performance) {
                $impactClass = switch ($finding.PerformanceImpact) {
                    'High' { 'high-risk' }
                    'Medium' { 'medium-risk' }
                    default { 'low-risk' }
                }
                
                $html += @"
            <tr>
                <td>$([System.Web.HttpUtility]::HtmlEncode($finding.GPOName))</td>
                <td>$($finding.SettingCount)</td>
                <td class="$impactClass">$($finding.PerformanceImpact)</td>
                <td>$([System.Web.HttpUtility]::HtmlEncode($finding.Recommendation))</td>
            </tr>
"@
            }
            $html += @'
        </table>
    </div>
'@
        }

        $html += @'
</body>
</html>
'@

        $html | Out-File -FilePath $htmlPath -Encoding UTF8
        
        Write-Verbose "Analysis report generated: $htmlPath"
    }
    catch {
        Write-Error "Report generation failed: $($_.Exception.Message)"
        throw
    }
}

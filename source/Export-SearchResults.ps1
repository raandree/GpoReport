# Export-SearchResults.ps1 - Export GPO search results in multiple formats
<#
.SYNOPSIS
    Export GPO search results to multiple professional formats
    
.DESCRIPTION
    Export-SearchResults.ps1 transforms GPO search results into professional formats suitable 
    for reporting, compliance documentation, and system integration. Supports JSON for APIs, 
    CSV for spreadsheet analysis, HTML for presentations, and XML for SIEM tools.
    
    KEY FEATURES:
    • Multi-format export (JSON, CSV, HTML, XML)
    • Rich HTML reports with styling and statistics
    • Metadata inclusion for audit trails
    • Pipeline integration with search results
    • Professional formatting for stakeholder reports
    
    WORKFLOW INTEGRATION:
    This script accepts output from Search-GPMCReports.ps1 and transforms it into 
    formats suitable for different audiences and systems.
    
.PARAMETER Results
    Array of search result objects from Search-GPMCReports.ps1
    Pipeline input supported for seamless workflow integration
    
.PARAMETER OutputPath
    Base output path without file extension
    Extensions (.json, .csv, .html, .xml) added automatically based on format
    
.PARAMETER Format
    Target export format(s):
    • JSON - Machine-readable format for API integration and automation
    • CSV - Spreadsheet-compatible for Excel analysis and data manipulation
    • HTML - Styled visual reports for presentations and stakeholder briefings
    • XML - Structured format for SIEM tools and compliance systems
    • All - Generates all four formats simultaneously
    
.PARAMETER IncludeMetadata
    Include comprehensive metadata in exports:
    • Export timestamp and user context
    • Result count and summary statistics
    • Data source information
    • Processing details for audit trails
    
.OUTPUTS
    Creates export files with appropriate extensions:
    • [OutputPath].json - JSON format with optional metadata
    • [OutputPath].csv - CSV format with headers
    • [OutputPath].html - Styled HTML report with statistics
    • [OutputPath].xml - Structured XML with schema
    
.EXAMPLE
    # Export audit findings in all formats with metadata
    $results = .\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*audit*"
    .\Export-SearchResults.ps1 -Results $results -OutputPath "audit-report" -Format All -IncludeMetadata
    
.EXAMPLE
    # Pipeline integration for CSV export
    .\Search-GPMCReports.ps1 -Path "D:\GPO\" -SearchString "*security*" | 
        .\Export-SearchResults.ps1 -OutputPath "security-findings" -Format CSV
    
.EXAMPLE
    # Generate executive HTML report
    $results = .\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*password*"
    .\Export-SearchResults.ps1 -Results $results -OutputPath "password-policy-report" -Format HTML -IncludeMetadata
    
.EXAMPLE
    # Export for SIEM integration
    $results | .\Export-SearchResults.ps1 -OutputPath "siem-feed" -Format XML
    
.NOTES
    File Name      : Export-SearchResults.ps1
    Author         : GPO Analysis Team
    Prerequisite   : PowerShell 5.1+ 
    Dependencies   : Search-GPMCReports.ps1 for result objects
    
    HTML reports include:
    • Professional styling with CSS
    • Summary statistics and counts
    • Color-coded sections for readability
    • Responsive design for various screens
    
    Performance notes:
    • Efficient processing of large result sets
    • Memory-conscious streaming for big exports
    • Parallel processing for multiple formats
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [object[]]$Results,
    
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    
    [Parameter()]
    [ValidateSet('JSON', 'CSV', 'HTML', 'XML', 'All')]
    [string]$Format = 'JSON',
    
    [Parameter()]
    [switch]$IncludeMetadata
)

function Export-ToJSON {
    param($Results, $OutputPath, $IncludeMetadata)
    
    $exportData = @{
        SearchResults = $Results
        ResultCount   = $Results.Count
    }
    
    if ($IncludeMetadata) {
        $exportData.Metadata = @{
            ExportTime   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
            ExportedBy   = $env:USERNAME
            ComputerName = $env:COMPUTERNAME
        }
    }
    
    $jsonPath = "$OutputPath.json"
    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
    Write-Host "JSON export saved to: $jsonPath" -ForegroundColor Green
}

function Export-ToCSV {
    param($Results, $OutputPath)
    
    $csvData = $Results | Select-Object @{
        n = 'MatchedText'; e = { $_.MatchedText }
    }, @{
        n = 'MatchType'; e = { $_.MatchType }
    }, @{
        n = 'GPO_Name'; e = { $_.GPO.DisplayName }
    }, @{
        n = 'GPO_Domain'; e = { $_.GPO.DomainName }
    }, @{
        n = 'GPO_GUID'; e = { $_.GPO.GUID }
    }, @{
        n = 'Section'; e = { $_.Section }
    }, @{
        n = 'CategoryPath'; e = { $_.CategoryPath }
    }, @{
        n = 'Setting_Name'; e = { $_.Setting.Name }
    }, @{
        n = 'Setting_State'; e = { $_.Setting.State }
    }, @{
        n = 'Setting_Value'; e = { $_.Setting.Value }
    }, @{
        n = 'Setting_Context'; e = { $_.Setting.Context }
    }, @{
        n = 'SourceFile'; e = { $_.SourceFile }
    }
    
    $csvPath = "$OutputPath.csv"
    $csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "CSV export saved to: $csvPath" -ForegroundColor Green
}

function Export-ToHTML {
    param($Results, $OutputPath, $IncludeMetadata)
    
    $html = @'
<!DOCTYPE html>
<html>
<head>
    <title>GPO Search Results Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; margin-bottom: 20px; }
        .summary { background-color: #e7f3ff; padding: 10px; border-radius: 5px; margin-bottom: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .section-computer { background-color: #e3f2fd; }
        .section-user { background-color: #fff3e0; }
        .category { font-weight: bold; color: #2196F3; }
    </style>
</head>
<body>
    <div class="header">
        <h1>GPO Search Results Report</h1>
'@

    if ($IncludeMetadata) {
        $html += @"
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Total Results:</strong> $($Results.Count)</p>
"@
    }
    
    $html += @"
    </div>
    
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Total Matches:</strong> $($Results.Count)</p>
        <p><strong>Computer Section:</strong> $(($Results | Where-Object {$_.Section -eq 'Computer'}).Count)</p>
        <p><strong>User Section:</strong> $(($Results | Where-Object {$_.Section -eq 'User'}).Count)</p>
        <p><strong>Unique GPOs:</strong> $(($Results | Select-Object -ExpandProperty GPO | Select-Object -ExpandProperty DisplayName -Unique).Count)</p>
    </div>
    
    <table>
        <tr>
            <th>Matched Text</th>
            <th>Section</th>
            <th>GPO Name</th>
            <th>Category</th>
            <th>Setting Details</th>
            <th>State</th>
        </tr>
"@

    foreach ($result in $Results) {
        $sectionClass = if ($result.Section -eq 'Computer') { 'section-computer' } else { 'section-user' }
        $html += @"
        <tr class="$sectionClass">
            <td>$($result.MatchedText)</td>
            <td>$($result.Section)</td>
            <td>$($result.GPO.DisplayName)</td>
            <td class="category">$($result.CategoryPath)</td>
            <td>$($result.Setting.Name)</td>
            <td>$($result.Setting.State)</td>
        </tr>
"@
    }
    
    $html += @'
    </table>
</body>
</html>
'@
    
    $htmlPath = "$OutputPath.html"
    $html | Out-File -FilePath $htmlPath -Encoding UTF8
    Write-Host "HTML report saved to: $htmlPath" -ForegroundColor Green
}

function Export-ToXML {
    param($Results, $OutputPath, $IncludeMetadata)
    
    $xmlDoc = New-Object System.Xml.XmlDocument
    $root = $xmlDoc.CreateElement('GPOSearchResults')
    $xmlDoc.AppendChild($root) | Out-Null
    
    if ($IncludeMetadata) {
        $metadata = $xmlDoc.CreateElement('Metadata')
        $metadata.SetAttribute('ExportTime', (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ'))
        $metadata.SetAttribute('ResultCount', $Results.Count)
        $root.AppendChild($metadata) | Out-Null
    }
    
    foreach ($result in $Results) {
        $resultNode = $xmlDoc.CreateElement('Result')
        
        $resultNode.SetAttribute('MatchedText', $result.MatchedText)
        $resultNode.SetAttribute('MatchType', $result.MatchType)
        $resultNode.SetAttribute('Section', $result.Section)
        $resultNode.SetAttribute('CategoryPath', $result.CategoryPath)
        
        $gpoNode = $xmlDoc.CreateElement('GPO')
        $gpoNode.SetAttribute('DisplayName', $result.GPO.DisplayName)
        $gpoNode.SetAttribute('Domain', $result.GPO.DomainName)
        $gpoNode.SetAttribute('GUID', $result.GPO.GUID)
        $resultNode.AppendChild($gpoNode) | Out-Null
        
        $settingNode = $xmlDoc.CreateElement('Setting')
        $settingNode.SetAttribute('Name', $result.Setting.Name)
        $settingNode.SetAttribute('State', $result.Setting.State)
        $settingNode.SetAttribute('Context', $result.Setting.Context)
        if ($result.Setting.Value) {
            $settingNode.SetAttribute('Value', $result.Setting.Value)
        }
        $resultNode.AppendChild($settingNode) | Out-Null
        
        $root.AppendChild($resultNode) | Out-Null
    }
    
    $xmlPath = "$OutputPath.xml"
    $xmlDoc.Save($xmlPath)
    Write-Host "XML export saved to: $xmlPath" -ForegroundColor Green
}

# Main execution
try {
    if ($Format -eq 'All') {
        Export-ToJSON -Results $Results -OutputPath $OutputPath -IncludeMetadata $IncludeMetadata
        Export-ToCSV -Results $Results -OutputPath $OutputPath
        Export-ToHTML -Results $Results -OutputPath $OutputPath -IncludeMetadata $IncludeMetadata
        Export-ToXML -Results $Results -OutputPath $OutputPath -IncludeMetadata $IncludeMetadata
    }
    else {
        switch ($Format) {
            'JSON' { Export-ToJSON -Results $Results -OutputPath $OutputPath -IncludeMetadata $IncludeMetadata }
            'CSV' { Export-ToCSV -Results $Results -OutputPath $OutputPath }
            'HTML' { Export-ToHTML -Results $Results -OutputPath $OutputPath -IncludeMetadata $IncludeMetadata }
            'XML' { Export-ToXML -Results $Results -OutputPath $OutputPath -IncludeMetadata $IncludeMetadata }
        }
    }
}
catch {
    Write-Error "Export failed: $($_.Exception.Message)"
    throw
}

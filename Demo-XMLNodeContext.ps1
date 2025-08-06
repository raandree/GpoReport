# Demo-XMLNodeContext.ps1
# Demonstrates the enhanced XML node context feature in GpoReport module

# Import the GpoReport module
Import-Module ".\output\module\GpoReport\0.1.0\GpoReport.psd1" -Force

Write-Host "=== GPO Report XML Node Context Enhancement Demo ===" -ForegroundColor Cyan
Write-Host ""

# Example 1: Basic search showing XML node context
Write-Host "Example 1: Searching for 'audit' - showing XML node context" -ForegroundColor Yellow
Write-Host ""

$auditResults = Search-GPMCReports -Path ".\Test Reports" -SearchString "*audit*" -MaxResults 1
if ($auditResults.Count -gt 0) {
    $result = $auditResults[0]
    
    Write-Host "GPO Name: " -NoNewline; Write-Host $result.GPOName -ForegroundColor Green
    Write-Host "Setting Value: " -NoNewline; Write-Host $result.SettingValue -ForegroundColor Green
    Write-Host "Category Path: " -NoNewline; Write-Host $result.CategoryPath -ForegroundColor Green
    Write-Host ""
    Write-Host "XML Node Context:" -ForegroundColor Cyan
    Write-Host "  Element Name: " -NoNewline; Write-Host $result.XmlNode.ElementName -ForegroundColor White
    Write-Host "  XML Path: " -NoNewline; Write-Host $result.XmlNode.XmlPath -ForegroundColor White
    Write-Host "  Parent Hierarchy: " -NoNewline; Write-Host ($result.XmlNode.ParentHierarchy -join " > ") -ForegroundColor White
    Write-Host "  XML Content: " -NoNewline; Write-Host $result.XmlNode.OuterXml -ForegroundColor Gray
}

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Example 2: Search showing element with attributes (if any)
Write-Host "Example 2: Searching for 'registry' - showing potential attributes" -ForegroundColor Yellow
Write-Host ""

$registryResults = Search-GPMCReports -Path ".\Test Reports" -SearchString "*registry*" -MaxResults 1
if ($registryResults.Count -gt 0) {
    $result = $registryResults[0]
    
    Write-Host "GPO Name: " -NoNewline; Write-Host $result.GPOName -ForegroundColor Green
    Write-Host "Setting Value: " -NoNewline; Write-Host $result.SettingValue -ForegroundColor Green
    Write-Host ""
    Write-Host "XML Node Context:" -ForegroundColor Cyan
    Write-Host "  Element Name: " -NoNewline; Write-Host $result.XmlNode.ElementName -ForegroundColor White
    Write-Host "  Element Attributes: " -NoNewline; 
    if ($result.XmlNode.ElementAttributes) {
        Write-Host $result.XmlNode.ElementAttributes -ForegroundColor White
    } else {
        Write-Host "(No attributes)" -ForegroundColor Gray
    }
    Write-Host "  Parent Hierarchy: " -NoNewline; Write-Host ($result.XmlNode.ParentHierarchy -join " > ") -ForegroundColor White
    Write-Host "  XML Content (first 200 chars): " -NoNewline; 
    $xmlContent = $result.XmlNode.OuterXml
    if ($xmlContent.Length -gt 200) {
        Write-Host ($xmlContent.Substring(0, 200) + "...") -ForegroundColor Gray
    } else {
        Write-Host $xmlContent -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Example 3: Show how this helps with debugging and analysis
Write-Host "Example 3: Analysis benefits - showing multiple results with XML context" -ForegroundColor Yellow
Write-Host ""

$passwordResults = Search-GPMCReports -Path ".\Test Reports" -SearchString "*password*" -MaxResults 3
Write-Host "Found $($passwordResults.Count) password-related settings:" -ForegroundColor Green
Write-Host ""

for ($i = 0; $i -lt $passwordResults.Count; $i++) {
    $result = $passwordResults[$i]
    Write-Host "Result $($i + 1):" -ForegroundColor Cyan
    Write-Host "  Setting: $($result.SettingValue)" -ForegroundColor White
    Write-Host "  Found in: $($result.XmlNode.ElementName) element" -ForegroundColor White
    Write-Host "  Context: $($result.XmlNode.ParentHierarchy -join " > ")" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "Benefits of XML Node Context Enhancement:" -ForegroundColor Yellow
Write-Host "• Users can see exactly which XML element contained their match"
Write-Host "• Parent hierarchy shows the XML structure context"
Write-Host "• Element attributes provide additional metadata"
Write-Host "• Complete XML content enables detailed analysis"
Write-Host "• Enhanced debugging capabilities for complex searches"
Write-Host "• Better understanding of GPO settings structure"
Write-Host ""
Write-Host "Demo completed!" -ForegroundColor Green

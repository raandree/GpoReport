# Demo: Enhanced XML Node Context
# This script demonstrates the improvement in XML node context capture

Write-Host "=== Enhanced XML Node Context Demo ===" -ForegroundColor Cyan
Write-Host ""

# Import the module
Import-Module .\output\module\GpoReport\0.1.0\GpoReport.psd1 -Force

# Search for "notifications network usage" to demonstrate enhanced context
Write-Host "Searching for 'notifications network usage'..." -ForegroundColor Yellow
$results = Search-GPMCReports -Path ".\Test Reports\AllSettings1.xml" -SearchString "notifications network usage"

if ($results) {
    $result = $results[0]
    
    Write-Host "`nENHANCED XML NODE CONTEXT:" -ForegroundColor Green
    Write-Host "=========================" -ForegroundColor Green
    
    Write-Host "`nElement Name: " -NoNewline -ForegroundColor White
    Write-Host $result.XmlNode.ElementName -ForegroundColor Cyan
    
    Write-Host "Context Level: " -NoNewline -ForegroundColor White
    Write-Host $result.XmlNode.ContextLevel -ForegroundColor Cyan
    
    Write-Host "Immediate Parent: " -NoNewline -ForegroundColor White
    Write-Host $result.XmlNode.ImmediateParent -ForegroundColor Cyan
    
    Write-Host "`nXML PATH:" -ForegroundColor Green
    Write-Host $result.XmlNode.XmlPath -ForegroundColor White
    
    Write-Host "`nCOMPLETE XML BLOCK (first 500 chars):" -ForegroundColor Green
    $xmlPreview = $result.XmlNode.OuterXml.Substring(0, [Math]::Min(500, $result.XmlNode.OuterXml.Length))
    Write-Host $xmlPreview -ForegroundColor White
    if ($result.XmlNode.OuterXml.Length -gt 500) {
        Write-Host "..." -ForegroundColor Gray
        Write-Host "(XML truncated for display - full context captured)" -ForegroundColor Gray
    }
    
    Write-Host "`n`nBENEFITS OF ENHANCED CONTEXT:" -ForegroundColor Green
    Write-Host "=============================" -ForegroundColor Green
    Write-Host "• Shows complete Policy block instead of just Name element" -ForegroundColor White
    Write-Host "• Includes policy state (Enabled/Disabled/Not Configured)" -ForegroundColor White
    Write-Host "• Provides full explanation text for policy" -ForegroundColor White
    Write-Host "• Captures all nested settings and values" -ForegroundColor White
    Write-Host "• Maintains proper XML structure for processing" -ForegroundColor White
    
} else {
    Write-Host "No results found for the search term." -ForegroundColor Red
}

Write-Host "`n=== Demo Complete ===" -ForegroundColor Cyan

# Demo-ShowGPOSearchReportUi.ps1
# Demonstrates the new Show-GPOSearchReportUi command

Write-Host "=== Show-GPOSearchReportUi Demo ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This demo showcases the new GUI for generating GPO search reports." -ForegroundColor White
Write-Host ""

# Import the module
Write-Host "1. Importing GpoReport module..." -ForegroundColor Yellow
Import-Module D:\Git\GpoReport\output\module\GpoReport\0.1.0\GpoReport.psd1 -Force
Write-Host "   ✓ Module imported successfully" -ForegroundColor Green
Write-Host ""

# Verify the command
Write-Host "2. Verifying Show-GPOSearchReportUi command..." -ForegroundColor Yellow
$cmd = Get-Command Show-GPOSearchReportUi -ErrorAction SilentlyContinue
if ($cmd) {
    Write-Host "   ✓ Command found: $($cmd.Name)" -ForegroundColor Green
    Write-Host "   ✓ Source: $($cmd.Source)" -ForegroundColor Green
    Write-Host "   ✓ Type: $($cmd.CommandType)" -ForegroundColor Green
} else {
    Write-Host "   ✗ Command not found" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Show command syntax
Write-Host "3. Command Syntax:" -ForegroundColor Yellow
Write-Host "   Show-GPOSearchReportUi" -ForegroundColor White
Write-Host ""

# Display features
Write-Host "4. UI Features:" -ForegroundColor Yellow
Write-Host "   • Two search modes: Local XML files or Active Directory" -ForegroundColor White
Write-Host "   • Guided input fields with tooltips" -ForegroundColor White
Write-Host "   • Browse dialogs for file/folder selection" -ForegroundColor White
Write-Host "   • Real-time input validation" -ForegroundColor White
Write-Host "   • Progress indicator during report generation" -ForegroundColor White
Write-Host "   • Automatic HTML report generation and viewing" -ForegroundColor White
Write-Host ""

# Show help
Write-Host "5. Getting Help:" -ForegroundColor Yellow
Write-Host "   Get-Help Show-GPOSearchReportUi -Full" -ForegroundColor White
Write-Host ""

# Launch option
Write-Host "6. Launch UI:" -ForegroundColor Yellow
Write-Host ""
$response = Read-Host "   Would you like to launch the UI now? (Y/N)"
if ($response -eq 'Y' -or $response -eq 'y') {
    Write-Host "   Launching Show-GPOSearchReportUi..." -ForegroundColor Green
    Show-GPOSearchReportUi
} else {
    Write-Host "   You can launch it anytime by running: Show-GPOSearchReportUi" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=== Demo Complete ===" -ForegroundColor Cyan

# Test Validation: Enhanced XML Node Context Feature
# This script validates that the enhanced XML node context tests are working correctly

Write-Host "=== XML Node Context Feature Validation ===" -ForegroundColor Cyan
Write-Host ""

# Import the module
Import-Module ..\..\output\module\GpoReport\0.1.0\GpoReport.psd1 -Force

# Test 1: Verify XmlNode property is included
Write-Host "Test 1: XmlNode Property Inclusion" -ForegroundColor Yellow
$results = Search-GPMCReports -Path "..\..\Test Reports\AllSettings1.xml" -SearchString "Chile"
if ($results -and $results[0].PSObject.Properties.Name -contains "XmlNode") {
    Write-Host "✅ PASS: XmlNode property is included in search results" -ForegroundColor Green
} else {
    Write-Host "❌ FAIL: XmlNode property is missing" -ForegroundColor Red
}

# Test 2: Verify all required XmlNode properties
Write-Host "`nTest 2: Required XmlNode Properties" -ForegroundColor Yellow
if ($results) {
    $xmlNode = $results[0].XmlNode
    $requiredProps = @("ElementName", "XmlPath", "OuterXml", "ParentHierarchy", "ImmediateParent", "ContextLevel")
    $missingProps = $requiredProps | Where-Object { $xmlNode.PSObject.Properties.Name -notcontains $_ }
    
    if ($missingProps.Count -eq 0) {
        Write-Host "✅ PASS: All required XmlNode properties present" -ForegroundColor Green
        Write-Host "   Properties: $($xmlNode.PSObject.Properties.Name -join ', ')" -ForegroundColor Gray
    } else {
        Write-Host "❌ FAIL: Missing properties: $($missingProps -join ', ')" -ForegroundColor Red
    }
}

# Test 3: Verify meaningful parent detection for policies
Write-Host "`nTest 3: Meaningful Parent Detection" -ForegroundColor Yellow
$policyResults = Search-GPMCReports -Path "..\..\Test Reports\AllSettings1.xml" -SearchString "Turn off notifications network usage"
if ($policyResults) {
    $xmlNode = $policyResults[0].XmlNode
    if ($xmlNode.ElementName -eq "Policy" -and $xmlNode.ContextLevel -eq "Policy") {
        Write-Host "✅ PASS: Meaningful parent detection working (Policy level context)" -ForegroundColor Green
        Write-Host "   ElementName: $($xmlNode.ElementName), ContextLevel: $($xmlNode.ContextLevel)" -ForegroundColor Gray
    } else {
        Write-Host "❌ FAIL: Expected Policy-level context, got ElementName: $($xmlNode.ElementName), ContextLevel: $($xmlNode.ContextLevel)" -ForegroundColor Red
    }
}

# Test 4: Verify ParentHierarchy is array
Write-Host "`nTest 4: ParentHierarchy Array Type" -ForegroundColor Yellow
if ($results) {
    $xmlNode = $results[0].XmlNode
    if ($xmlNode.ParentHierarchy -is [System.Array] -and $xmlNode.ParentHierarchy.Count -gt 0) {
        Write-Host "✅ PASS: ParentHierarchy is array with $($xmlNode.ParentHierarchy.Count) elements" -ForegroundColor Green
        Write-Host "   Hierarchy: $($xmlNode.ParentHierarchy -join ' > ')" -ForegroundColor Gray
    } else {
        Write-Host "❌ FAIL: ParentHierarchy type issue. Type: $($xmlNode.ParentHierarchy.GetType().Name), Count: $($xmlNode.ParentHierarchy.Count)" -ForegroundColor Red
    }
}

# Test 5: Verify immediate vs meaningful parent distinction
Write-Host "`nTest 5: Parent Distinction" -ForegroundColor Yellow
if ($policyResults) {
    $xmlNode = $policyResults[0].XmlNode
    if ($xmlNode.ImmediateParent -eq "Name" -and $xmlNode.ElementName -eq "Policy") {
        Write-Host "✅ PASS: Correctly distinguishes immediate parent ($($xmlNode.ImmediateParent)) from meaningful parent ($($xmlNode.ElementName))" -ForegroundColor Green
    } else {
        Write-Host "❌ FAIL: Parent distinction issue. ImmediateParent: $($xmlNode.ImmediateParent), ElementName: $($xmlNode.ElementName)" -ForegroundColor Red
    }
}

# Test 6: Verify XML content capture
Write-Host "`nTest 6: Complete XML Content Capture" -ForegroundColor Yellow
if ($policyResults) {
    $xmlNode = $policyResults[0].XmlNode
    if ($xmlNode.OuterXml -match "q4:Policy" -and $xmlNode.OuterXml -match "q4:Name" -and $xmlNode.OuterXml -match "q4:State") {
        Write-Host "✅ PASS: Complete policy XML content captured" -ForegroundColor Green
        Write-Host "   XML Length: $($xmlNode.OuterXml.Length) characters" -ForegroundColor Gray
    } else {
        Write-Host "❌ FAIL: Incomplete XML content capture" -ForegroundColor Red
    }
}

Write-Host "`n=== Validation Complete ===" -ForegroundColor Cyan

# Summary of what was tested
Write-Host "`nTEST COVERAGE SUMMARY:" -ForegroundColor Green
Write-Host "✓ XmlNode property inclusion in search results" -ForegroundColor White
Write-Host "✓ All required XmlNode sub-properties present" -ForegroundColor White  
Write-Host "✓ Meaningful parent element detection (Policy vs Element level)" -ForegroundColor White
Write-Host "✓ ParentHierarchy maintained as proper array type" -ForegroundColor White
Write-Host "✓ Distinction between immediate and meaningful parents" -ForegroundColor White
Write-Host "✓ Complete XML policy block capture" -ForegroundColor White

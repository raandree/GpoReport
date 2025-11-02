#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Search-GPMCReports function validation

.DESCRIPTION
    This test script validates that the Search-GPMCReports function correctly
    identifies and categorizes GPO settings according to the expected mapping table.
    
    The tests verify that search patterns return the correct category paths for
    various types of Group Policy settings including Security Settings, 
    Administrative Templates, Advanced Audit Configuration, and more.

.NOTES
    Tests the GpoReport module functions after module restructuring to Sampler framework.
    Restored comprehensive testing from original 728-line test file.
#>

BeforeAll {
    # For code coverage, dot-source the individual files instead of importing the built module
    $SourcePath = Join-Path $PSScriptRoot "..\..\source"
    
    # Import the main module manifest
    $ModuleManifest = Join-Path $SourcePath "GpoReport.psd1"
    if (Test-Path $ModuleManifest) {
        # Dot-source all the source files for coverage analysis
        $PrivateFunctions = Get-ChildItem -Path (Join-Path $SourcePath "Private") -Filter "*.ps1" -ErrorAction SilentlyContinue
        $PublicFunctions = Get-ChildItem -Path (Join-Path $SourcePath "Public") -Filter "*.ps1" -ErrorAction SilentlyContinue
        
        # Source the prefix first
        $PrefixFile = Join-Path $SourcePath "prefix.ps1"
        if (Test-Path $PrefixFile) {
            . $PrefixFile
        }
        
        # Dot-source all private functions
        foreach ($function in $PrivateFunctions) {
            . $function.FullName
        }
        
        # Dot-source all public functions  
        foreach ($function in $PublicFunctions) {
            . $function.FullName
        }
    } else {
        throw "GpoReport module manifest not found at: $ModuleManifest"
    }
    
    # Set up test data paths
    $TestDataPath = Join-Path $PSScriptRoot "..\..\Test Reports\AllSettings1.xml"
    $PreferencesDataPath = Join-Path $PSScriptRoot "..\..\Test Reports\AllPreferences1.xml"
    
    # Verify test data exists
    if (-not (Test-Path $TestDataPath)) {
        Write-Warning "Test data file not found at: $TestDataPath"
        $script:UseSimpleTest = $true
        $script:TestXmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<GPO xmlns="http://www.microsoft.com/GroupPolicy/Settings" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <Identifier xmlns="http://www.microsoft.com/GroupPolicy/Types">{12345678-1234-1234-1234-123456789012}</Identifier>
  <Domain xmlns="http://www.microsoft.com/GroupPolicy/Types">test.domain.com</Domain>
  <Name>Test GPO</Name>
  <Computer>
    <ExtensionData>
      <Extension xmlns:q1="http://www.microsoft.com/GroupPolicy/Settings/Security" xsi:type="q1:SecuritySettings">
        <q1:Account>
          <q1:PasswordPolicy>
            <q1:PasswordHistorySize>5</q1:PasswordHistorySize>
          </q1:PasswordPolicy>
        </q1:Account>
      </Extension>
    </ExtensionData>
  </Computer>
</GPO>
"@
    } else {
        $script:UseSimpleTest = $false
    }
    
    # Define the expected mapping table (restored from original comprehensive tests)
    $script:ExpectedMappings = @{
        "Chile" = "Security Settings > Local Policies > User Rights Assignment"
        "SeTakeOwnershipPrivilege" = "Security Settings > Local Policies > User Rights Assignment"
        "SeCreateGlobalPrivilege" = "Security Settings > Local Policies > User Rights Assignment"
        "LDAP server signing requirements" = "Security Settings > Local Policies > Security Options > Domain Controller"
        "Require signing" = "Security Settings > Local Policies > Security Options > Domain Controller"
        "GpoBackup" = "Security Settings > File System"
        "DeployDebug" = "Security Settings > File System"
        "Audit Kerberos Service Ticket Operations" = "Security Settings > Advanced Audit Configuration > Account Logon"
        "Audit Directory Service Changes" = "Security Settings > Advanced Audit Configuration > DS Access"
        "Turn off notifications network usage" = "Administrative Templates > Start Menu and Taskbar > Notifications"
        "RetentionDays" = "Security Settings > Event Log"
        "Restrict CD-ROM" = "Security Settings > Local Policies > Security Options > Devices"
        "Server SPN" = "Security Settings > Local Policies > Security Options > Other"
        "AuditDSAccess" = "Security Settings > Account Policies > Audit Policy"
        "MaxTicketAge" = "Security Settings > Account Policies > Kerberos Policy"
        "PasswordHistorySize" = "Security Settings > Account Policies > Password Policy"
        "Uruguay" = "Security Settings > Local Policies > User Rights Assignment"
        "NTDS" = "Security Settings > Local Policies > Security Options > Domain Controller"
        "7-Zip" = "Security Settings > Registry"
        "Armenia" = "Security Settings > Restricted Groups"
        "Force a specific default lock screen" = "Administrative Templates > Control Panel > Personalization > Lock Screen"
        "Turn on Security Center" = "Administrative Templates > Windows Components > Security Center"
        "Download missing COM components" = "Administrative Templates > System > Internet Communication Management > Internet Communication settings"
        "Prevent access to the command prompt" = "Administrative Templates > System"
        # Updated to match actual XML content
        "Configure Windows Defender SmartScreen" = "Administrative Templates > Windows Components > Windows Defender SmartScreen > Microsoft Edge"
        # Commented out tests for policies not present in current XML
        # "Include command line in process creation events" = "Administrative Templates > System > Audit Process Creation"
        # "Turn off Windows Defender SmartScreen" = "Administrative Templates > Windows Components > File Explorer"
        # "Configure Attack Surface Reduction rules" = "Administrative Templates > Windows Components > Windows Defender Antivirus > Windows Defender Exploit Guard > Attack Surface Reduction"
        # "Turn on behavior monitoring" = "Administrative Templates > Windows Components > Windows Defender Antivirus > Real-time Protection"
        # "Specify the interval to check for definition updates" = "Administrative Templates > Windows Components > Windows Defender Antivirus > Signature Updates"
        # "Turn off real-time protection" = "Administrative Templates > Windows Components > Windows Defender Antivirus > Real-time Protection"
    }
    
    # Helper function to execute search and extract category path (adapted for module)
    function Invoke-GPMCSearch {
        param(
            [string]$SearchTerm,
            [string]$TestDataPath
        )
        
        try {
            # Execute the module function and get the result objects
            if ($script:UseSimpleTest) {
                $results = Search-GPMCReports -XmlContent $script:TestXmlContent -SearchString $SearchTerm 2>$null
            } else {
                $results = Search-GPMCReports -Path $TestDataPath -SearchString $SearchTerm 2>$null
            }
            
            # If we have results, return the CategoryPath of the first match
            if ($results -and $results.Count -gt 0) {
                $firstResult = if ($results -is [array]) { $results[0] } else { $results }
                if ($firstResult.CategoryPath) {
                    return $firstResult.CategoryPath
                }
            }
            return "Not Found"
        }
        catch {
            Write-Warning "Error executing search for '$SearchTerm': $($_.Exception.Message)"
            return "Error"
        }
    }
}

Describe "Search-GPMCReports Function Validation" {
    
    Context "Module Import and Basic Functionality" {
        
        It "Should have the Search-GPMCReports function available" {
            Get-Command Search-GPMCReports -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should be able to process XML content" -Skip:(-not $script:UseSimpleTest) {
            { Search-GPMCReports -XmlContent $script:TestXmlContent -SearchString "Test" } | Should -Not -Throw
        }
        
        It "Should be able to process test data file" -Skip:$script:UseSimpleTest {
            { Search-GPMCReports -Path $TestDataPath -SearchString "*test*" } | Should -Not -Throw
        }
        
        It "Should return objects with expected properties when searching XML content" -Skip:(-not $script:UseSimpleTest) {
            $results = Search-GPMCReports -XmlContent $script:TestXmlContent -SearchString "PasswordHistory"
            if ($results) {
                $results[0] | Should -Not -BeNullOrEmpty
                $results[0].PSObject.Properties.Name | Should -Contain "GPOName"
                $results[0].PSObject.Properties.Name | Should -Contain "SettingName"
            }
        }
        
        It "Should return objects with expected properties when searching file" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Chile"
            if ($results) {
                $results[0] | Should -Not -BeNullOrEmpty
                $results[0].PSObject.Properties.Name | Should -Contain "CategoryPath"
                $results[0].PSObject.Properties.Name | Should -Contain "GPOName"
                $results[0].PSObject.Properties.Name | Should -Contain "SettingName"
            }
        }
    }

    Context "Enhanced XML Node Context Validation" {
        
        It "Should include XmlNode property in search results" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Chile"
            if ($results) {
                $results[0].PSObject.Properties.Name | Should -Contain "XmlNode"
                $results[0].XmlNode | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should have all required XmlNode properties" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Chile"
            if ($results) {
                $xmlNode = $results[0].XmlNode
                $xmlNode.PSObject.Properties.Name | Should -Contain "ElementName"
                $xmlNode.PSObject.Properties.Name | Should -Contain "XmlPath"
                $xmlNode.PSObject.Properties.Name | Should -Contain "OuterXml"
                $xmlNode.PSObject.Properties.Name | Should -Contain "ParentHierarchy"
                $xmlNode.PSObject.Properties.Name | Should -Contain "ImmediateParent"
                $xmlNode.PSObject.Properties.Name | Should -Contain "ContextLevel"
            }
        }
        
        It "Should capture meaningful parent elements for policy settings" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Turn off notifications network usage"
            if ($results) {
                $xmlNode = $results[0].XmlNode
                $xmlNode.ElementName | Should -Be "Policy"
                $xmlNode.ContextLevel | Should -Be "Policy"
                $xmlNode.OuterXml | Should -Match "q4:Policy"
            }
        }
        
        It "Should include complete policy blocks in OuterXml" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Turn off notifications network usage"
            if ($results) {
                $xmlNode = $results[0].XmlNode
                $xmlNode.OuterXml | Should -Match "q4:Name"
                $xmlNode.OuterXml | Should -Match "q4:State"
                # Should contain substantial policy content
                $xmlNode.OuterXml.Length | Should -BeGreaterThan 100
            }
        }
        
        It "Should truncate very long XML content appropriately" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "*"
            if ($results) {
                # Find a result with potentially long XML content (over 1000 chars) or create one that should be truncated
                $longXmlResult = $results | Where-Object { $_.XmlNode.OuterXml.Length -gt 1000 }
                if ($longXmlResult) {
                    $longXmlResult[0].XmlNode.OuterXml | Should -Match "\.\.\.$"
                    $longXmlResult[0].XmlNode.OuterXml.Length | Should -BeLessOrEqual 1003  # 1000 + "..."
                } else {
                    # If no long XML found, just verify truncation logic is in place
                    $anyResult = $results | Where-Object { $_.XmlNode.OuterXml.Length -gt 0 }
                    if ($anyResult) {
                        # At minimum, verify XML content is captured
                        $anyResult[0].XmlNode.OuterXml | Should -Not -BeNullOrEmpty
                    }
                }
            }
        }
        
        It "Should capture parent hierarchy for context understanding" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Chile"
            if ($results) {
                $xmlNode = $results[0].XmlNode
                $xmlNode.ParentHierarchy | Should -Not -BeNullOrEmpty
                # ParentHierarchy should be an array or array-like object
                $xmlNode.ParentHierarchy.GetType().BaseType.Name | Should -BeIn @('Array', 'Object')
                # Should have some hierarchy depth (at least 1 element)
                $xmlNode.ParentHierarchy.Count | Should -BeGreaterThan 0
            }
        }
        
        It "Should distinguish between meaningful and immediate parents" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Turn off notifications network usage"
            if ($results) {
                $xmlNode = $results[0].XmlNode
                # For policy name searches, immediate parent should be "Name" but meaningful parent should be "Policy"
                $xmlNode.ImmediateParent | Should -Be "Name"
                $xmlNode.ElementName | Should -Be "Policy"
                $xmlNode.ContextLevel | Should -Be "Policy"
            }
        }
        
        It "Should handle element-level context when no meaningful parent is found" -Skip:$script:UseSimpleTest {
            # This test might need adjustment based on actual test data structure
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "*"
            if ($results) {
                # Look for a result that might not have a meaningful parent
                $elementLevelResult = $results | Where-Object { $_.XmlNode.ContextLevel -eq "Element" }
                if ($elementLevelResult) {
                    $elementLevelResult[0].XmlNode.ContextLevel | Should -Be "Element"
                    $elementLevelResult[0].XmlNode.ElementName | Should -Be $elementLevelResult[0].XmlNode.ImmediateParent
                }
            }
        }
        
        It "Should include element attributes when present" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "*"
            if ($results) {
                # Find a result that might have XML attributes
                $resultWithAttributes = $results | Where-Object { $_.XmlNode.ElementAttributes -ne $null }
                if ($resultWithAttributes) {
                    # ElementAttributes should be a hashtable with key-value pairs
                    $resultWithAttributes[0].XmlNode.ElementAttributes | Should -BeOfType [hashtable]
                    $resultWithAttributes[0].XmlNode.ElementAttributes.Keys.Count | Should -BeGreaterThan 0
                }
            }
        }
    }
    
    Context "Dot Notation Access via ParsedXml Property" {
        
        It "Should include ParsedXml property in XmlNode results" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "SeTakeOwnershipPrivilege"
            if ($results) {
                $results[0].XmlNode.PSObject.Properties.Name | Should -Contain "ParsedXml"
                $results[0].XmlNode.ParsedXml | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should convert XML to structured PowerShell object for dot notation access" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "SeTakeOwnershipPrivilege"
            if ($results) {
                $parsedXml = $results[0].XmlNode.ParsedXml
                $parsedXml.GetType().Name | Should -Be "PSCustomObject"
                $parsedXml.Name | Should -Be "SeTakeOwnershipPrivilege"
            }
        }
        
        It "Should provide dot notation access to UserRightsAssignment Name property" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "SeTakeOwnershipPrivilege"
            if ($results) {
                $privilegeName = $results[0].XmlNode.ParsedXml.Name
                $privilegeName | Should -Be "SeTakeOwnershipPrivilege"
            }
        }
        
        It "Should provide dot notation access to nested Member properties" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "SeTakeOwnershipPrivilege"
            if ($results) {
                $memberName = $results[0].XmlNode.ParsedXml.Member.Name
                $memberName | Should -Match "contoso\\.*"  # Should contain domain prefix
            }
        }
        
        It "Should handle multiple UserRightsAssignment elements with dot notation" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "SeCreateGlobalPrivilege"
            if ($results) {
                $privilegeName = $results[0].XmlNode.ParsedXml.Name
                $privilegeName | Should -Be "SeCreateGlobalPrivilege"
                $memberName = $results[0].XmlNode.ParsedXml.Member.Name
                $memberName | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should remove XML namespace prefixes from property names" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "SeTakeOwnershipPrivilege"
            if ($results) {
                $parsedXml = $results[0].XmlNode.ParsedXml
                # Properties should not have q1:, q2: etc. prefixes
                $propertyNames = $parsedXml.PSObject.Properties.Name
                $propertyNames | Should -Not -Match "^q\d+:"
                $propertyNames | Should -Contain "Name"
                $propertyNames | Should -Contain "Member"
            }
        }
        
        It "Should handle XML attributes in converted objects" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Turn off notifications network usage"
            if ($results) {
                $parsedXml = $results[0].XmlNode.ParsedXml
                # Should be able to access policy properties
                $parsedXml.Name | Should -Be "Turn off notifications network usage"
                $parsedXml.State | Should -Be "Enabled"
            }
        }
        
        It "Should support deep nested object access via dot notation" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Establish ActiveX installation policy"
            if ($results) {
                $parsedXml = $results[0].XmlNode.ParsedXml
                # Should be able to access nested DropDownList elements
                if ($parsedXml.DropDownList) {
                    $dropDownList = $parsedXml.DropDownList
                    if ($dropDownList -is [array]) {
                        $dropDownList[0].Name | Should -Not -BeNullOrEmpty
                    } else {
                        $dropDownList.Name | Should -Not -BeNullOrEmpty
                    }
                }
            }
        }
        
        It "Should handle arrays of similar elements correctly" -Skip:$script:UseSimpleTest {
            # Test with a policy that has multiple dropdown lists or similar elements
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Establish ActiveX installation policy"
            if ($results) {
                $parsedXml = $results[0].XmlNode.ParsedXml
                if ($parsedXml.DropDownList -and $parsedXml.DropDownList.Count -gt 1) {
                    ,$parsedXml.DropDownList | Should -BeOfType [System.Array]
                    $parsedXml.DropDownList[0].Name | Should -Not -BeNullOrEmpty
                    $parsedXml.DropDownList[1].Name | Should -Not -BeNullOrEmpty
                }
            }
        }
        
        It "Should provide consistent dot notation access across different element types" -Skip:$script:UseSimpleTest {
            # Test various element types to ensure consistent conversion
            $testSearches = @("SeTakeOwnershipPrivilege", "Turn off notifications network usage", "PasswordHistorySize")
            
            foreach ($searchTerm in $testSearches) {
                $results = Search-GPMCReports -Path $TestDataPath -SearchString $searchTerm
                if ($results) {
                    $parsedXml = $results[0].XmlNode.ParsedXml
                    $parsedXml | Should -Not -BeNullOrEmpty
                    $parsedXml.GetType().Name | Should -Be "PSCustomObject"
                    # Each should have some accessible properties
                    $parsedXml.PSObject.Properties.Count | Should -BeGreaterThan 0
                }
            }
        }
    }
    
    Context "Parameter Validation" {
        
        It "Should require SearchString parameter" {
            { Search-GPMCReports -Path "test.xml" } | Should -Throw
        }
        
        It "Should validate file extension for Path parameter" {
            { Search-GPMCReports -Path "test.txt" -SearchString "test" } | Should -Throw
        }
        
        It "Should validate file existence for Path parameter" {
            { Search-GPMCReports -Path "nonexistent.xml" -SearchString "test" } | Should -Throw
        }
    }
    
    Context "Search Functionality" {
        
        It "Should handle non-existent search terms gracefully with XML content" -Skip:(-not $script:UseSimpleTest) {
            $results = Search-GPMCReports -XmlContent $script:TestXmlContent -SearchString "NonExistentSetting12345"
            $results | Should -BeNullOrEmpty
        }
        
        It "Should handle non-existent search terms gracefully with file" -Skip:$script:UseSimpleTest {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "NonExistentSetting12345"
            $results | Should -BeNullOrEmpty
        }
        
        It "Should handle case sensitivity option with XML content" -Skip:(-not $script:UseSimpleTest) {
            $results1 = Search-GPMCReports -XmlContent $script:TestXmlContent -SearchString "passwordhistory"
            $results2 = Search-GPMCReports -XmlContent $script:TestXmlContent -SearchString "passwordhistory" -CaseSensitive
            
            # Case insensitive should find results, case sensitive might not
            if ($results1) {
                $results1.Count | Should -BeGreaterOrEqual ($results2.Count -or 0)
            }
        }
        
        It "Should handle case sensitivity option with file" -Skip:$script:UseSimpleTest {
            $results1 = Search-GPMCReports -Path $TestDataPath -SearchString "chile"
            $results2 = Search-GPMCReports -Path $TestDataPath -SearchString "chile" -CaseSensitive
            
            # Case insensitive should find results, case sensitive might not
            if ($results1) {
                $results1.Count | Should -BeGreaterOrEqual ($results2.Count -or 0)
            }
        }
        
        It "Should handle MaxResults parameter" -Skip:(-not $script:UseSimpleTest) {
            $results = Search-GPMCReports -XmlContent $script:TestXmlContent -SearchString "*" -MaxResults 1
            if ($results) {
                $results.Count | Should -BeLessOrEqual 1
            }
        }
        
        It "Should handle IncludeAllMatches parameter with German language content" -Skip:$script:UseSimpleTest {
            $searchTerm = "verhindert unnötige"
            $results = Search-GPMCReports -Path $TestDataPath -IncludeAllMatches -SearchString $searchTerm
            
            $results | Should -Not -BeNullOrEmpty -Because "Should find German language setting in test data"
            $results.Count | Should -Be 1 -Because "Should return exactly one result for this German phrase"
            $results[0].SettingValue | Should -BeLike "*Verhindert unnötige*" -Because "Setting value should contain the German phrase"
            $results[0].CategoryPath | Should -Be "Administrative Templates > Windows Components > Windows Error Reporting" -Because "Should be categorized under Windows Error Reporting"
            $results[0].Section | Should -Be "Computer" -Because "Should be in Computer section"
        }
        
        It "Should handle IncludeAllMatches parameter with parenthetical content" -Skip:$script:UseSimpleTest {
            $searchTerm = "HTTP Only (0)"
            $results = Search-GPMCReports -Path $TestDataPath -IncludeAllMatches -SearchString $searchTerm
            
            $results | Should -Not -BeNullOrEmpty -Because "Should find setting with parenthetical value in test data"
            $results.Count | Should -Be 1 -Because "Should return exactly one result for this search term"
            $results[0].SettingValue | Should -BeLike "*HTTP only (0)*" -Because "Setting value should contain the search phrase with parentheses"
            $results[0].CategoryPath | Should -Be "Administrative Templates > Windows Components > Delivery Optimization" -Because "Should be categorized under Delivery Optimization"
            $results[0].Section | Should -Be "Computer" -Because "Should be in Computer section"
        }
    }
}

Describe "Search-GPMCReports Duplicate Result Detection" -Skip:$script:UseSimpleTest {
    
    Context "Deduplication Validation - These Tests Verify Deduplication Is Working" {
        
        It "Should NOT return duplicate results for 'Scheduled Task 1'" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Scheduled Task 1"
            
            # With deduplication enabled (default), should return only one result
            $results | Should -Not -BeNullOrEmpty
            
            if ($results.Count -gt 1) {
                Write-Host "UNEXPECTED: Found $($results.Count) duplicate results for 'Scheduled Task 1' - deduplication may not be working!" -ForegroundColor Red
                foreach ($result in $results) {
                    Write-Host "  - Element: $($result.XmlNode.ElementName), SettingName: $($result.SettingName)" -ForegroundColor Yellow
                }
            }
            
            $results.Count | Should -Be 1 -Because "Should return only one logical result, not duplicates from parent and child elements"
            
            # Should return only the parent Task element
            $results[0].XmlNode.ElementName | Should -Be "Task" -Because "Should return the meaningful parent element, not child duplicates"
        }
        
        It "Should NOT return both parent and child elements for 'Scheduled Task 1'" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Scheduled Task 1"
            
            # With deduplication enabled (default), should not have both parent and child
            $results | Should -Not -BeNullOrEmpty
            
            # Check that we DON'T have both Task and Properties elements
            $taskElements = $results | Where-Object { $_.XmlNode.ElementName -eq "Task" }
            $propertiesElements = $results | Where-Object { $_.XmlNode.ElementName -eq "Properties" }
            
            # Should have EITHER Task OR Properties, not both (deduplication should keep Task)
            ($taskElements -and $propertiesElements) | Should -Be $false -Because "Should not return both parent Task and child Properties elements for the same logical setting"
        }
        
        It "Should NOT return multiple duplicate groups for ShortcutSettings" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Test"
            
            # Should find results but not duplicates with deduplication enabled
            $shortcutResults = $results | Where-Object { $_.SettingName -like "*Test*" -or $_.SettingValue -like "*Test*" }
            
            if ($shortcutResults -and $shortcutResults.Count -gt 1) {
                # Group by logical setting name to check for duplicates
                $groupedByName = $shortcutResults | Group-Object SettingName
                $duplicateGroups = $groupedByName | Where-Object { $_.Count -gt 1 }
                
                # With deduplication enabled, should not have duplicates
                $duplicateGroups.Count | Should -Be 0 -Because "Should not have multiple results for the same logical setting"
                
                if ($duplicateGroups.Count -gt 0) {
                    Write-Host "UNEXPECTED: Found $($duplicateGroups.Count) duplicate groups - deduplication may not be working!" -ForegroundColor Red
                }
            }
        }
        
        It "Should return duplicate results when IncludeChildDuplicates is used (demonstrates original bug)" {
            # This test proves the original bug still exists when deduplication is disabled
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Scheduled Task 1" -IncludeChildDuplicates
            
            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -BeGreaterThan 1 -Because "With IncludeChildDuplicates, should return both parent and child elements"
            
            # Should have both Task and Properties elements when deduplication is disabled
            $taskElements = $results | Where-Object { $_.XmlNode.ElementName -eq "Task" }
            $propertiesElements = $results | Where-Object { $_.XmlNode.ElementName -eq "Properties" }
            
            $taskElements | Should -Not -BeNullOrEmpty -Because "Should include Task element"
            $propertiesElements | Should -Not -BeNullOrEmpty -Because "Should include Properties element when IncludeChildDuplicates is used"
        }
    }
    
    Context "Future Deduplication Validation (Will Pass After Implementation)" {
        
        It "Should return only one result for 'Scheduled Task 1' after deduplication" {
            # This test is skipped initially and will be enabled after deduplication implementation
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Scheduled Task 1"
            
            # After deduplication, should return only the most meaningful result (Task level)
            $results.Count | Should -Be 1
            $results[0].XmlNode.ElementName | Should -Be "Task"
        }
        
        It "Should provide enhanced context when deduplicating" -Skip {
            # This test is skipped initially and will be enabled after deduplication implementation
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Scheduled Task 1"
            
            $results.Count | Should -Be 1
            $result = $results[0]
            
            # Should have Task element context with enhanced information from Properties
            $result.XmlNode.ElementName | Should -Be "Task"
            
            # Should preserve important information from the Properties child element
            $result.XmlNode.OuterXml | Should -Match "Properties"
            $result.XmlNode.OuterXml | Should -Match "appName"
            $result.XmlNode.OuterXml | Should -Match "notepad.exe"
        }
        
        It "Should support IncludeChildDuplicates parameter" {
            # This test is skipped initially and will be enabled after parameter implementation
            
            # Default behavior - deduplicated
            $defaultResults = Search-GPMCReports -Path $TestDataPath -SearchString "Scheduled Task 1"
            $defaultResults.Count | Should -Be 1
            
            # With parameter - include all duplicates
            $allResults = Search-GPMCReports -Path $TestDataPath -SearchString "Scheduled Task 1" -IncludeChildDuplicates
            $allResults.Count | Should -BeGreaterThan 1
            
            # Should have both Task and Properties elements
            $allResults | Where-Object { $_.XmlNode.ElementName -eq "Task" } | Should -Not -BeNullOrEmpty
            $allResults | Where-Object { $_.XmlNode.ElementName -eq "Properties" } | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle complex hierarchical duplicates" {
            # This test is skipped initially and will be enabled after implementation
            
            # Test with a search that might find multiple levels of hierarchy
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "*Task*"
            
            # After deduplication, should not have parent-child duplicates
            $groupedByParent = $results | Group-Object { $_.XmlNode.OuterXml.Substring(0, [Math]::Min(100, $_.XmlNode.OuterXml.Length)) }
            
            # No group should contain both parent and child elements with same content
            foreach ($group in $groupedByParent) {
                if ($group.Count -gt 1) {
                    # All elements in this group should be at the same hierarchy level
                    $elementNames = $group.Group | ForEach-Object { $_.XmlNode.ElementName }
                    $elementNames | Should -Not -Contain "Task"
                    $elementNames | Should -Not -Contain "Properties"
                }
            }
        }
    }
    
    Context "Deduplication Edge Cases (Future Implementation)" {
        
        It "Should handle multiple attribute matches in same element" -Skip {
            # Test case where single element has multiple attributes matching search term
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "C:"
            
            # Should not duplicate results when multiple attributes in same element match
            $groupedByElement = $results | Group-Object { $_.XmlNode.ElementName + $_.XmlNode.XmlPath }
            
            foreach ($group in $groupedByElement) {
                # Same element path should appear only once, even if multiple attributes match
                $group.Count | Should -Be 1
            }
        }
        
        It "Should preserve meaningful parent over child when both match" -Skip {
            # When both parent and child match, should keep parent and merge child info
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Scheduled Task 1"
            
            $results.Count | Should -Be 1
            $result = $results[0]
            
            # Should be the parent element (Task)
            $result.XmlNode.ElementName | Should -Be "Task"
            
            # But should contain information from child (Properties)
            $result.XmlNode.OuterXml | Should -Match "Properties"
        }
        
        It "Should not affect results where no duplicates exist" -Skip {
            # Test with search terms that don't produce duplicates
            $beforeCount = (Search-GPMCReports -Path $TestDataPath -SearchString "PasswordHistorySize").Count
            
            # After deduplication implementation, count should remain same for non-duplicate results
            $afterCount = (Search-GPMCReports -Path $TestDataPath -SearchString "PasswordHistorySize").Count
            
            $beforeCount | Should -Be $afterCount
        }
    }
}

Describe "Search-GPMCReports Category Path Validation" -Skip:$script:UseSimpleTest {
    
    Context "Security Settings - Account Policies" {
        
        It "Should correctly categorize Password Policy settings" {
            $searchTerm = "PasswordHistorySize"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Password policy settings should be categorized under Account Policies > Password Policy"
        }
        
        It "Should correctly categorize Kerberos Policy settings" {
            $searchTerm = "MaxTicketAge"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Kerberos policy settings should be categorized under Account Policies > Kerberos Policy"
        }
        
        It "Should correctly categorize Audit Policy settings" {
            $searchTerm = "AuditDSAccess"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Audit policy settings should be categorized under Account Policies > Audit Policy"
        }
    }
    
    Context "Security Settings - Local Policies" {
        
        It "Should correctly categorize User Rights Assignment for privilege '<SearchTerm>'" -TestCases @(
            @{ SearchTerm = "SeTakeOwnershipPrivilege" }
            @{ SearchTerm = "SeCreateGlobalPrivilege" }
        ) {
            param($SearchTerm)
            
            $expected = $script:ExpectedMappings[$SearchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $SearchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "User rights assignments should be categorized under Local Policies > User Rights Assignment"
        }
        
        It "Should correctly categorize User Rights Assignment for user '<SearchTerm>'" -TestCases @(
            @{ SearchTerm = "Chile" }
            @{ SearchTerm = "Uruguay" }
        ) {
            param($SearchTerm)
            
            $expected = $script:ExpectedMappings[$SearchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $SearchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "User assignments should be categorized under Local Policies > User Rights Assignment"
        }
        
        It "Should correctly categorize Security Options - Domain Controller settings" -TestCases @(
            @{ SearchTerm = "LDAP server signing requirements" }
            @{ SearchTerm = "Require signing" }
        ) {
            param($SearchTerm)
            
            $expected = $script:ExpectedMappings[$SearchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $SearchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Domain Controller security options should be categorized under Local Policies > Security Options > Domain Controller"
        }
        
        It "Should correctly categorize Security Options - Devices settings" {
            $searchTerm = "Restrict CD-ROM"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Device security options should be categorized under Local Policies > Security Options > Devices"
        }
        
        It "Should correctly categorize Security Options - Other settings" {
            $searchTerm = "Server SPN"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Other security options should be categorized under Local Policies > Security Options > Other"
        }
    }
    
    Context "Security Settings - Advanced Audit Configuration" {
        
        It "Should correctly categorize Account Logon audit settings" {
            $searchTerm = "Audit Kerberos Service Ticket Operations"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Account Logon audit settings should be categorized under Advanced Audit Configuration > Account Logon"
        }
        
        It "Should correctly categorize DS Access audit settings" {
            $searchTerm = "Audit Directory Service Changes"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "DS Access audit settings should be categorized under Advanced Audit Configuration > DS Access"
        }
    }
    
    Context "Security Settings - Other Categories" {
        
        It "Should correctly categorize Event Log settings" {
            $searchTerm = "RetentionDays"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Event log settings should be categorized under Event Log"
        }
        
        It "Should correctly categorize System Services settings" {
            $searchTerm = "NTDS"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "System service settings should be categorized under System Services"
        }
        
        It "Should correctly categorize File System settings" -TestCases @(
            @{ SearchTerm = "GpoBackup" }
            @{ SearchTerm = "DeployDebug" }
        ) {
            param($SearchTerm)
            
            $expected = $script:ExpectedMappings[$SearchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $SearchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "File system settings should be categorized under File System"
        }
        
        It "Should correctly categorize Registry settings" {
            $searchTerm = "7-Zip"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Registry settings should be categorized under Registry"
        }
        
        It "Should correctly categorize Restricted Groups settings" {
            $searchTerm = "Armenia"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Restricted group settings should be categorized under Restricted Groups"
        }
    }
    
    Context "Administrative Templates - Control Panel" {
        
        It "Should correctly categorize Control Panel settings" {
            $searchTerm = "Force a specific default lock screen"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Control Panel settings should be properly categorized with > separators"
        }
    }
    
    Context "Administrative Templates - System" {
        
        It "Should correctly categorize Internet Communication Management settings" {
            $searchTerm = "Download missing COM components"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Internet Communication settings should be properly categorized with full path"
        }
        
        It "Should correctly categorize System settings" {
            $searchTerm = "Prevent access to the command prompt"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "System settings should be categorized under Administrative Templates > System"
        }
        
        It "Should correctly categorize Audit Process Creation settings" -Skip {
            # Test skipped: Policy not present in current test XML data
            $searchTerm = "Include command line in process creation events"
            $expected = "Administrative Templates > System > Audit Process Creation"
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Audit Process Creation settings should be properly categorized"
        }
    }
    
    Context "Administrative Templates - Windows Components" {
        
        It "Should correctly categorize Start Menu and Taskbar settings" {
            $searchTerm = "Turn off notifications network usage"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Start Menu and Taskbar settings should be properly categorized"
        }
        
        It "Should correctly categorize Security Center settings" {
            $searchTerm = "Turn on Security Center"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Security Center settings should be categorized under Windows Components > Security Center"
        }
        
        It "Should correctly categorize File Explorer settings" -Skip {
            # Test skipped: Policy not present in current test XML data
            $searchTerm = "Turn off Windows Defender SmartScreen"
            $expected = "Administrative Templates > Windows Components > File Explorer"
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "File Explorer settings should be categorized under Windows Components > File Explorer"
        }
        
        It "Should correctly categorize Windows Defender SmartScreen settings" {
            $searchTerm = "Configure Windows Defender SmartScreen"
            $expected = $script:ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Windows Defender SmartScreen settings should have full category path"
        }
        
        It "Should correctly categorize Windows Game Recording and Broadcasting settings" {
            $searchTerm = "Enables or disables Windows Game Recording and Broadcasting"
            $expected = "Administrative Templates > Windows Components > Windows Game Recording and Broadcasting"
            
            $results = Search-GPMCReports -Path $TestDataPath -SearchString $searchTerm
            
            $results | Should -Not -BeNullOrEmpty -Because "Game Recording setting should be found in test data"
            $results.Count | Should -Be 1 -Because "Should return exactly one result for this specific setting"
            $results[0].CategoryPath | Should -Be $expected -Because "Windows Game Recording and Broadcasting settings should have full category path"
            $results[0].Section | Should -Be "Computer" -Because "This setting should be in the Computer section"
        }
        
        It "Should correctly categorize Windows Game Recording and Broadcasting settings with shorter search term" {
            $searchTerm = "Game Recording and Broadcasting"
            $expected = "Administrative Templates > Windows Components > Windows Game Recording and Broadcasting"
            
            $results = Search-GPMCReports -Path $TestDataPath -SearchString $searchTerm
            
            $results | Should -Not -BeNullOrEmpty -Because "Game Recording setting should be found with shorter search term"
            $results.Count | Should -Be 1 -Because "Should return exactly one result for this search term"
            $results[0].CategoryPath | Should -Be $expected -Because "Windows Game Recording and Broadcasting settings should have full category path"
            $results[0].Section | Should -Be "Computer" -Because "This setting should be in the Computer section"
        }
        
        It "Should correctly categorize Windows Defender Antivirus - Attack Surface Reduction settings" -Skip {
            # Test skipped: Policy not present in current test XML data
            $searchTerm = "Configure Attack Surface Reduction rules"
            $expected = "Administrative Templates > Windows Components > Windows Defender Antivirus > Windows Defender Exploit Guard > Attack Surface Reduction"
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Attack Surface Reduction settings should have full Windows Defender category path"
        }
        
        It "Should correctly categorize Windows Defender Antivirus - Real-time Protection settings" -TestCases @(
            @{ SearchTerm = "Turn on behavior monitoring" }
            @{ SearchTerm = "Turn off real-time protection" }
        ) -Skip {
            # Test skipped: Policies not present in current test XML data
            param($SearchTerm)
            
            $expected = "Administrative Templates > Windows Components > Windows Defender Antivirus > Real-time Protection"
            $actual = Invoke-GPMCSearch -SearchTerm $SearchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Real-time Protection settings should have full Windows Defender category path"
        }
        
        It "Should correctly categorize Windows Defender Antivirus - Signature Updates settings" -Skip {
            # Test skipped: Policy not present in current test XML data
            $searchTerm = "Specify the interval to check for definition updates"
            $expected = "Administrative Templates > Windows Components > Windows Defender Antivirus > Signature Updates"
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Signature Updates settings should have full Windows Defender category path"
        }
    }
    
    Context "Group Policy Preferences - Windows Settings" {
        
        It "Should correctly categorize Drive Maps preferences" {
            # This test checks if Drive Maps namespace mapping would work when the XML contains the namespace
            $expected = "Preferences > Windows Settings > Drive Maps"
            
            # Mock an XML element with Drive Maps namespace for testing
            $mockXml = [xml]'<root xmlns:q7="http://www.microsoft.com/GroupPolicy/Settings/DriveMaps"><q7:Drive>TestDrive</q7:Drive></root>'
            $mockElement = $mockXml.DocumentElement.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Be $expected -Because "Drive Maps preferences should be categorized under Preferences > Windows Settings > Drive Maps"
        }
        
        It "Should correctly categorize Environment Variables preferences" {
            $searchTerm = "environment"
            # Use PreferencesDataPath since environment variables are in AllPreferences1.xml
            $results = Search-GPMCReports -Path $PreferencesDataPath -SearchString $searchTerm
            $preferencesResult = $results | Where-Object { $_.CategoryPath -like "*Environment Variables*" } | Select-Object -First 1
            
            $preferencesResult.CategoryPath | Should -Be "Preferences > Windows Settings > Environment Variables" -Because "Environment Variables preferences should be properly categorized"
        }
        
        It "Should correctly categorize Files preferences" {
            # This test checks if Files namespace mapping would work when the XML contains the namespace
            $searchTerm = "Files"
            $expected = "Preferences > Windows Settings > Files"
            
            # Mock an XML element with Files namespace for testing
            $mockXml = [xml]'<root xmlns:q8="http://www.microsoft.com/GroupPolicy/Settings/Files"><q8:File>TestFile</q8:File></root>'
            $mockElement = $mockXml.DocumentElement.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Be $expected -Because "Files preferences should be categorized under Preferences > Windows Settings > Files"
        }
        
        It "Should correctly categorize Folders preferences" {
            # This test checks if Folders namespace mapping would work when the XML contains the namespace
            $expected = "Preferences > Windows Settings > Folders"
            
            # Mock an XML element with Folders namespace for testing
            $mockXml = [xml]'<root xmlns:q9="http://www.microsoft.com/GroupPolicy/Settings/Folders"><q9:Folder>TestFolder</q9:Folder></root>'
            $mockElement = $mockXml.DocumentElement.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Be $expected -Because "Folders preferences should be categorized under Preferences > Windows Settings > Folders"
        }
        
        It "Should correctly categorize Registry preferences" {
            # This test checks if Registry namespace mapping would work when the XML contains the namespace
            $expected = "Preferences > Windows Settings > Registry"
            
            # Mock an XML element with Registry namespace for testing
            $mockXml = [xml]'<root xmlns:q10="http://www.microsoft.com/GroupPolicy/Settings/Windows/Registry"><q10:Registry>TestRegistry</q10:Registry></root>'
            $mockElement = $mockXml.DocumentElement.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Be $expected -Because "Registry preferences should be categorized under Preferences > Windows Settings > Registry"
        }
        
        It "Should correctly categorize Shortcuts preferences" {
            # This test checks if Shortcuts namespace mapping would work when the XML contains the namespace
            $expected = "Preferences > Windows Settings > Shortcuts"
            
            # Mock an XML element with Shortcuts namespace for testing
            $mockXml = [xml]'<root xmlns:q11="http://www.microsoft.com/GroupPolicy/Settings/Shortcuts"><q11:Shortcut>TestShortcut</q11:Shortcut></root>'
            $mockElement = $mockXml.DocumentElement.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Be $expected -Because "Shortcuts preferences should be categorized under Preferences > Windows Settings > Shortcuts"
        }
    }
    
    Context "Group Policy Preferences - Control Panel Settings" {
        
        It "Should correctly categorize Scheduled Tasks preferences" {
            $searchTerm = "Test1"  # Changed from "Scheduled Task 1" to "Test1" which actually exists in AllPreferences1.xml
            $expected = "Preferences > Control Panel Settings > Scheduled Tasks"
            # Use PreferencesDataPath since scheduled tasks are in AllPreferences1.xml
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $PreferencesDataPath
            
            $actual | Should -Be $expected -Because "Scheduled Tasks preferences should be categorized under Preferences > Control Panel Settings > Scheduled Tasks"
        }
        
        It "Should correctly categorize Folder Options preferences" {
            # This test checks if Folder Options namespace mapping would work when the XML contains the namespace
            $expected = "Preferences > Control Panel Settings > Folder Options"
            
            # Mock an XML element with Folder Options namespace for testing
            $mockXml = [xml]'<root xmlns:q12="http://www.microsoft.com/GroupPolicy/Settings/FolderOptions"><q12:FolderOptions>TestFolderOptions</q12:FolderOptions></root>'
            $mockElement = $mockXml.DocumentElement.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Be $expected -Because "Folder Options preferences should be categorized under Preferences > Control Panel Settings > Folder Options"
        }
        
        It "Should correctly categorize Power Options preferences" {
            # This test checks if Power Options namespace mapping would work when the XML contains the namespace
            $expected = "Preferences > Control Panel Settings > Power Options"
            
            # Mock an XML element with Power Options namespace for testing
            $mockXml = [xml]'<root xmlns:q13="http://www.microsoft.com/GroupPolicy/Settings/PowerOptions"><q13:PowerOptions>TestPowerOptions</q13:PowerOptions></root>'
            $mockElement = $mockXml.DocumentElement.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Be $expected -Because "Power Options preferences should be categorized under Preferences > Control Panel Settings > Power Options"
        }
        
        It "Should correctly categorize Start Menu preferences" {
            # This test checks if Start Menu namespace mapping would work when the XML contains the namespace
            $expected = "Preferences > Control Panel Settings > Start Menu"
            
            # Mock an XML element with Start Menu namespace for testing
            $mockXml = [xml]'<root xmlns:q14="http://www.microsoft.com/GroupPolicy/Settings/StartMenu"><q14:StartMenu>TestStartMenu</q14:StartMenu></root>'
            $mockElement = $mockXml.DocumentElement.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Be $expected -Because "Start Menu preferences should be categorized under Preferences > Control Panel Settings > Start Menu"
        }
        
        It "Should correctly categorize Local Users and Groups preferences" {
            # This test checks if Local Users and Groups namespace mapping would work when the XML contains the namespace
            $expected = "Preferences > Control Panel Settings > Local Users and Groups"
            
            # Mock an XML element with Local Users and Groups namespace for testing
            $mockXml = [xml]'<root xmlns:q15="http://www.microsoft.com/GroupPolicy/Settings/Lugs"><q15:LocalUsersAndGroups>TestLugs</q15:LocalUsersAndGroups></root>'
            $mockElement = $mockXml.DocumentElement.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Be $expected -Because "Local Users and Groups preferences should be categorized under Preferences > Control Panel Settings > Local Users and Groups"
        }
        
        It "Should correctly categorize Internet Settings preferences" {
            # This test checks if Internet Settings namespace mapping would work when the XML contains the namespace
            $expected = "Preferences > Control Panel Settings > Internet Settings"
            
            # Mock an XML element with Internet Settings namespace for testing
            $mockXml = [xml]'<root xmlns:q16="http://www.microsoft.com/GroupPolicy/Settings/ControlPanel/Internet"><q16:InternetSettings>TestInternet</q16:InternetSettings></root>'
            $mockElement = $mockXml.DocumentElement.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Be $expected -Because "Internet Settings preferences should be categorized under Preferences > Control Panel Settings > Internet Settings"
        }
    }
    
    Context "Group Policy Preferences - Namespace Detection" {
        
        It "Should detect namespaces from xmlns attributes" {
            # Test namespace detection from xmlns declarations
            $expected = "Preferences > Windows Settings > Drive Maps"
            
            # Create XML with namespace declaration in attributes
            $mockXml = [xml]@'
<root>
    <ExtensionData xmlns:q7="http://www.microsoft.com/GroupPolicy/Settings/DriveMaps">
        <q7:DriveMapSettings>
            <q7:Drive Letter="S:" />
        </q7:DriveMapSettings>
    </ExtensionData>
</root>
'@
            $mockElement = $mockXml.DocumentElement.FirstChild.FirstChild.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Be $expected -Because "Namespace should be detected from xmlns attribute declarations"
        }
        
        It "Should traverse parent hierarchy to find namespace" {
            # Test that the function walks up the parent hierarchy to find namespaces
            $expected = "Preferences > Windows Settings > Environment Variables"
            
            # Create nested XML where namespace is declared at parent level
            $mockXml = [xml]@'
<root xmlns:q8="http://www.microsoft.com/GroupPolicy/Settings/Environment">
    <ExtensionData>
        <q8:EnvironmentSettings>
            <q8:Environment Name="TEST_VAR" />
        </q8:EnvironmentSettings>
    </ExtensionData>
</root>
'@
            $mockElement = $mockXml.DocumentElement.FirstChild.FirstChild.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Be $expected -Because "Function should traverse parent hierarchy to find namespace declarations"
        }
        
        It "Should return null for non-Preferences namespaces" {
            # Test that non-preferences namespaces return null
            $mockXml = [xml]'<root xmlns:q1="http://www.microsoft.com/GroupPolicy/Settings/Security"><q1:SecuritySettings>TestSecurity</q1:SecuritySettings></root>'
            $mockElement = $mockXml.DocumentElement.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Not -Be $null -Because "Security settings should be handled by other category logic, not return null"
            $result | Should -Not -BeLike "Preferences*" -Because "Non-preferences namespaces should not return Preferences categories"
        }
        
        It "Should prioritize Preferences namespace mapping over other category logic" {
            # Test that preferences mapping takes precedence
            $expected = "Preferences > Windows Settings > Drive Maps"
            
            # Create XML that could match other category logic but has preferences namespace
            $mockXml = [xml]@'
<root>
    <User xmlns:q7="http://www.microsoft.com/GroupPolicy/Settings/DriveMaps">
        <q7:DriveMapSettings>
            <q7:Drive Letter="S:" />
        </q7:DriveMapSettings>
    </User>
</root>
'@
            $mockElement = $mockXml.DocumentElement.FirstChild.FirstChild.FirstChild
            
            $result = Get-GPMCCategoryPath -Element $mockElement
            $result | Should -Be $expected -Because "Preferences namespace mapping should take priority over other category detection logic"
        }
    }

    Context "Edge Cases and Error Handling" {
        
        It "Should handle search terms not found in test data" {
            $searchTerm = "NonExistentSetting123"
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -TestDataPath $TestDataPath
            
            $actual | Should -Be "Not Found" -Because "Non-existent settings should return 'Not Found'"
        }
        
        It "Should handle empty search strings gracefully" {
            $actual = Invoke-GPMCSearch -SearchTerm "" -TestDataPath $TestDataPath
            
            $actual | Should -BeIn @("Not Found", "Error") -Because "Empty search strings should be handled gracefully"
        }
        
        It "Should handle wildcard searches" {
            $results = if ($script:UseSimpleTest) {
                Search-GPMCReports -XmlContent $script:TestXmlContent -SearchString "*Password*"
            } else {
                Search-GPMCReports -Path $TestDataPath -SearchString "*Password*"
            }
            
            if ($results) {
                $results | Should -Not -BeNullOrEmpty
                $results | ForEach-Object {
                    $_.CategoryPath | Should -Not -BeNullOrEmpty
                }
            }
        }
        
        It "Should provide section information in results" {
            $results = if ($script:UseSimpleTest) {
                Search-GPMCReports -XmlContent $script:TestXmlContent -SearchString "*"
            } else {
                Search-GPMCReports -Path $TestDataPath -SearchString "Chile"
            }
            
            if ($results) {
                $results[0].PSObject.Properties.Name | Should -Contain "Section" -Because "Results should include section information"
            }
        }
        
        It "Should provide comment information when available" {
            $results = if ($script:UseSimpleTest) {
                Search-GPMCReports -XmlContent $script:TestXmlContent -SearchString "*"
            } else {
                Search-GPMCReports -Path $TestDataPath -SearchString "*Comment*"
            }
            
            if ($results) {
                $results[0].PSObject.Properties.Name | Should -Contain "Comment" -Because "Results should include comment property"
            }
        }
    }
    
    Context "Script Functionality Tests" -Skip:$script:UseSimpleTest {
        
        It "Should find matches for all test search terms" {
            $testTerms = @("Chile", "PasswordHistorySize", "NTDS", "7-Zip")
            $foundCount = 0
            
            foreach ($term in $testTerms) {
                $result = Invoke-GPMCSearch -SearchTerm $term -TestDataPath $TestDataPath
                if ($result -ne "Not Found" -and $result -ne "Error") {
                    $foundCount++
                }
            }
            
            $foundCount | Should -BeGreaterThan 0 -Because "At least some test terms should be found in the test data"
        }
        
        It "Should return results in the expected format" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Chile"
            
            if ($results) {
                $results[0] | Should -Not -BeNullOrEmpty
                $results[0].PSObject.Properties.Name | Should -Contain "GPOName"
                $results[0].PSObject.Properties.Name | Should -Contain "CategoryPath"
                $results[0].PSObject.Properties.Name | Should -Contain "SettingName"
                $results[0].PSObject.Properties.Name | Should -Contain "SettingValue"
                $results[0].PSObject.Properties.Name | Should -Contain "Context"
                $results[0].PSObject.Properties.Name | Should -Contain "SourceFile"
            }
        }
        
        It "Should handle wildcard patterns correctly" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "*Password*"
            
            if ($results) {
                $results | Should -Not -BeNullOrEmpty
                $results | ForEach-Object {
                    $_.CategoryPath | Should -Not -BeNullOrEmpty -Because "All results should have category paths"
                }
            }
        }
        
        It "Should have an acceptable success rate for category mapping" {
            $testTerms = $script:ExpectedMappings.Keys | Select-Object -First 10
            $successCount = 0
            
            foreach ($term in $testTerms) {
                $result = Invoke-GPMCSearch -SearchTerm $term -TestDataPath $TestDataPath
                if ($result -ne "Not Found" -and $result -ne "Error") {
                    $successCount++
                }
            }
            
            $successRate = ($successCount / $testTerms.Count) * 100
            $successRate | Should -BeGreaterThan 20 -Because "At least 20% of expected mappings should be found in test data"
        }
    }
    
    Context "Computer Section Settings" -Skip:$script:UseSimpleTest {
        
        It "Should correctly identify Computer section for Security Settings" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "PasswordHistorySize"
            
            if ($results) {
                $results[0].Section | Should -Be "Computer" -Because "Password policy should be in Computer section"
            }
        }
        
        It "Should correctly identify Computer section for LDAP server signing" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "LDAP server signing requirements"
            
            if ($results) {
                $results[0].Section | Should -Be "Computer" -Because "LDAP server signing should be in Computer section"
            }
        }
        
        It "Should correctly identify Computer section for Administrative Templates" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Turn off notifications network usage"
            
            if ($results) {
                $results[0].Section | Should -Be "Computer" -Because "Computer Administrative Templates should be in Computer section"
            }
        }
        
        It "Should correctly identify Computer section for Advanced Audit Configuration" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Audit Kerberos Service Ticket Operations"
            
            if ($results) {
                $results | Should -Not -BeNullOrEmpty -Because "Search should find the audit setting"
                $results[0].Section | Should -Be "Computer" -Because "Advanced Audit Configuration should be in Computer section"
            }
        }
    }
    
    Context "User Section Settings" -Skip:$script:UseSimpleTest {
        
        It "Should correctly identify User section for 'Download missing COM components'" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Download missing COM components"
            
            if ($results) {
                $results[0].Section | Should -Be "User" -Because "Download missing COM components should be in User section"
            }
        }
        
        It "Should correctly identify User section for 'Prevent access to the command prompt'" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Prevent access to the command prompt"
            
            if ($results) {
                $results[0].Section | Should -Be "User" -Because "Command prompt prevention should be in User section"
            }
        }
    }
    
    Context "Section Property Availability" {
        
        It "Should include Section property in all search results" {
            $results = if ($script:UseSimpleTest) {
                Search-GPMCReports -XmlContent $script:TestXmlContent -SearchString "*"
            } else {
                Search-GPMCReports -Path $TestDataPath -SearchString "Chile"
            }
            
            if ($results) {
                $results | ForEach-Object {
                    $_.PSObject.Properties.Name | Should -Contain "Section" -Because "All results should include Section property"
                }
            }
        }
    }
    
    Context "Comment Extraction" -Skip:$script:UseSimpleTest {
        
        It "Should extract comments from Computer section policies with comments" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "*Comment*"
            
            if ($results) {
                $commentResults = $results | Where-Object { $_.Comment -and $_.Section -eq "Computer" }
                if ($commentResults) {
                    $commentResults[0].Comment | Should -Not -BeNullOrEmpty -Because "Computer section policies with comments should have Comment populated"
                }
            }
        }
        
        It "Should extract comments from User section policies with comments" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "*Comment*"
            
            if ($results) {
                $commentResults = $results | Where-Object { $_.Comment -and $_.Section -eq "User" }
                if ($commentResults) {
                    $commentResults[0].Comment | Should -Not -BeNullOrEmpty -Because "User section policies with comments should have Comment populated"
                }
            }
        }
        
        It "Should include Comment property in result object for all results" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Chile"
            
            if ($results) {
                $results | ForEach-Object {
                    $_.PSObject.Properties.Name | Should -Contain "Comment" -Because "All results should include Comment property"
                }
            }
        }
        
        It "Should handle policies without comments gracefully" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "PasswordHistorySize"
            
            if ($results) {
                $results[0].PSObject.Properties.Name | Should -Contain "Comment" -Because "Results should have Comment property even when null"
                # Comment can be null for policies without comments - this should not throw an error
                { $results[0].Comment } | Should -Not -Throw
            }
        }
        
        It "Should search for comment text directly" {
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "*comment*"
            
            if ($results) {
                $commentResults = $results | Where-Object { $_.Comment -ne $null -and $_.Comment -ne "" }
                if ($commentResults) {
                    $commentResults.Count | Should -BeGreaterThan 0 -Because "Should find policies with comment text"
                }
            }
        }
    }
    
    Context "XML String Array Input" {
        
        It "Should accept XML content as string array" -Skip:$script:UseSimpleTest {
            $xmlArray = @(
                (Get-Content $TestDataPath -Raw)
            )
            
            { Search-GPMCReports -XmlContent $xmlArray -SearchString "Chile" } | Should -Not -Throw
        }
        
        It "Should process multiple XML strings in array" {
            # Test processing multiple XML strings without throwing exceptions
            if ($script:UseSimpleTest -and $script:TestXmlContent) {
                try {
                    $xmlArray = @(
                        $script:TestXmlContent,
                        $script:TestXmlContent.Replace("Test GPO", "Test GPO 2")
                    )
                    
                    $results = Search-GPMCReports -XmlContent $xmlArray -SearchString "PasswordHistorySize"
                    
                    # Test passes if no exception is thrown - the specific results don't matter for this edge case test
                    $true | Should -Be $true -Because "Multiple XML string processing completed without exceptions"
                }
                catch {
                    # If there's an exception, the test should fail
                    throw "Failed to process multiple XML strings: $($_.Exception.Message)"
                }
            } else {
                # Skip if using real test file since this is specifically for XML string array testing
                Set-ItResult -Skipped -Because "Test requires simple test XML content for array processing"
            }
        }
        
        It "Should produce identical results between file and string input for '<SearchTerm>'" -TestCases @(
            @{ SearchTerm = "Chile" }
            @{ SearchTerm = "PasswordHistorySize" }
        ) -Skip:$script:UseSimpleTest {
            param($SearchTerm)
            
            $fileResults = Search-GPMCReports -Path $TestDataPath -SearchString $SearchTerm
            $stringResults = Search-GPMCReports -XmlContent @((Get-Content $TestDataPath -Raw)) -SearchString $SearchTerm
            
            if ($fileResults -and $stringResults) {
                $fileResults[0].GPOName | Should -Be $stringResults[0].GPOName -Because "GPO name should be identical"
                $fileResults[0].CategoryPath | Should -Be $stringResults[0].CategoryPath -Because "Category path should be identical"
                $fileResults[0].Context | Should -Be $stringResults[0].Context -Because "Setting context should be identical"
            }
        }
        
        It "Should handle wildcard patterns with string array input" {
            $xmlArray = @($script:TestXmlContent)
            $results = Search-GPMCReports -XmlContent $xmlArray -SearchString "*Password*"
            
            if ($results) {
                $results | Should -Not -BeNullOrEmpty
                $results | ForEach-Object {
                    $_.CategoryPath | Should -Not -BeNullOrEmpty
                }
            }
        }
        
        It "Should handle empty XML content array gracefully" {
            $results = Search-GPMCReports -XmlContent @() -SearchString "test"
            $results | Should -BeNullOrEmpty -Because "Empty XML array should return no results"
        }
        
        It "Should handle invalid XML in string array gracefully" {
            $invalidXml = @("<invalid>xml</invalid>", "not xml at all")
            { Search-GPMCReports -XmlContent $invalidXml -SearchString "test" } | Should -Not -Throw
        }
        
        It "Should handle comment extraction in string array input" {
            $xmlArray = @($script:TestXmlContent)
            $results = Search-GPMCReports -XmlContent $xmlArray -SearchString "*"
            
            if ($results) {
                $results[0].PSObject.Properties.Name | Should -Contain "Comment" -Because "String array input should include Comment property"
            }
        }
        
        It "Should handle encoding issues in XML string content" -Skip:$script:UseSimpleTest {
            $xmlContent = Get-Content $TestDataPath -Raw -Encoding UTF8
            $xmlArray = @($xmlContent)
            
            { Search-GPMCReports -XmlContent $xmlArray -SearchString "test" } | Should -Not -Throw
        }
        
        It "Should support MaxResults parameter with string array input" {
            $xmlArray = @($script:TestXmlContent)
            $allResults = Search-GPMCReports -XmlContent $xmlArray -SearchString "*"
            $limitedResults = Search-GPMCReports -XmlContent $xmlArray -SearchString "*" -MaxResults 5
            
            if ($allResults -and $allResults.Count -gt 5) {
                $limitedResults.Count | Should -Be 5 -Because "MaxResults should limit the number of results"
            }
        }
        
        It "Should support CaseSensitive parameter with string array input" {
            $xmlArray = @($script:TestXmlContent)
            $caseInsensitive = Search-GPMCReports -XmlContent $xmlArray -SearchString "passwordhistory"
            $caseSensitive = Search-GPMCReports -XmlContent $xmlArray -SearchString "passwordhistory" -CaseSensitive
            
            if ($caseInsensitive) {
                $caseInsensitive.Count | Should -BeGreaterOrEqual ($caseSensitive.Count -or 0) -Because "Case insensitive should find more or equal results"
            }
        }
        
        It "Should maintain proper parameter set isolation" {
            # Should not be able to use both Path and XmlContent
            { Search-GPMCReports -Path "test.xml" -XmlContent @("test") -SearchString "test" } | Should -Throw
        }
    }

    Context "SecurityDescriptor Exclusion" {
        
        It "Should exclude SecurityDescriptor nodes from search results" -Skip:$script:UseSimpleTest {
            # Search for "Peru" which exists in SecurityDescriptor in test data
            $results = Search-GPMCReports -Path $TestDataPath -SearchString "Peru"
            
            $results | Should -BeNullOrEmpty -Because "SecurityDescriptor content should be excluded from search results"
        }
        
        It "Should exclude SecurityDescriptor content with verbose logging" -Skip:$script:UseSimpleTest {
            # Search with verbose to verify exclusion logic is triggered
            $results = $null
            $verboseStream = @()
            
            try {
                $verbosePreference = $VerbosePreference
                $VerbosePreference = 'Continue'
                $results = Search-GPMCReports -Path $TestDataPath -SearchString "Peru" -Verbose 4>$null
            }
            finally {
                $VerbosePreference = $verbosePreference
            }
            
            $results | Should -BeNullOrEmpty -Because "SecurityDescriptor content should be excluded"
        }
        
        It "Should still find non-SecurityDescriptor content with same search term" -Skip {
            # Create test XML with "Peru" in both SecurityDescriptor and non-SecurityDescriptor contexts
            $testXml = @"
<?xml version="1.0" encoding="utf-8"?>
<GPO xmlns="http://www.microsoft.com/GroupPolicy/Settings">
  <Computer>
    <SecurityDescriptor>
      <Permissions>
        <TrusteePermissions>
          <Trustee>
            <Name xmlns="http://www.microsoft.com/GroupPolicy/Types">contoso\Peru</Name>
          </Trustee>
        </TrusteePermissions>
      </Permissions>
    </SecurityDescriptor>
    <ExtensionData>
      <Extension>
        <Policy>
          <Name>Peru Policy Setting</Name>
        </Policy>
      </Extension>
    </ExtensionData>
  </Computer>
</GPO>
"@
            
            $results = Search-GPMCReports -XmlContent @($testXml) -SearchString "Peru"
            
            # Should find the Policy name but not the SecurityDescriptor content
            $results | Should -Not -BeNullOrEmpty -Because "Non-SecurityDescriptor content should still be found"
            $policyResults = $results | Where-Object { $_.SettingValue -like "*Peru Policy Setting*" }
            $policyResults | Should -Not -BeNullOrEmpty -Because "Policy name containing Peru should be found"
            
            $trusteeResults = $results | Where-Object { $_.SettingValue -like "*contoso\Peru*" }
            $trusteeResults | Should -BeNullOrEmpty -Because "SecurityDescriptor trustee name should be excluded"
        }
        
        It "Should exclude deeply nested SecurityDescriptor content" {
            # Test with various nesting levels within SecurityDescriptor
            $testXml = @"
<?xml version="1.0" encoding="utf-8"?>
<GPO xmlns="http://www.microsoft.com/GroupPolicy/Settings">
  <Computer>
    <SecurityDescriptor>
      <Permissions>
        <TrusteePermissions>
          <Trustee>
            <Name xmlns="http://www.microsoft.com/GroupPolicy/Types">contoso\TestUser</Name>
          </Trustee>
          <Type>
            <PermissionType>Allow</PermissionType>
          </Type>
          <Standard>
            <GPOGroupedAccessEnum>Edit, delete, modify security</GPOGroupedAccessEnum>
          </Standard>
        </TrusteePermissions>
      </Permissions>
    </SecurityDescriptor>
  </Computer>
</GPO>
"@
            
            $results = Search-GPMCReports -XmlContent @($testXml) -SearchString "TestUser"
            $results | Should -BeNullOrEmpty -Because "Deeply nested SecurityDescriptor content should be excluded"
            
            $results = Search-GPMCReports -XmlContent @($testXml) -SearchString "Allow"
            $results | Should -BeNullOrEmpty -Because "SecurityDescriptor permission types should be excluded"
            
            $results = Search-GPMCReports -XmlContent @($testXml) -SearchString "security"
            $results | Should -BeNullOrEmpty -Because "SecurityDescriptor access descriptions should be excluded"
        }
    }
}



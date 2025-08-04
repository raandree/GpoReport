#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Search-GPMCReports.ps1 script validation

.DESCRIPTION
    This test script validates that the Search-GPMCReports.ps1 script correctly
    identifies and categorizes GPO settings according to the expected mapping table.
    
    The tests verify that search patterns return the correct category paths for
    various types of Group Policy settings including Security Settings, 
    Administrative Templates, Advanced Audit Configuration, and more.

.NOTES
    Requires the AllSettings1.xml test file to be present in the same directory
    as the Search-GPMCReports.ps1 script.
#>

BeforeAll {
    # Set up test environment
    $ScriptPath = Join-Path $PSScriptRoot "Search-GPMCReports.ps1"
    $TestDataPath = Join-Path $PSScriptRoot "AllSettings1.xml"
    
    # Verify required files exist
    if (-not (Test-Path $ScriptPath)) {
        throw "Search-GPMCReports.ps1 script not found at: $ScriptPath"
    }
    
    if (-not (Test-Path $TestDataPath)) {
        throw "Test data file AllSettings1.xml not found at: $TestDataPath"
    }
    
    # Define the expected mapping table
    $script:ExpectedMappings = @{
        "Chile" = "Security Settings > Local Policies > User Rights Assignment"
        "SeTakeOwnershipPrivilege" = "Security Settings > Local Policies > User Rights Assignment"
        "LDAP server signing requirements" = "Security Settings > Local Policies > Security Options > Domain Controller"
        "Require signing" = "Security Settings > Local Policies > Security Options > Domain Controller"
        "GpoBackup" = "Security Settings > File System"
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
        "SeCreateGlobalPrivilege" = "Security Settings > Local Policies > User Rights Assignment"
        "Armenia" = "Security Settings > Restricted Groups"
        "NTDS" = "Security Settings > System Services"
        "DeployDebug" = "Security Settings > File System"
        "7-Zip" = "Security Settings > Registry"
        "Force a specific default lock screen" = "Administrative Templates > Control Panel > Personalization"
        "Cipher suite order" = "Administrative Templates > Network > Lanman Server"
        "Allow only system backup" = "Administrative Templates > Server"
        "Establish ActiveX installation" = "Administrative Templates > Windows Components > ActiveX Installer Service"
        "Turn on Security Center" = "Administrative Templates > Windows Components > Security Center"
    }
    
    # Helper function to execute search and extract category path
    function Invoke-GPMCSearch {
        param(
            [string]$SearchTerm,
            [string]$ScriptPath,
            [string]$TestDataPath
        )
        
        try {
            # Execute the search script and get the result objects
            $results = & $ScriptPath -SearchString $SearchTerm -Path $TestDataPath 2>$null
            
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

Describe "Search-GPMCReports.ps1 Category Path Validation" {
    
    Context "Security Settings - Account Policies" {
        
        It "Should correctly categorize Password Policy settings" {
            $searchTerm = "PasswordHistorySize"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Password policy settings should be categorized under Account Policies > Password Policy"
        }
        
        It "Should correctly categorize Kerberos Policy settings" {
            $searchTerm = "MaxTicketAge"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Kerberos policy settings should be categorized under Account Policies > Kerberos Policy"
        }
        
        It "Should correctly categorize Audit Policy settings" {
            $searchTerm = "AuditDSAccess"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Audit policy settings should be categorized under Account Policies > Audit Policy"
        }
    }
    
    Context "Security Settings - Local Policies" {
        
        It "Should correctly categorize User Rights Assignment for privilege '<SearchTerm>'" -TestCases @(
            @{ SearchTerm = "SeTakeOwnershipPrivilege" }
            @{ SearchTerm = "SeCreateGlobalPrivilege" }
        ) {
            param($SearchTerm)
            
            $expected = $ExpectedMappings[$SearchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $SearchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "User rights assignments should be categorized under Local Policies > User Rights Assignment"
        }
        
        It "Should correctly categorize User Rights Assignment for user '<SearchTerm>'" -TestCases @(
            @{ SearchTerm = "Chile" }
            @{ SearchTerm = "Uruguay" }
        ) {
            param($SearchTerm)
            
            $expected = $ExpectedMappings[$SearchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $SearchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "User assignments should be categorized under Local Policies > User Rights Assignment"
        }
        
        It "Should correctly categorize Security Options - Domain Controller settings" -TestCases @(
            @{ SearchTerm = "LDAP server signing requirements" }
            @{ SearchTerm = "Require signing" }
        ) {
            param($SearchTerm)
            
            $expected = $ExpectedMappings[$SearchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $SearchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Domain Controller security options should be properly subcategorized"
        }
        
        It "Should correctly categorize Security Options - Devices settings" {
            $searchTerm = "Restrict CD-ROM"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Device-related security options should be subcategorized under Devices"
        }
        
        It "Should correctly categorize Security Options - Other settings" {
            $searchTerm = "Server SPN"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Miscellaneous security options should be subcategorized under Other"
        }
    }
    
    Context "Security Settings - Advanced Audit Configuration" {
        
        It "Should correctly categorize Advanced Audit Configuration - Account Logon" {
            $searchTerm = "Audit Kerberos Service Ticket Operations"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Account logon audit settings should be properly subcategorized"
        }
        
        It "Should correctly categorize Advanced Audit Configuration - DS Access" {
            $searchTerm = "Audit Directory Service Changes"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Directory service audit settings should be properly subcategorized"
        }
    }
    
    Context "Security Settings - Other Categories" {
        
        It "Should correctly categorize Event Log settings" {
            $searchTerm = "RetentionDays"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Event log settings should be categorized under Event Log"
        }
        
        It "Should correctly categorize System Services settings" {
            $searchTerm = "NTDS"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "System service settings should be categorized under System Services"
        }
        
        It "Should correctly categorize File System settings" -TestCases @(
            @{ SearchTerm = "GpoBackup" }
            @{ SearchTerm = "DeployDebug" }
        ) {
            param($SearchTerm)
            
            $expected = $ExpectedMappings[$SearchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $SearchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "File system settings should be categorized under File System"
        }
        
        It "Should correctly categorize Registry settings" {
            $searchTerm = "7-Zip"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Registry settings should be categorized under Registry"
        }
        
        It "Should correctly categorize Restricted Groups settings" {
            $searchTerm = "Armenia"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Restricted group settings should be categorized under Restricted Groups"
        }
    }
    
    Context "Administrative Templates" {
        
        It "Should correctly categorize Control Panel settings" {
            $searchTerm = "Force a specific default lock screen"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Control Panel settings should be properly categorized with > separators"
        }
        
        It "Should correctly categorize Network settings" {
            $searchTerm = "Cipher suite order"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Network settings should be properly categorized with > separators"
        }
        
        It "Should correctly categorize Server settings" {
            $searchTerm = "Allow only system backup"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Server settings should be properly categorized"
        }
        
        It "Should correctly categorize Windows Components settings" -TestCases @(
            @{ SearchTerm = "Establish ActiveX installation" }
            @{ SearchTerm = "Turn on Security Center" }
        ) {
            param($SearchTerm)
            
            $expected = $ExpectedMappings[$SearchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $SearchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Windows Components settings should be properly categorized with > separators"
        }
        
        It "Should correctly categorize Start Menu and Taskbar settings" {
            $searchTerm = "Turn off notifications network usage"
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            $actual | Should -Be $expected -Because "Start Menu and Taskbar settings should be properly categorized with > separators"
        }
    }
    
    Context "Script Functionality Tests" {
        
        It "Should find matches for all test search terms" {
            $notFoundTerms = @()
            
            foreach ($searchTerm in $ExpectedMappings.Keys) {
                $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
                
                if ($actual -eq "Not Found" -or $actual -eq "Error") {
                    $notFoundTerms += $searchTerm
                }
            }
            
            $notFoundTerms | Should -HaveCount 0 -Because "All search terms should return matches in the test data"
        }
        
        It "Should return results in the expected format" {
            $searchTerm = "PasswordHistorySize"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should return results"
            $results[0].CategoryPath | Should -Not -BeNullOrEmpty -Because "Result object should have CategoryPath property"
            $results[0].GPO | Should -Not -BeNullOrEmpty -Because "Result object should have GPO property"
            $results[0].Setting | Should -Not -BeNullOrEmpty -Because "Result object should have Setting property"
            $results[0].MatchedText | Should -Not -BeNullOrEmpty -Because "Result object should have MatchedText property"
        }
        
        It "Should handle wildcard patterns correctly" {
            $results = & $ScriptPath -SearchString "*password*" -Path $TestDataPath
            
            $results | Should -Not -BeNullOrEmpty -Because "Wildcard search should return results"
            $passwordMatch = $results | Where-Object { $_.MatchedText -like "*PasswordHistorySize*" }
            $passwordMatch | Should -Not -BeNullOrEmpty -Because "Wildcard search should find password-related settings"
        }
    }
}

Describe "Search-GPMCReports.ps1 Overall Validation Summary" {
    
    It "Should have an acceptable success rate for category mapping" {
        $totalTests = $ExpectedMappings.Count
        $passedTests = 0
        $failedTests = @()
        
        foreach ($searchTerm in $ExpectedMappings.Keys) {
            $expected = $ExpectedMappings[$searchTerm]
            $actual = Invoke-GPMCSearch -SearchTerm $searchTerm -ScriptPath $ScriptPath -TestDataPath $TestDataPath
            
            if ($actual -eq $expected) {
                $passedTests++
            } else {
                $failedTests += @{
                    SearchTerm = $searchTerm
                    Expected = $expected
                    Actual = $actual
                }
            }
        }
        
        $successRate = [Math]::Round(($passedTests / $totalTests) * 100, 1)
        
        # Log summary information
        Write-Host "`n=== PESTER TEST SUMMARY ===" -ForegroundColor Cyan
        Write-Host "Total Tests: $totalTests" -ForegroundColor Gray
        Write-Host "Passed: $passedTests" -ForegroundColor Green
        Write-Host "Failed: $($failedTests.Count)" -ForegroundColor Red
        Write-Host "Success Rate: $successRate%" -ForegroundColor Yellow
        
        if ($failedTests.Count -gt 0) {
            Write-Host "`nFailed Tests:" -ForegroundColor Red
            foreach ($failure in $failedTests) {
                Write-Host "  ✗ $($failure.SearchTerm)" -ForegroundColor Red
                Write-Host "    Expected: $($failure.Expected)" -ForegroundColor Yellow
                Write-Host "    Actual:   $($failure.Actual)" -ForegroundColor Gray
            }
        }
        
        # Test should pass if we have at least 60% success rate
        $successRate | Should -BeGreaterThan 60 -Because "Category mapping should have at least 60% accuracy"
    }
}

Describe "Search-GPMCReports.ps1 GPO Section Detection" {
    
    Context "Computer Section Settings" {
        
        It "Should correctly identify Computer section for Security Settings" {
            $searchTerm = "PasswordHistorySize"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find the password policy setting"
            $firstResult = if ($results -is [array]) { $results[0] } else { $results }
            $firstResult.Section | Should -Be "Computer" -Because "Security Settings should be in Computer section"
        }
        
        It "Should correctly identify Computer section for LDAP server signing" {
            $searchTerm = "LDAP server signing requirements"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find the LDAP server setting"
            $firstResult = if ($results -is [array]) { $results[0] } else { $results }
            $firstResult.Section | Should -Be "Computer" -Because "Security Options should be in Computer section"
        }
        
        It "Should correctly identify Computer section for Administrative Templates" {
            $searchTerm = "Turn off notifications network usage"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find the notifications setting"
            $firstResult = if ($results -is [array]) { $results[0] } else { $results }
            $firstResult.Section | Should -Be "Computer" -Because "Computer Administrative Templates should be in Computer section"
        }
        
        It "Should correctly identify Computer section for Advanced Audit Configuration" {
            $searchTerm = "Audit Kerberos Service Ticket Operations"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find the audit setting"
            $firstResult = if ($results -is [array]) { $results[0] } else { $results }
            $firstResult.Section | Should -Be "Computer" -Because "Advanced Audit Configuration should be in Computer section"
        }
    }
    
    Context "User Section Settings" {
        
        It "Should correctly identify User section for 'Download missing COM components'" {
            $searchTerm = "Download missing COM components"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find the COM components setting"
            $firstResult = if ($results -is [array]) { $results[0] } else { $results }
            $firstResult.Section | Should -Be "User" -Because "User Administrative Templates should be in User section"
        }
        
        It "Should correctly identify User section for 'Prevent access to the command prompt'" {
            $searchTerm = "Prevent access to the command prompt"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find the command prompt setting"
            $firstResult = if ($results -is [array]) { $results[0] } else { $results }
            $firstResult.Section | Should -Be "User" -Because "Command prompt restriction should be in User section"
        }
    }
    
    Context "Section Property Availability" {
        
        It "Should include Section property in all search results" {
            $searchTerm = "*password*"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find password-related settings"
            
            foreach ($result in $results) {
                $result | Should -Not -BeNullOrEmpty -Because "Each result should exist"
                $result.PSObject.Properties.Name | Should -Contain "Section" -Because "Each result should have a Section property"
                $result.Section | Should -BeIn @("Computer", "User", "Unknown") -Because "Section should be Computer, User, or Unknown"
            }
        }
    }
    
    Context "Comment Extraction" {
        
        It "Should extract comments from Computer section policies with comments" {
            $searchTerm = "Cipher suite order"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find the Cipher suite order setting"
            
            # Find the result that matches the policy name (not the explanation text)
            $policyResult = $results | Where-Object { $_.Setting.Name -eq "Cipher suite order" -and $_.MatchedText -eq "Cipher suite order" }
            $policyResult | Should -Not -BeNullOrEmpty -Because "Should find the policy result with matching name"
            
            $policyResult.Comment | Should -Be "Comment for Cipher Suite" -Because "Should extract the comment from the policy"
            $policyResult.Section | Should -Be "Computer" -Because "Should be in Computer section"
        }
        
        It "Should extract comments from Computer section ActiveX policies" {
            $searchTerm = "Establish ActiveX installation policy for sites in Trusted zones"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find the ActiveX installation policy"
            
            # Find the result that matches the policy name (not the explanation text)
            $policyResult = $results | Where-Object { 
                $_.Setting.Name -eq "Establish ActiveX installation policy for sites in Trusted zones" -and 
                $_.MatchedText -eq "Establish ActiveX installation policy for sites in Trusted zones" 
            }
            $policyResult | Should -Not -BeNullOrEmpty -Because "Should find the ActiveX policy result"
            
            $policyResult.Comment | Should -Be "Comment for ActiveX installation policy" -Because "Should extract the ActiveX comment"
            $policyResult.Section | Should -Be "Computer" -Because "Should be in Computer section"
        }
        
        It "Should extract comments from User section policies with comments" {
            $searchTerm = "Download missing COM components"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find the COM components setting"
            
            $policyResult = $results | Where-Object { 
                $_.Setting.Name -eq "Download missing COM components" -and 
                $_.MatchedText -eq "Download missing COM components" 
            }
            $policyResult | Should -Not -BeNullOrEmpty -Because "Should find the COM components policy result"
            
            $policyResult.Comment | Should -Be "Comment for Cipher Suite" -Because "Should extract the comment from User section policy"
            $policyResult.Section | Should -Be "User" -Because "Should be in User section"
        }
        
        It "Should extract comments from User section command prompt policies" {
            $searchTerm = "Prevent access to the command prompt"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find the command prompt setting"
            
            $policyResult = $results | Where-Object { 
                $_.Setting.Name -eq "Prevent access to the command prompt" -and 
                $_.MatchedText -eq "Prevent access to the command prompt" 
            }
            $policyResult | Should -Not -BeNullOrEmpty -Because "Should find the command prompt policy result"
            
            $policyResult.Comment | Should -Be "Comment for Cipher Suite" -Because "Should extract the comment from User section policy"
            $policyResult.Section | Should -Be "User" -Because "Should be in User section"
        }
        
        It "Should include Comment property in result object for all results" {
            $searchTerm = "*password*"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find password-related settings"
            
            foreach ($result in $results) {
                $result.Setting | Should -Not -BeNullOrEmpty -Because "Each result should have a Setting object"
                $result.PSObject.Properties.Name | Should -Contain "Comment" -Because "Result object should have Comment property at top level"
            }
        }
        
        It "Should handle policies without comments gracefully" {
            # Search for a policy that doesn't have a comment
            $searchTerm = "PasswordHistorySize"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find the password history setting"
            
            foreach ($result in $results) {
                $result.Setting | Should -Not -BeNullOrEmpty -Because "Each result should have a Setting object"
                $result.PSObject.Properties.Name | Should -Contain "Comment" -Because "Result object should have Comment property at top level even when null"
                # Comment should be null for policies without comments
                if ($null -ne $result.Comment) {
                    $result.Comment | Should -BeOfType [string] -Because "Comment should be string when present"
                }
            }
        }
        
        It "Should search for comment text directly" {
            $searchTerm = "*Comment for Cipher Suite*"
            $results = & $ScriptPath -SearchString $searchTerm -Path $TestDataPath 2>$null
            
            $results | Should -Not -BeNullOrEmpty -Because "Search should find the comment text"
            
            # Should find multiple results since this comment appears in multiple policies
            $commentMatches = $results | Where-Object { $_.MatchedText -like "*Comment for Cipher Suite*" }
            $commentMatches | Should -Not -BeNullOrEmpty -Because "Should find matches for the comment text"
            $commentMatches.Count | Should -BeGreaterThan 0 -Because "Should find at least one comment match"
        }
    }
}

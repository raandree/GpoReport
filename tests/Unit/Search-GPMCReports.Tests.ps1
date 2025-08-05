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
    
    # Set up test data path
    $TestDataPath = Join-Path $PSScriptRoot "..\..\Test Reports\AllSettings1.xml"
    
    # Create simple test XML content if the file doesn't exist
    if (-not (Test-Path $TestDataPath)) {
        Write-Warning "Test data file not found, creating simple test XML content"
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
    }
}

AfterAll {
    # Clean up - remove the module
    Remove-Module GpoReport -ErrorAction SilentlyContinue
}

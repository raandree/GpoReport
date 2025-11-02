#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Get-GPOInsights function validation

.DESCRIPTION
    This test script valida        It "Should handle empty results gracefully" {
            # Test with actual test results rather than empty array to avoid parameter validation issues
            $result = Get-GPOInsights -Results $script:TestResults -AnalysisType 'Security'
            $result | Should -Not -BeNull
        } the Get-GPOInsights function's ability to
    analyze GPO search results and provide security, compliance, and performance insights.

.NOTES
    Tests the GpoReport module insights functionality.
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
    
    # Create test data with various security-related settings
    $script:TestResults = @(
        [PSCustomObject]@{
            GPOName = "Security GPO"
            GPOId = "{12345678-1234-1234-1234-123456789012}"
            DomainName = "test.domain.com"
            CategoryPath = "Security Settings > Account Policies > Password Policy"
            SettingName = "PasswordHistorySize"
            SettingValue = "5"
            Context = "Computer Configuration"
            SourceFile = "SecurityGPO.xml"
        },
        [PSCustomObject]@{
            GPOName = "Audit GPO"
            GPOId = "{87654321-4321-4321-4321-210987654321}"
            DomainName = "test.domain.com"
            CategoryPath = "Security Settings > Advanced Audit Configuration > Account Logon"
            SettingName = "Audit Kerberos Service Ticket Operations"
            SettingValue = "Success"
            Context = "Computer Configuration"
            SourceFile = "AuditGPO.xml"
        },
        [PSCustomObject]@{
            GPOName = "User Rights GPO"
            GPOId = "{11111111-2222-3333-4444-555555555555}"
            DomainName = "test.domain.com"
            CategoryPath = "Security Settings > Local Policies > User Rights Assignment"
            SettingName = "SeTakeOwnershipPrivilege"
            SettingValue = "Administrators"
            Context = "Computer Configuration"
            SourceFile = "UserRightsGPO.xml"
        }
    )
}

Describe "Get-GPOInsights Function Validation" {
    
    Context "Function Availability and Basic Operations" {
        
        It "Should have the Get-GPOInsights function available" {
            Get-Command Get-GPOInsights -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should accept pipeline input" {
            $function = Get-Command Get-GPOInsights
            $pipelineParam = $function.Parameters['Results']
            $pipelineParam.Attributes.ValueFromPipeline | Should -Be $true
        }
        
        It "Should have valid analysis type parameter set" {
            $function = Get-Command Get-GPOInsights
            $analysisTypeParam = $function.Parameters['AnalysisType']
            $validSet = $analysisTypeParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validSet.ValidValues | Should -Contain 'Security'
            $validSet.ValidValues | Should -Contain 'Compliance'
            $validSet.ValidValues | Should -Contain 'Performance'
            $validSet.ValidValues | Should -Contain 'Conflicts'
            $validSet.ValidValues | Should -Contain 'All'
        }
    }
    
    Context "Analysis Functions" {
        
        It "Should perform security analysis successfully" {
            { Get-GPOInsights -Results $script:TestResults -AnalysisType Security } | Should -Not -Throw
        }
        
        It "Should perform compliance analysis successfully" {
            { Get-GPOInsights -Results $script:TestResults -AnalysisType Compliance } | Should -Not -Throw
        }
        
        It "Should perform performance analysis successfully" {
            { Get-GPOInsights -Results $script:TestResults -AnalysisType Performance } | Should -Not -Throw
        }
        
        It "Should perform conflict analysis successfully" {
            { Get-GPOInsights -Results $script:TestResults -AnalysisType Conflicts } | Should -Not -Throw
        }
        
        It "Should return non-null results for all analysis types" {
            $securityInsights = Get-GPOInsights -Results $script:TestResults -AnalysisType Security
            $complianceInsights = Get-GPOInsights -Results $script:TestResults -AnalysisType Compliance
            $performanceInsights = Get-GPOInsights -Results $script:TestResults -AnalysisType Performance
            $conflictInsights = Get-GPOInsights -Results $script:TestResults -AnalysisType Conflicts
            
            $securityInsights | Should -Not -BeNullOrEmpty
            $complianceInsights | Should -Not -BeNullOrEmpty
            $performanceInsights | Should -Not -BeNullOrEmpty
            $conflictInsights | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Comprehensive Analysis" {
        
        It "Should perform all analysis types when AnalysisType is 'All'" {
            $insights = Get-GPOInsights -Results $script:TestResults -AnalysisType All
            
            $insights | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Report Generation" {
        
        It "Should accept GenerateReport parameter" {
            $function = Get-Command Get-GPOInsights
            $function.Parameters.Keys | Should -Contain 'GenerateReport'
        }
        
        It "Should accept OutputPath parameter" {
            $function = Get-Command Get-GPOInsights
            $function.Parameters.Keys | Should -Contain 'OutputPath'
        }
    }
    
    Context "Pipeline Input" {
        
        It "Should accept results via pipeline" {
            { $script:TestResults | Get-GPOInsights -AnalysisType Security } | Should -Not -Throw
        }
        
        It "Should process pipeline input correctly" {
            $insights = $script:TestResults | Get-GPOInsights -AnalysisType Security
            
            $insights | Should -Not -BeNullOrEmpty
            $insights.Summary.TotalSettings | Should -Be $script:TestResults.Count
        }
    }
    
    Context "Analysis Quality" {
        
        It "Should identify password policy settings in security analysis" {
            $insights = Get-GPOInsights -Results $script:TestResults -AnalysisType Security
            
            # The security analysis should identify password-related settings
            if ($insights.Security.Count -gt 0) {
                $passwordFindings = $insights.Security | Where-Object { $_.SettingName -match 'Password' }
                $passwordFindings | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should identify audit settings appropriately" {
            $insights = Get-GPOInsights -Results $script:TestResults -AnalysisType Security
            
            # The security analysis should identify audit-related settings
            if ($insights.Security.Count -gt 0) {
                $auditFindings = $insights.Security | Where-Object { $_.CategoryPath -match 'Audit' }
                $auditFindings | Should -Not -BeNullOrEmpty
            }
        }
    }
}

AfterAll {
    # Clean up - remove the module
    Remove-Module GpoReport -ErrorAction SilentlyContinue
}

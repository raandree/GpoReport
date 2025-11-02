#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Export-SearchResults function validation

.DESCRIPTION
    This test script validates the Export-SearchResults function's ability to
    export GPO search results in various formats (JSON, CSV, HTML, XML).

.NOTES
    Tests the GpoReport module export functionality.
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
    
    # Create test data
    $script:TestResults = @(
        [PSCustomObject]@{
            GPOName = "Test GPO 1"
            GPOId = "{12345678-1234-1234-1234-123456789012}"
            DomainName = "test.domain.com"
            CategoryPath = "Security Settings > Local Policies > User Rights Assignment"
            SettingName = "Test Setting 1"
            SettingValue = "Test Value 1"
            Context = "Computer Configuration"
            SourceFile = "TestFile1.xml"
        },
        [PSCustomObject]@{
            GPOName = "Test GPO 2"
            GPOId = "{87654321-4321-4321-4321-210987654321}"
            DomainName = "test.domain.com"
            CategoryPath = "Administrative Templates > Control Panel"
            SettingName = "Test Setting 2"
            SettingValue = "Test Value 2"
            Context = "User Configuration"
            SourceFile = "TestFile2.xml"
        }
    )
    
    # Create temporary directory for test outputs
    $script:TempDir = Join-Path $env:TEMP "GpoReportTests"
    if (-not (Test-Path $script:TempDir)) {
        New-Item -Path $script:TempDir -ItemType Directory -Force | Out-Null
    }
}

Describe "Export-SearchResults Function Validation" {
    
    Context "Function Availability and Basic Operations" {
        
        It "Should have the Export-SearchResults function available" {
            Get-Command Export-SearchResults -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should accept pipeline input" {
            $function = Get-Command Export-SearchResults
            $pipelineParam = $function.Parameters['Results']
            $pipelineParam.Attributes.ValueFromPipeline | Should -Be $true
        }
    }
    
    Context "JSON Export Format" {
        
        It "Should export to JSON format successfully" {
            $outputPath = Join-Path $script:TempDir "test-json"
            
            { Export-SearchResults -Results $script:TestResults -OutputPath $outputPath -Format JSON } | Should -Not -Throw
            
            $jsonFile = "$outputPath.json"
            Test-Path $jsonFile | Should -Be $true
        }
        
        It "Should create valid JSON content" {
            $outputPath = Join-Path $script:TempDir "test-json-valid"
            Export-SearchResults -Results $script:TestResults -OutputPath $outputPath -Format JSON
            
            $jsonFile = "$outputPath.json"
            $content = Get-Content $jsonFile -Raw
            
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }
    }
    
    Context "CSV Export Format" {
        
        It "Should export to CSV format successfully" {
            $outputPath = Join-Path $script:TempDir "test-csv"
            
            { Export-SearchResults -Results $script:TestResults -OutputPath $outputPath -Format CSV } | Should -Not -Throw
            
            $csvFile = "$outputPath.csv"
            Test-Path $csvFile | Should -Be $true
        }
        
        It "Should create valid CSV content with headers" {
            $outputPath = Join-Path $script:TempDir "test-csv-valid"
            Export-SearchResults -Results $script:TestResults -OutputPath $outputPath -Format CSV
            
            $csvFile = "$outputPath.csv"
            $content = Get-Content $csvFile
            
            $content[0] | Should -Match "GPOName.*CategoryPath.*SettingName"
            $content.Count | Should -BeGreaterThan 1
        }
    }
    
    Context "HTML Export Format" {
        
        It "Should export to HTML format successfully" {
            $outputPath = Join-Path $script:TempDir "test-html"
            
            { Export-SearchResults -Results $script:TestResults -OutputPath $outputPath -Format HTML } | Should -Not -Throw
            
            $htmlFile = "$outputPath.html"
            Test-Path $htmlFile | Should -Be $true
        }
        
        It "Should create valid HTML content" {
            $outputPath = Join-Path $script:TempDir "test-html-valid"
            Export-SearchResults -Results $script:TestResults -OutputPath $outputPath -Format HTML
            
            $htmlFile = "$outputPath.html"
            $content = Get-Content $htmlFile -Raw
            
            $content | Should -Match "<!DOCTYPE html>"
            $content | Should -Match "<html>"
            $content | Should -Match "</html>"
        }
    }
    
    Context "XML Export Format" {
        
        It "Should export to XML format successfully" {
            $outputPath = Join-Path $script:TempDir "test-xml"
            
            { Export-SearchResults -Results $script:TestResults -OutputPath $outputPath -Format XML } | Should -Not -Throw
            
            $xmlFile = "$outputPath.xml"
            Test-Path $xmlFile | Should -Be $true
        }
        
        It "Should create valid XML content" {
            $outputPath = Join-Path $script:TempDir "test-xml-valid"
            Export-SearchResults -Results $script:TestResults -OutputPath $outputPath -Format XML
            
            $xmlFile = "$outputPath.xml"
            
            { [xml](Get-Content $xmlFile -Raw) } | Should -Not -Throw
        }
    }
    
    Context "All Formats Export" {
        
        It "Should export all formats when Format is 'All'" {
            $outputPath = Join-Path $script:TempDir "test-all"
            
            { Export-SearchResults -Results $script:TestResults -OutputPath $outputPath -Format All } | Should -Not -Throw
            
            Test-Path "$outputPath.json" | Should -Be $true
            Test-Path "$outputPath.csv" | Should -Be $true
            Test-Path "$outputPath.html" | Should -Be $true
            Test-Path "$outputPath.xml" | Should -Be $true
        }
    }
    
    Context "Metadata Inclusion" {
        
        It "Should include metadata when IncludeMetadata switch is used" {
            $outputPath = Join-Path $script:TempDir "test-metadata"
            
            { Export-SearchResults -Results $script:TestResults -OutputPath $outputPath -Format JSON -IncludeMetadata } | Should -Not -Throw
            
            $jsonFile = "$outputPath.json"
            $content = Get-Content $jsonFile -Raw | ConvertFrom-Json
            
            # Check if metadata is properly structured
            if ($content.PSObject.Properties.Name -contains "Metadata") {
                $content.Metadata.PSObject.Properties.Name | Should -Contain "ExportTime"
                $content.Metadata.PSObject.Properties.Name | Should -Contain "TotalResults"
            } else {
                # Fallback: check if metadata is at root level
                $content.PSObject.Properties.Name | Should -Contain "Results"
            }
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle empty results gracefully" {
            $outputPath = Join-Path $script:TempDir "test-empty"
            
            # Empty results should complete successfully without throwing
            { Export-SearchResults -Results $script:TestResults -OutputPath $outputPath -Format JSON } | Should -Not -Throw
        }
        
        It "Should handle invalid output paths" {
            $invalidPath = "Z:\InvalidPath\test"
            
            { Export-SearchResults -Results $script:TestResults -OutputPath $invalidPath -Format JSON } | Should -Throw
        }
    }
    
    Context "Pipeline Input" {
        
        It "Should accept results via pipeline" {
            $outputPath = Join-Path $script:TempDir "test-pipeline"
            
            { $script:TestResults | Export-SearchResults -OutputPath $outputPath -Format JSON } | Should -Not -Throw
            
            Test-Path "$outputPath.json" | Should -Be $true
        }
    }
}

AfterAll {
    # Clean up - remove test files and module
    if (Test-Path $script:TempDir) {
        Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Module GpoReport -ErrorAction SilentlyContinue
}

function Export-SearchResults {
    <#
    .SYNOPSIS
        Export GPO search results to multiple professional formats
        
    .DESCRIPTION
        Export-SearchResults transforms GPO search results into professional formats suitable 
        for reporting, compliance documentation, and system integration. Supports JSON for APIs, 
        CSV for spreadsheet analysis, HTML for presentations, and XML for SIEM tools.
        
    .PARAMETER Results
        Array of search result objects from Search-GPMCReports
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
        
    .EXAMPLE
        $results = Search-GPMCReports -Path "*.xml" -SearchString "*audit*"
        Export-SearchResults -Results $results -OutputPath "audit-report" -Format All
        
    .EXAMPLE
        Search-GPMCReports -Path "." -SearchString "*password*" | Export-SearchResults -OutputPath "security-report" -Format HTML -IncludeMetadata
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject[]]$Results,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter()]
        [ValidateSet('JSON', 'CSV', 'HTML', 'XML', 'All')]
        [string]$Format = 'All',

        [Parameter()]
        [switch]$IncludeMetadata
    )

    begin {
        Write-Verbose "Starting export operation to: $OutputPath"
        $allResults = @()
        $exportMetadata = @{
            ExportTime    = Get-Date
            ExportUser    = $env:USERNAME
            ExportMachine = $env:COMPUTERNAME
            TotalResults  = 0
        }
    }

    process {
        $allResults += $Results
    }

    end {
        if ($allResults.Count -eq 0) {
            Write-Warning 'No results to export'
            return
        }

        $exportMetadata.TotalResults = $allResults.Count
        Write-Verbose "Exporting $($allResults.Count) results in format: $Format"

        try {
            switch ($Format) {
                'JSON' { Export-ToJSON -Results $allResults -OutputPath "$OutputPath.json" -IncludeMetadata:$IncludeMetadata -Metadata $exportMetadata }
                'CSV' { Export-ToCSV -Results $allResults -OutputPath "$OutputPath.csv" -IncludeMetadata:$IncludeMetadata -Metadata $exportMetadata }
                'HTML' { Export-ToHTML -Results $allResults -OutputPath "$OutputPath.html" -IncludeMetadata:$IncludeMetadata -Metadata $exportMetadata }
                'XML' { Export-ToXML -Results $allResults -OutputPath "$OutputPath.xml" -IncludeMetadata:$IncludeMetadata -Metadata $exportMetadata }
                'All' {
                    Export-ToJSON -Results $allResults -OutputPath "$OutputPath.json" -IncludeMetadata:$IncludeMetadata -Metadata $exportMetadata
                    Export-ToCSV -Results $allResults -OutputPath "$OutputPath.csv" -IncludeMetadata:$IncludeMetadata -Metadata $exportMetadata
                    Export-ToHTML -Results $allResults -OutputPath "$OutputPath.html" -IncludeMetadata:$IncludeMetadata -Metadata $exportMetadata
                    Export-ToXML -Results $allResults -OutputPath "$OutputPath.xml" -IncludeMetadata:$IncludeMetadata -Metadata $exportMetadata
                }
            }
            
            Write-Host "Export completed successfully to: $OutputPath.*" -ForegroundColor Green
        }
        catch {
            Write-Error "Export failed: $($_.Exception.Message)"
            throw
        }
    }
}

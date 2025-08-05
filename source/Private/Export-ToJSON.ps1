function Export-ToJSON {
    <#
    .SYNOPSIS
        Exports results to JSON format
        
    .DESCRIPTION
        Internal helper function to export search results to JSON format
        
    .PARAMETER Results
        The search results to export
        
    .PARAMETER OutputPath
        Output file path
        
    .PARAMETER IncludeMetadata
        Whether to include metadata in the export
        
    .PARAMETER Metadata
        Metadata object to include
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter()]
        [switch]$IncludeMetadata,
        
        [Parameter()]
        [hashtable]$Metadata
    )
    
    try {
        $exportData = @{}
        
        if ($IncludeMetadata -and $Metadata) {
            $exportData.Metadata = $Metadata
        }
        
        $exportData.Results = $Results
        
        $json = $exportData | ConvertTo-Json -Depth 10
        $json | Out-File -FilePath $OutputPath -Encoding UTF8
        
        Write-Verbose "JSON export completed: $OutputPath"
    }
    catch {
        Write-Error "JSON export failed: $($_.Exception.Message)"
        throw
    }
}

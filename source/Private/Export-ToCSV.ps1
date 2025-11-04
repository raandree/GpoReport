function Export-ToCSV {
    <#
    .SYNOPSIS
        Exports results to CSV format
        
    .DESCRIPTION
        Internal helper function to export search results to CSV format
        
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
        $Results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        
        if ($IncludeMetadata -and $Metadata) {
            # Append metadata as comments at the end
            $metadataText = @()
            $metadataText += ''
            $metadataText += '# Export Metadata'
            foreach ($key in $Metadata.Keys) {
                $metadataText += "# $key`: $($Metadata[$key])"
            }
            
            Add-Content -Path $OutputPath -Value $metadataText -Encoding UTF8
        }
        
        Write-Verbose "CSV export completed: $OutputPath"
    }
    catch {
        Write-Error "CSV export failed: $($_.Exception.Message)"
        throw
    }
}

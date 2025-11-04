function Export-ToXML {
    <#
    .SYNOPSIS
        Exports results to XML format
        
    .DESCRIPTION
        Internal helper function to export search results to XML format
        
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
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDecl = $xmlDoc.CreateXmlDeclaration('1.0', 'UTF-8', $null)
        $xmlDoc.AppendChild($xmlDecl) | Out-Null
        
        # Create root element
        $root = $xmlDoc.CreateElement('GPOSearchResults')
        $xmlDoc.AppendChild($root) | Out-Null
        
        # Add metadata if requested
        if ($IncludeMetadata -and $Metadata) {
            $metadataElement = $xmlDoc.CreateElement('Metadata')
            foreach ($key in $Metadata.Keys) {
                $element = $xmlDoc.CreateElement($key)
                $element.InnerText = $Metadata[$key].ToString()
                $metadataElement.AppendChild($element) | Out-Null
            }
            $root.AppendChild($metadataElement) | Out-Null
        }
        
        # Add results
        $resultsElement = $xmlDoc.CreateElement('Results')
        
        foreach ($result in $Results) {
            $resultElement = $xmlDoc.CreateElement('Result')
            
            foreach ($property in $result.PSObject.Properties) {
                $propElement = $xmlDoc.CreateElement($property.Name)
                if ($null -ne $property.Value) {
                    $propElement.InnerText = $property.Value.ToString()
                }
                $resultElement.AppendChild($propElement) | Out-Null
            }
            
            $resultsElement.AppendChild($resultElement) | Out-Null
        }
        
        $root.AppendChild($resultsElement) | Out-Null
        
        # Save to file
        $xmlDoc.Save($OutputPath)
        
        Write-Verbose "XML export completed: $OutputPath"
    }
    catch {
        Write-Error "XML export failed: $($_.Exception.Message)"
        throw
    }
}

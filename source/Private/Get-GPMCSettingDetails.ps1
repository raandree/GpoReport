function Get-GPMCSettingDetails {
    <#
    .SYNOPSIS
        Extracts setting details from XML element
        
    .DESCRIPTION
        Internal helper function to extract setting name and other details from XML element
        
    .PARAMETER Element
        The XML element to analyze
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Element
    )
    
    try {
        $details = @{
            Name = 'Unknown Setting'
            Type = 'Unknown'
        }
        
        $currentElement = $Element
        
        # Look for setting name in various attributes and elements
        while ($currentElement -and $currentElement.ParentNode) {
            # Check common attribute names for setting names
            foreach ($attr in @('name', 'Name', 'DisplayName', 'title', 'key')) {
                if ($currentElement.HasAttribute($attr)) {
                    $value = $currentElement.GetAttribute($attr)
                    if ($value -and $value.Trim() -ne '' -and $details.Name -eq 'Unknown Setting') {
                        $details.Name = $value
                        break
                    }
                }
            }
            
            # Check if this is a specific setting type
            $localName = $currentElement.LocalName
            if ($localName -in @('Registry', 'File', 'Folder', 'Service', 'EnvironmentVariable', 'Script')) {
                $details.Type = $localName
            }
            
            $currentElement = $currentElement.ParentNode
        }
        
        return [PSCustomObject]$details
    }
    catch {
        Write-Verbose "Error extracting setting details: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Name = 'Unknown Setting'
            Type = 'Unknown'
        }
    }
}

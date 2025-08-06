function ConvertFrom-XmlToObject {
    <#
    .SYNOPSIS
        Converts XML content to a structured PowerShell object supporting dot notation access
        
    .DESCRIPTION
        Transforms XML elements into nested PowerShell custom objects, removing namespace prefixes
        and creating properties that can be accessed using dot notation. Handles complex XML structures
        including elements with both attributes and text content.
        
    .PARAMETER XmlElement
        The XML element to convert
        
    .PARAMETER RemoveNamespaces
        Whether to remove XML namespace prefixes from property names
        
    .OUTPUTS
        PSCustomObject with properties corresponding to XML structure
        
    .EXAMPLE
        $xml = [xml]'<Root><Child>Value</Child></Root>'
        $obj = ConvertFrom-XmlToObject -XmlElement $xml.DocumentElement
        $obj.Child  # Returns "Value"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$XmlElement,
        
        [Parameter()]
        [switch]$RemoveNamespaces = $true
    )
    
    try {
        # Create the base object
        $resultObject = [PSCustomObject]@{}
        
        # Get the clean element name (without namespace prefix)
        $elementName = if ($RemoveNamespaces -and $XmlElement.LocalName) { 
            $XmlElement.LocalName 
        } else { 
            $XmlElement.Name 
        }
        
        # Handle attributes if present
        if ($XmlElement.Attributes -and $XmlElement.Attributes.Count -gt 0) {
            foreach ($attr in $XmlElement.Attributes) {
                $attrName = if ($RemoveNamespaces) { $attr.LocalName } else { $attr.Name }
                $resultObject | Add-Member -NotePropertyName "_$attrName" -NotePropertyValue $attr.Value
            }
        }
        
        # Handle child elements
        $childElements = $XmlElement.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element }
        
        if ($childElements) {
            # Group child elements by name to handle multiple elements with same name
            $groupedChildren = $childElements | Group-Object -Property LocalName
            
            foreach ($group in $groupedChildren) {
                $childName = if ($RemoveNamespaces) { $group.Name } else { $group.Group[0].Name }
                
                if ($group.Count -eq 1) {
                    # Single child element
                    $childElement = $group.Group[0]
                    
                    # Check if element has child elements or just text
                    $grandChildren = $childElement.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element }
                    
                    if ($grandChildren -or ($childElement.Attributes -and $childElement.Attributes.Count -gt 0)) {
                        # Has child elements OR attributes - convert recursively to preserve structure
                        $childObject = ConvertFrom-XmlToObject -XmlElement $childElement -RemoveNamespaces:$RemoveNamespaces
                        $resultObject | Add-Member -NotePropertyName $childName -NotePropertyValue $childObject
                    } else {
                        # Text content only, no attributes
                        $textValue = $childElement.InnerText.Trim()
                        $resultObject | Add-Member -NotePropertyName $childName -NotePropertyValue $textValue
                    }
                } else {
                    # Multiple child elements with same name - create array
                    $childArray = @()
                    foreach ($childElement in $group.Group) {
                        $grandChildren = $childElement.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element }
                        
                        if ($grandChildren -or ($childElement.Attributes -and $childElement.Attributes.Count -gt 0)) {
                            $childArray += ConvertFrom-XmlToObject -XmlElement $childElement -RemoveNamespaces:$RemoveNamespaces
                        } else {
                            $childArray += $childElement.InnerText.Trim()
                        }
                    }
                    $resultObject | Add-Member -NotePropertyName $childName -NotePropertyValue $childArray
                }
            }
        } else {
            # No child elements - this element contains only text and/or attributes
            $textValue = $XmlElement.InnerText.Trim()
            if (-not [string]::IsNullOrEmpty($textValue)) {
                $resultObject | Add-Member -NotePropertyName "Text" -NotePropertyValue $textValue
            }
        }
        
        # If the object has no properties except attributes and no meaningful text content, 
        # it's still a valid object (e.g., <Properties attr1="val1" attr2="val2" />)
        # If the object has no properties at all and only text content, return the text directly
        $hasAttributes = ($resultObject.PSObject.Properties | Where-Object { $_.Name.StartsWith('_') }).Count -gt 0
        $hasOtherProperties = ($resultObject.PSObject.Properties | Where-Object { -not $_.Name.StartsWith('_') }).Count -gt 0
        
        if (-not $hasAttributes -and -not $hasOtherProperties -and -not [string]::IsNullOrEmpty($XmlElement.InnerText)) {
            return $XmlElement.InnerText.Trim()
        }
        
        return $resultObject
    }
    catch {
        Write-Warning "Failed to convert XML element '$($XmlElement.LocalName)' to object: $($_.Exception.Message)"
        return $null
    }
}

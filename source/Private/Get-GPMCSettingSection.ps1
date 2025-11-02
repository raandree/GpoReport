function Get-GPMCSettingSection {
    <#
    .SYNOPSIS
        Determines whether a GPO setting is in Computer or User section
        
    .DESCRIPTION
        Internal helper function to identify the section (Computer/User) of a GPO setting
        by traversing up the XML hierarchy to find Computer or User parent elements
        
    .PARAMETER Element
        The XML element to analyze for section context
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Element
    )
    
    try {
        $currentElement = $Element
        $traversalCount = 0
        $maxTraversal = 20  # Prevent infinite loops
        
        # Walk up the XML tree to find Computer or User section
        while ($currentElement -and $currentElement.ParentNode -and $traversalCount -lt $maxTraversal) {
            $localName = $currentElement.LocalName
            
            # Check for Computer or User section indicators
            if ($localName -eq 'Computer' -or $localName -eq 'ComputerConfiguration') {
                return 'Computer'
            }
            elseif ($localName -eq 'User' -or $localName -eq 'UserConfiguration') {
                return 'User'
            }
            
            # Check element attributes for section information
            if ($currentElement.HasAttributes) {
                foreach ($attr in $currentElement.Attributes) {
                    $attrValue = $attr.Value.ToLower()
                    if ($attrValue -match 'computer') {
                        return 'Computer'
                    }
                    elseif ($attrValue -match 'user') {
                        return 'User'
                    }
                }
            }
            
            $currentElement = $currentElement.ParentNode
            $traversalCount++
        }
        
        # If we can't determine the section, return null
        Write-Verbose "Could not determine section for element: $($Element.LocalName)"
        return $null
    }
    catch {
        Write-Verbose "Error determining section: $($_.Exception.Message)"
        return $null
    }
}

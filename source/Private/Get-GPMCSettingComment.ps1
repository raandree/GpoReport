function Get-GPMCSettingComment {
    <#
    .SYNOPSIS
        Extracts comment information from a GPO setting element
        
    .DESCRIPTION
        Internal helper function to extract policy comments from XML elements.
        Looks for comment elements in the current element and its children.
        
    .PARAMETER Element
        The XML element to analyze for comment information
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Element
    )
    
    try {
        # Look for comment elements in current element and children
        $commentPatterns = @(
            './/q*:Comment',
            './/Comment', 
            ".//*[local-name()='Comment']",
            './/q4:Comment',
            './/q6:Comment'
        )
        
        foreach ($pattern in $commentPatterns) {
            try {
                $commentNode = $Element.SelectSingleNode($pattern)
                if ($commentNode -and -not [string]::IsNullOrWhiteSpace($commentNode.InnerText)) {
                    return $commentNode.InnerText.Trim()
                }
            }
            catch {
                # Continue to next pattern if this one fails
                Write-Verbose "Comment pattern '$pattern' failed: $($_.Exception.Message)"
            }
        }
        
        # Look for comment in parent elements (up to 3 levels)
        $currentElement = $Element
        $maxLevels = 3
        $level = 0
        
        while ($currentElement.ParentNode -and $level -lt $maxLevels) {
            $currentElement = $currentElement.ParentNode
            
            foreach ($pattern in $commentPatterns) {
                try {
                    $commentNode = $currentElement.SelectSingleNode($pattern)
                    if ($commentNode -and -not [string]::IsNullOrWhiteSpace($commentNode.InnerText)) {
                        return $commentNode.InnerText.Trim()
                    }
                }
                catch {
                    # Continue to next pattern if this one fails
                    Write-Verbose "Comment pattern '$pattern' failed at level ${level}: $($_.Exception.Message)"
                }
            }
            
            $level++
        }
        
        # No comment found
        return $null
    }
    catch {
        Write-Verbose "Error extracting comment: $($_.Exception.Message)"
        return $null
    }
}

function Get-GPMCCategoryPath {
    <#
    .SYNOPSIS
        Determines the category path for a GPO setting element
        
    .DESCRIPTION
        Internal helper function to build hierarchical category path from XML element context
        
    .PARAMETER Element
        The XML element to analyze for category path
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Element
    )
    
    try {
        $pathParts = @()
        $currentElement = $Element
        
        # Walk up the XML tree to build category path
        while ($currentElement -and $currentElement.ParentNode) {
            $localName = $currentElement.LocalName
            
            # Look for meaningful category indicators
            switch ($localName) {
                'Computer' { $pathParts += 'Computer Configuration'; break }
                'User' { $pathParts += 'User Configuration'; break }
                'SecuritySettings' { $pathParts += 'Security Settings'; break }
                'LocalPolicies' { $pathParts += 'Local Policies'; break }
                'AuditPolicy' { $pathParts += 'Audit Policy'; break }
                'UserRightsAssignment' { $pathParts += 'User Rights Assignment'; break }
                'SecurityOptions' { $pathParts += 'Security Options'; break }
                'AdministrativeTemplates' { $pathParts += 'Administrative Templates'; break }
                'Preferences' { $pathParts += 'Group Policy Preferences'; break }
                'Registry' { $pathParts += 'Registry'; break }
                'Files' { $pathParts += 'Files'; break }
                'Folders' { $pathParts += 'Folders'; break }
                'EnvironmentVariables' { $pathParts += 'Environment Variables'; break }
                'Services' { $pathParts += 'Services'; break }
                'StartupShutdown' { $pathParts += 'Startup/Shutdown Scripts'; break }
                'LogonLogoff' { $pathParts += 'Logon/Logoff Scripts'; break }
            }
            
            # Check for category names in attributes
            if ($currentElement.HasAttribute('name')) {
                $name = $currentElement.GetAttribute('name')
                if ($name -and $name.Trim() -ne '') {
                    $pathParts += $name
                }
            }
            
            $currentElement = $currentElement.ParentNode
        }
        
        # Reverse the array to get correct hierarchy
        [Array]::Reverse($pathParts)
        
        # Build path string
        if ($pathParts.Count -gt 0) {
            return ($pathParts -join ' > ')
        } else {
            return 'Unknown Category'
        }
    }
    catch {
        Write-Verbose "Error building category path: $($_.Exception.Message)"
        return 'Unknown Category'
    }
}

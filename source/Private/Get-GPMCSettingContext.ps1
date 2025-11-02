function Get-GPMCSettingContext {
    <#
    .SYNOPSIS
        Determines the context (Computer/User configuration) for a setting
        
    .DESCRIPTION
        Internal helper function to determine if a setting applies to Computer or User configuration
        
    .PARAMETER Element
        The XML element to analyze
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Element
    )
    
    try {
        $currentElement = $Element
        
        # Walk up the tree looking for Computer or User configuration indicators
        while ($currentElement -and $currentElement.ParentNode) {
            $localName = $currentElement.LocalName
            
            if ($localName -eq 'Computer' -or $localName -eq 'ComputerConfiguration') {
                return 'Computer Configuration'
            }
            elseif ($localName -eq 'User' -or $localName -eq 'UserConfiguration') {
                return 'User Configuration'
            }
            
            # Check for HKLM vs HKCU registry contexts
            if ($currentElement.HasAttribute('hive')) {
                $hive = $currentElement.GetAttribute('hive')
                if ($hive -like '*HKEY_LOCAL_MACHINE*' -or $hive -like '*HKLM*') {
                    return 'Computer Configuration'
                }
                elseif ($hive -like '*HKEY_CURRENT_USER*' -or $hive -like '*HKCU*') {
                    return 'User Configuration'
                }
            }
            
            $currentElement = $currentElement.ParentNode
        }
        
        return 'Unknown Context'
    }
    catch {
        Write-Verbose "Error determining setting context: $($_.Exception.Message)"
        return 'Unknown Context'
    }
}

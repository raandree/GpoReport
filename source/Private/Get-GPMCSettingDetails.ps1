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
        
        # Walk up the hierarchy to find the setting name based on element type
        while ($currentElement -and $currentElement.ParentNode) {
            $localName = $currentElement.LocalName
            
            # Pattern 1: Administrative Templates (Registry-based policies)
            # Structure: <Policy><Name>Setting Name</Name>...
            if ($localName -eq 'Policy' -and $currentElement.NamespaceURI -like '*Registry*') {
                $nameNode = $currentElement.SelectSingleNode('.//*[local-name()="Name"]')
                if ($nameNode -and $nameNode.InnerText) {
                    $details.Name = $nameNode.InnerText
                    $details.Type = 'Administrative Template'
                    break
                }
            }
            
            # Pattern 2: Security Settings - Account Policies
            # Structure: <Account><Name>PasswordHistorySize</Name>...
            if ($localName -eq 'Account') {
                $nameNode = $currentElement.SelectSingleNode('.//*[local-name()="Name"]')
                if ($nameNode -and $nameNode.InnerText) {
                    $details.Name = $nameNode.InnerText
                    $details.Type = 'Account Policy'
                    break
                }
            }
            
            # Pattern 3: Security Settings - Audit
            # Structure: <Audit><Name>AuditDSAccess</Name>...
            if ($localName -eq 'Audit') {
                $nameNode = $currentElement.SelectSingleNode('.//*[local-name()="Name"]')
                if ($nameNode -and $nameNode.InnerText) {
                    $details.Name = $nameNode.InnerText
                    $details.Type = 'Audit Policy'
                    break
                }
            }
            
            # Pattern 4: Security Settings - User Rights Assignment
            # Structure: <UserRightsAssignment><Name>SeCreateGlobalPrivilege</Name>...
            if ($localName -eq 'UserRightsAssignment') {
                $nameNode = $currentElement.SelectSingleNode('.//*[local-name()="Name"]')
                if ($nameNode -and $nameNode.InnerText) {
                    $details.Name = $nameNode.InnerText
                    $details.Type = 'User Rights Assignment'
                    break
                }
            }
            
            # Pattern 5: Security Settings - Security Options
            # Structure: <SecurityOptions><Display><Name>Friendly Name</Name>...
            if ($localName -eq 'SecurityOptions') {
                $displayNode = $currentElement.SelectSingleNode('.//*[local-name()="Display"]/*[local-name()="Name"]')
                if ($displayNode -and $displayNode.InnerText) {
                    $details.Name = $displayNode.InnerText
                    $details.Type = 'Security Option'
                    break
                }
            }
            
            # Pattern 6: Security Settings - Event Log
            # Structure: <EventLog><Name>RetentionDays</Name><Log>Application</Log>...
            if ($localName -eq 'EventLog') {
                $nameNode = $currentElement.SelectSingleNode('.//*[local-name()="Name"]')
                $logNode = $currentElement.SelectSingleNode('.//*[local-name()="Log"]')
                if ($nameNode -and $nameNode.InnerText) {
                    if ($logNode -and $logNode.InnerText) {
                        $details.Name = "$($nameNode.InnerText) ($($logNode.InnerText))"
                    } else {
                        $details.Name = $nameNode.InnerText
                    }
                    $details.Type = 'Event Log'
                    break
                }
            }
            
            # Pattern 7: Security Settings - Restricted Groups
            # Structure: <RestrictedGroups><GroupName><Name>contoso\Russia</Name>...
            if ($localName -eq 'RestrictedGroups') {
                $groupNameNode = $currentElement.SelectSingleNode('.//*[local-name()="GroupName"]/*[local-name()="Name"]')
                if ($groupNameNode -and $groupNameNode.InnerText) {
                    $details.Name = $groupNameNode.InnerText
                    $details.Type = 'Restricted Group'
                    break
                }
            }
            
            # Pattern 8: Security Settings - System Services
            # Structure: <SystemServices><Name>NTDS</Name>...
            if ($localName -eq 'SystemServices') {
                $nameNode = $currentElement.SelectSingleNode('.//*[local-name()="Name"]')
                if ($nameNode -and $nameNode.InnerText) {
                    $details.Name = $nameNode.InnerText
                    $details.Type = 'System Service'
                    break
                }
            }
            
            # Pattern 9: Security Settings - File System
            # Structure: <File><Path>%SystemDrive%\DeployDebug</Path>...
            if ($localName -eq 'File') {
                $pathNode = $currentElement.SelectSingleNode('.//*[local-name()="Path"]')
                if ($pathNode -and $pathNode.InnerText) {
                    $details.Name = $pathNode.InnerText
                    $details.Type = 'File System'
                    break
                }
            }
            
            # Pattern 10: Security Settings - Registry
            # Structure: <Registry><Path>MACHINE\SOFTWARE\7-Zip</Path>...
            if ($localName -eq 'Registry' -and $currentElement.NamespaceURI -like '*Security*') {
                $pathNode = $currentElement.SelectSingleNode('.//*[local-name()="Path"]')
                if ($pathNode -and $pathNode.InnerText) {
                    $details.Name = $pathNode.InnerText
                    $details.Type = 'Registry Security'
                    break
                }
            }
            
            # Pattern 11: Preferences - Various types
            # Check for Task, Shortcut, IniFile, EnvironmentVariable, etc.
            if ($localName -in @('Task', 'Shortcut', 'IniFile', 'EnvironmentVariable', 'Folder', 'Drive')) {
                # Try to get name from Properties
                $propertiesNode = $currentElement.SelectSingleNode('.//*[local-name()="Properties"]')
                if ($propertiesNode) {
                    # Try various name attributes
                    foreach ($attr in @('name', 'label', 'path', 'targetPath')) {
                        if ($propertiesNode.HasAttribute($attr)) {
                            $value = $propertiesNode.GetAttribute($attr)
                            if ($value -and $value.Trim() -ne '') {
                                $details.Name = $value
                                $details.Type = "Preference ($localName)"
                                break
                            }
                        }
                    }
                    if ($details.Name -ne 'Unknown Setting') {
                        break
                    }
                }
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

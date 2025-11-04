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
        # Check for Group Policy Preferences first
        # Define the namespace to category mapping based on mapping.txt
        $namespaceMapping = @{
            'http://www.microsoft.com/GroupPolicy/Settings/DriveMaps'             = 'Preferences > Windows Settings > Drive Maps'
            'http://www.microsoft.com/GroupPolicy/Settings/Environment'           = 'Preferences > Windows Settings > Environment Variables'
            'http://www.microsoft.com/GroupPolicy/Settings/Files'                 = 'Preferences > Windows Settings > Files'
            'http://www.microsoft.com/GroupPolicy/Settings/Folders'               = 'Preferences > Windows Settings > Folders'
            'http://www.microsoft.com/GroupPolicy/Settings/Windows/Registry'      = 'Preferences > Windows Settings > Registry'
            'http://www.microsoft.com/GroupPolicy/Settings/Shortcuts'             = 'Preferences > Windows Settings > Shortcuts'
            'http://www.microsoft.com/GroupPolicy/Settings/FolderOptions'         = 'Preferences > Control Panel Settings > Folder Options'
            'http://www.microsoft.com/GroupPolicy/Settings/PowerOptions'          = 'Preferences > Control Panel Settings > Power Options'
            'http://www.microsoft.com/GroupPolicy/Settings/ScheduledTasks'        = 'Preferences > Control Panel Settings > Scheduled Tasks'
            'http://www.microsoft.com/GroupPolicy/Settings/StartMenu'             = 'Preferences > Control Panel Settings > Start Menu'
            'http://www.microsoft.com/GroupPolicy/Settings/ControlPanel/Internet' = 'Preferences > Control Panel Settings > Internet Settings'
            'http://www.microsoft.com/GroupPolicy/Settings/Lugs'                  = 'Preferences > Control Panel Settings > Local Users and Groups'
        }
        
        # Check current element and parent elements for namespace information
        $currentNode = $Element
        $searchDepth = 0
        
        while ($null -ne $currentNode -and $searchDepth -lt 10) {
            if ($currentNode.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                # Check if the current node's namespace matches any preferences mapping
                if ($currentNode.NamespaceURI -and $namespaceMapping.ContainsKey($currentNode.NamespaceURI)) {
                    return $namespaceMapping[$currentNode.NamespaceURI]
                }
                
                # Also check namespace declarations in the node's attributes
                if ($currentNode.Attributes) {
                    foreach ($attr in $currentNode.Attributes) {
                        if ($attr.Name.StartsWith('xmlns:') -and $namespaceMapping.ContainsKey($attr.Value)) {
                            return $namespaceMapping[$attr.Value]
                        }
                    }
                }
            }
            
            $currentNode = $currentNode.ParentNode
            $searchDepth++
        }
        
        # Walk up the hierarchy to find the right categorization context
        $current = $Element
        $maxDepth = 20
        $depth = 0
        
        while ($current -and $depth -lt $maxDepth) {
            # PRIORITY 1: Administrative Templates (q4:Policy with q4:Category)
            if ($current.LocalName -eq 'Policy' -and $current.NamespaceURI -like '*registry*') {
                $categoryNode = $current.SelectSingleNode('.//*[local-name()="Category"]')
                $nameNode = $current.SelectSingleNode('.//*[local-name()="Name"]')
                
                if ($categoryNode -and $categoryNode.InnerText) {
                    $categoryPath = $categoryNode.InnerText -replace '/', ' > '
                    
                    # Special handling for specific settings that need extended categorization
                    if ($nameNode -and $nameNode.InnerText) {
                        $settingName = $nameNode.InnerText
                        switch -Regex ($settingName) {
                            'Force a specific default lock screen' {
                                if ($categoryPath -eq 'Control Panel > Personalization') {
                                    return 'Administrative Templates > Control Panel > Personalization > Lock Screen'
                                }
                            }
                            'Download missing COM components' {
                                if ($categoryPath -eq 'System') {
                                    return 'Administrative Templates > System > Internet Communication Management > Internet Communication settings'
                                }
                            }
                            'Configure Windows Defender SmartScreen' {
                                if ($categoryPath -like '*Windows Defender SmartScreen*') {
                                    return "Administrative Templates > $categoryPath"
                                }
                            }
                        }
                    }
                    
                    return "Administrative Templates > $categoryPath"
                }
                return 'Administrative Templates'
            }
            
            # PRIORITY 2: Security Settings - Account Policies (q1:Account with types)
            if ($current.LocalName -eq 'Account' -and $current.NamespaceURI -like '*security*') {
                $typeNode = $current.SelectSingleNode('.//*[local-name()="Type"]')
                if ($typeNode -and $typeNode.InnerText) {
                    $type = $typeNode.InnerText
                    switch ($type) {
                        'Password' { return 'Security Settings > Account Policies > Password Policy' }
                        'Kerberos' { return 'Security Settings > Account Policies > Kerberos Policy' }
                        'Audit' { return 'Security Settings > Account Policies > Audit Policy' }
                        { $_ -like '*Account*' } { return 'Security Settings > Account Policies > Account Lockout Policy' }
                        default { return 'Security Settings > Account Policies' }
                    }
                }
                return 'Security Settings > Account Policies'
            }
            
            # PRIORITY 3: System Services (q1:SystemServices) - highest priority for Security Settings
            if ($current.LocalName -eq 'SystemServices' -and $current.NamespaceURI -like '*security*') {
                return 'Security Settings > System Services'
            }
            
            # PRIORITY 3a: Also check if we're inside a SystemServices element (look at parent)
            if ($current.ParentNode -and $current.ParentNode.LocalName -eq 'SystemServices' -and $current.ParentNode.NamespaceURI -like '*security*') {
                return 'Security Settings > System Services'
            }
            
            # PRIORITY 4: Audit policies (q1:Audit)
            if ($current.LocalName -eq 'Audit' -and $current.NamespaceURI -like '*security*') {
                return 'Security Settings > Account Policies > Audit Policy'
            }
            
            # PRIORITY 5: User Rights Assignment (q1:UserRightsAssignment)
            if ($current.LocalName -eq 'UserRightsAssignment' -and $current.NamespaceURI -like '*security*') {
                return 'Security Settings > Local Policies > User Rights Assignment'
            }
            
            # PRIORITY 5a: User Rights Assignment (q1:Privilege) - legacy support
            if ($current.LocalName -eq 'Privilege' -and $current.NamespaceURI -like '*security*') {
                return 'Security Settings > Local Policies > User Rights Assignment'
            }
            
            # PRIORITY 5b: System Services (q1:SystemServices) - Must come before SecurityOptions to avoid conflicts
            if ($current.LocalName -eq 'SystemServices' -and $current.NamespaceURI -like '*security*') {
                return 'Security Settings > System Services'
            }
            
            # PRIORITY 6: Security Options (q1:SecurityOptions) with subcategorization
            if ($current.LocalName -eq 'SecurityOptions' -and $current.NamespaceURI -like '*security*') {
                # Look for Display Name or KeyName to determine subcategory
                $displayNameNode = $current.SelectSingleNode('.//*[local-name()="Name"]')
                $keyNameNode = $current.SelectSingleNode('.//*[local-name()="KeyName"]')
                
                $name = ''
                if ($displayNameNode -and $displayNameNode.InnerText) {
                    $name = $displayNameNode.InnerText
                }
                elseif ($keyNameNode -and $keyNameNode.InnerText) {
                    $name = $keyNameNode.InnerText
                }
                
                # Subcategorize based on content (removed NTDS to avoid conflict with SystemServices)
                switch -Regex ($name) {
                    'LDAP.*server.*signing|Domain.*controller.*LDAP' {
                        return 'Security Settings > Local Policies > Security Options > Domain Controller'
                    }
                    'CD-ROM|Floppy|Device|AllocateCDRoms|AllocateFloppies' {
                        return 'Security Settings > Local Policies > Security Options > Devices'
                    }
                    'SPN|Service.*Principal.*Name|Server.*SPN' {
                        return 'Security Settings > Local Policies > Security Options > Other'
                    }
                    default {
                        return 'Security Settings > Local Policies > Security Options'
                    }
                }
            }
            
            # PRIORITY 7: Other Security Settings patterns
            if ($current.NamespaceURI -like '*security*') {
                $localName = $current.LocalName
                switch ($localName) {
                    'Registry' { return 'Security Settings > Registry' }
                    'RegistryKeys' { return 'Security Settings > Registry' }
                    'File' { return 'Security Settings > File System' }
                    'RestrictedGroups' { return 'Security Settings > Restricted Groups' }
                    'EventLog' { return 'Security Settings > Event Log' }
                    'RegKeys' { 
                        # Check for Security Options vs other registry settings
                        $keyNameNode = $current.SelectSingleNode('.//*[local-name()="KeyName"]')
                        if ($keyNameNode -and $keyNameNode.InnerText -like '*SecurityOptions*') {
                            return 'Security Settings > Local Policies > Security Options'
                        }
                        return 'Security Settings > Registry'
                    }
                    'SecuritySettings' { return 'Security Settings' }
                }
            }
            
            # PRIORITY 8: Auditing namespace (q2:*) with subcategorization
            if ($current.NamespaceURI -like '*auditing*') {
                # Look for AuditSetting ancestor and its SubcategoryName
                $auditSetting = $current
                while ($auditSetting -and $auditSetting.LocalName -ne 'AuditSetting') {
                    $auditSetting = $auditSetting.ParentNode
                    if (-not $auditSetting -or $auditSetting.NodeType -eq 'Document') {
                        break
                    }
                }
                
                if ($auditSetting -and $auditSetting.LocalName -eq 'AuditSetting') {
                    $subcategoryNode = $auditSetting.SelectSingleNode('.//*[local-name()="SubcategoryName"]')
                    if ($subcategoryNode -and $subcategoryNode.InnerText) {
                        $subcategoryName = $subcategoryNode.InnerText
                        switch -Regex ($subcategoryName) {
                            'Kerberos.*Service.*Ticket|Kerberos.*Authentication.*Service' {
                                return 'Security Settings > Advanced Audit Configuration > Account Logon'
                            }
                            'Directory.*Service.*Changes|DS.*Access' {
                                return 'Security Settings > Advanced Audit Configuration > DS Access'
                            }
                            default {
                                return 'Security Settings > Advanced Audit Configuration'
                            }
                        }
                    }
                }
                return 'Security Settings > Advanced Audit Configuration'
            }
            
            # PRIORITY 9: Check for configuration context
            $localName = $current.LocalName
            switch ($localName) {
                'Computer' { return 'Computer Configuration' }
                'User' { return 'User Configuration' }
                'SecuritySettings' { return 'Security Settings' }
                'Extensions' {
                    # Check for specific extension types
                    $xsiType = $current.GetAttribute('xsi:type')
                    if ($xsiType -and $xsiType -match 'RegistrySettings') {
                        return 'Administrative Templates'
                    }
                }
            }
            
            $current = $current.ParentNode
            $depth++
        }
        
        # Default fallback
        return 'Unknown Category'
    }
    catch {
        Write-Verbose "Error building category path: $($_.Exception.Message)"
        return 'Unknown Category'
    }
}

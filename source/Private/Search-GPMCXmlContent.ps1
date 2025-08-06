function Search-GPMCXmlContent {
    <#
    .SYNOPSIS
        Searches XML content for matching patterns and extracts GPO information
        
    .DESCRIPTION
        Internal helper function that performs the core search logic on XML content.
        Returns detailed results including XML node context information for each match.
        
    .PARAMETER XmlString
        The XML content as a string
        
    .PARAMETER SearchString
        Search pattern to look for
        
    .PARAMETER SourceFile
        Source file name for result attribution
        
    .PARAMETER CaseSensitive
        Whether to perform case-sensitive search
        
    .PARAMETER IncludeAllMatches
        Whether to include all matches or filter for meaningful content
        
    .OUTPUTS
        PSCustomObject[] with properties: GPOName, GPOId, DomainName, CategoryPath, SettingName, 
        SettingValue, Context, Section, Comment, SourceFile, CreatedTime, ModifiedTime, XmlNode
        
        The XmlNode property contains enhanced context information:
        - ElementName: The most meaningful XML element containing the match (Policy, Account, etc.)
        - ElementAttributes: Attributes of the context element
        - XmlPath: The element name path with namespace
        - OuterXml: Complete XML of the context element (truncated if > 1000 chars)
        - ParentHierarchy: Array of parent element names (up to 5 levels)
        - ImmediateParent: The direct parent element of the matched text
        - ContextLevel: "Policy" if meaningful parent found, "Element" if immediate parent used
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$XmlString,
        
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SearchString,
        
        [Parameter(Mandatory = $true)]
        [string]$SourceFile,
        
        [Parameter()]
        [switch]$CaseSensitive,
        
        [Parameter()]
        [switch]$IncludeAllMatches
    )
    
    try {
        $results = @()

        Write-Verbose "=== Private Search-GPMCXmlContent function called ==="
        
        # Handle empty or whitespace-only search strings
        if ([string]::IsNullOrWhiteSpace($SearchString)) {
            Write-Verbose "Empty search string provided, returning no results"
            return $results
        }        # Parse XML
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($XmlString)
        
        # Get GPO information
        $gpoInfo = Get-GPMCGpoInfo -XmlDocument $xmlDoc -SourceFilePath $SourceFile
        
        # Convert search string to regex pattern
        $pattern = ConvertTo-RegexPattern -WildcardPattern $SearchString -CaseSensitive $CaseSensitive
        $regex = New-Object System.Text.RegularExpressions.Regex($pattern)
        
        # Search all text nodes
        $textNodes = $xmlDoc.SelectNodes("//text()")
        
        # Separate exact matches from partial matches to prioritize them
        $exactMatches = @()
        $partialMatches = @()

        foreach ($node in $textNodes) {
            $text = $node.Value.Trim()
            
            # Skip empty or whitespace-only content
            if ([string]::IsNullOrWhiteSpace($text)) {
                continue
            }

            # Skip nodes that are within SecurityDescriptor elements
            $currentNode = $node.ParentNode
            $isInSecurityDescriptor = $false
            $maxDepth = 10  # Limit search depth for performance
            $depth = 0
            
            Write-Verbose "Checking text '$text' in node path for SecurityDescriptor"
            
            while ($null -ne $currentNode -and $depth -lt $maxDepth) {
                Write-Verbose "  Checking parent node at depth $depth`: $($currentNode.LocalName)"
                if ($currentNode.LocalName -eq "SecurityDescriptor") {
                    $isInSecurityDescriptor = $true
                    Write-Verbose "  Found SecurityDescriptor ancestor!"
                    break
                }
                $currentNode = $currentNode.ParentNode
                $depth++
            }
            
            if ($isInSecurityDescriptor) {
                Write-Verbose "Skipping match in SecurityDescriptor: $text"
                continue
            } else {
                Write-Verbose "Text '$text' is NOT in SecurityDescriptor, proceeding with check"
            }

            # Check if text matches the pattern
            if ($regex.IsMatch($text)) {
                # Get section information
                $section = Get-GPMCSettingSection -Element $node.ParentNode
                
                # Get comment information
                $comment = Get-GPMCSettingComment -Element $node.ParentNode
                
                # Get XML node context information with enhanced policy-level context
                $parentElement = $node.ParentNode
                
                # Find the most meaningful parent element (Policy, Account, Audit, etc.)
                $meaningfulParent = $parentElement
                $currentNode = $parentElement
                $searchDepth = 0
                $maxSearchDepth = 10
                
                # Look for meaningful parent elements that represent complete policies or settings
                $meaningfulElementNames = @('Policy', 'Account', 'Audit', 'UserRightsAssignment', 'SecurityOptions', 'EventLog', 'RestrictedGroups', 'SystemServices', 'File', 'Registry', 'AuditSetting')
                
                while ($null -ne $currentNode -and $searchDepth -lt $maxSearchDepth) {
                    if ($meaningfulElementNames -contains $currentNode.LocalName) {
                        $meaningfulParent = $currentNode
                        Write-Verbose "Found meaningful parent: $($currentNode.LocalName) at depth $searchDepth"
                        break
                    }
                    $currentNode = $currentNode.ParentNode
                    $searchDepth++
                }
                
                # Use the meaningful parent for XML context, fall back to immediate parent if none found
                $contextElement = if ($meaningfulParent -ne $parentElement) { $meaningfulParent } else { $parentElement }
                
                $xmlNodeInfo = [PSCustomObject]@{
                    ElementName = $contextElement.LocalName
                    ElementAttributes = if ($contextElement.Attributes -and $contextElement.Attributes.Count -gt 0) {
                        @($contextElement.Attributes | ForEach-Object { "$($_.Name)='$($_.Value)'" }) -join '; '
                    } else { $null }
                    XmlPath = $contextElement.Name
                    OuterXml = if ($contextElement.OuterXml.Length -gt 1000) { 
                        $contextElement.OuterXml.Substring(0, 1000) + "..." 
                    } else { 
                        $contextElement.OuterXml 
                    }
                    ParentHierarchy = @()
                    ImmediateParent = $parentElement.LocalName
                    ContextLevel = if ($meaningfulParent -ne $parentElement) { "Policy" } else { "Element" }
                }
                
                # Build parent hierarchy for context (limited to 5 levels for readability)
                $hierarchyList = [System.Collections.ArrayList]@()
                $currentParent = $contextElement.ParentNode
                $hierarchyDepth = 0
                while ($null -ne $currentParent -and $hierarchyDepth -lt 5 -and $currentParent.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                    $hierarchyList.Add($currentParent.LocalName) | Out-Null
                    $currentParent = $currentParent.ParentNode
                    $hierarchyDepth++
                }
                
                # Reverse hierarchy to show from root to immediate parent and convert to array
                $hierarchyList.Reverse()
                $xmlNodeInfo.ParentHierarchy = [array]$hierarchyList

                # Create result object
                $result = [PSCustomObject]@{
                    GPOName = $gpoInfo.DisplayName
                    GPOId = $gpoInfo.GUID
                    DomainName = $gpoInfo.DomainName
                    CategoryPath = Get-GPMCCategoryPath -Element $node.ParentNode
                    SettingName = Get-GPMCSettingDetails -Element $node.ParentNode | Select-Object -ExpandProperty Name
                    SettingValue = $text
                    Context = Get-GPMCSettingContext -Element $node.ParentNode
                    Section = $section
                    Comment = $comment
                    SourceFile = $SourceFile
                    CreatedTime = $gpoInfo.CreatedTime
                    ModifiedTime = $gpoInfo.ModifiedTime
                    XmlNode = $xmlNodeInfo
                }
                
                # Determine if this is an exact match or partial match
                # Remove wildcard characters from search string for exact comparison
                $cleanSearchString = $SearchString -replace '[\*\?]', ''
                if ($text -eq $cleanSearchString -or ($text -like $SearchString -and $text.Length -eq $cleanSearchString.Length)) {
                    $exactMatches += $result
                } else {
                    $partialMatches += $result
                }
            }
        }
        
        # Return exact matches first, then partial matches
        $results = $exactMatches + $partialMatches
        
        return $results
    }
    catch {
        Write-Error "Failed to search XML content: $($_.Exception.Message)"
        return @()
    }
}

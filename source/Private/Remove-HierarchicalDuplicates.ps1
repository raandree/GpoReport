function Remove-HierarchicalDuplicates {
    <#
    .SYNOPSIS
    Removes hierarchical duplicates from search results while preserving legitimate different results.
    
    .DESCRIPTION
    This function analyzes search results to identify and remove hierarchical duplicates where
    a child element duplicate is found within a parent element. Uses a two-phase approach:
    1. Groups results by XmlPath and category path to find potential duplicates from same XML element
    2. Within each group, applies parent-child relationship detection
    
    .PARAMETER Results
    Array of search result objects to deduplicate
    
    .PARAMETER IncludeChildDuplicates
    When specified, returns all duplicates including child elements that would normally be filtered
    
    .EXAMPLE
    $deduplicatedResults = Remove-HierarchicalDuplicates -Results $searchResults
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Array]$Results,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeChildDuplicates
    )
    
    if ($IncludeChildDuplicates) {
        Write-Verbose 'IncludeChildDuplicates specified - returning all results without deduplication'
        return $Results
    }
    
    if ($Results.Count -le 1) {
        Write-Verbose "Only $($Results.Count) result(s) - no deduplication needed"
        return $Results
    }
    
    Write-Verbose "Starting deduplication process with $($Results.Count) results"
    
    # Phase 1: Group by XmlPath, CategoryPath, and OuterXml to find exact duplicates
    # Results with the same XmlPath (same XML element) in the same category AND same OuterXml
    # are exact duplicates. Different elements that share the same XmlPath (e.g., multiple
    # RestrictedGroups entries with different group names) are kept as distinct results.
    $exactDuplicateGroups = @()
    foreach ($result in $Results) {
        $xmlPath = $result.XmlNode.XmlPath
        $categoryPath = $result.CategoryPath
        $outerXmlHash = if ($result.XmlNode.OuterXml) { $result.XmlNode.OuterXml.GetHashCode() } else { 0 }
        $groupKey = "$xmlPath|$categoryPath|$outerXmlHash"
        Write-Verbose "Creating exact duplicate group key: '$groupKey' (XmlPath='$xmlPath', CategoryPath='$categoryPath')"
        
        $existingGroup = $exactDuplicateGroups | Where-Object { $_.Name -eq $groupKey }
        if ($existingGroup) {
            $existingGroup.Group += $result
        }
        else {
            $exactDuplicateGroups += [PSCustomObject]@{
                Name  = $groupKey
                Group = @($result)
                Count = 1
            }
        }
    }
    
    # Update Count property
    foreach ($group in $exactDuplicateGroups) {
        $group.Count = $group.Group.Count
    }
    
    # Phase 1.5: Remove exact duplicates within each XmlPath group
    $afterExactDeduplication = @()
    $exactDuplicatesRemoved = 0
    
    foreach ($group in $exactDuplicateGroups) {
        if ($group.Count -eq 1) {
            # No exact duplicates, keep the result
            $afterExactDeduplication += $group.Group[0]
        }
        else {
            Write-Verbose "Removing $($group.Count - 1) exact duplicates for XmlPath/Category '$($group.Name)'"
            # Keep only the first result, remove exact duplicates
            $afterExactDeduplication += $group.Group[0]
            $exactDuplicatesRemoved += ($group.Count - 1)
        }
    }
    
    Write-Verbose "After exact duplicate removal: $($Results.Count) -> $($afterExactDeduplication.Count) results (removed $exactDuplicatesRemoved exact duplicates)"
    
    # Phase 2: Group remaining results by CategoryPath to check for parent-child relationships
    $categoryGroups = @{}
    foreach ($result in $afterExactDeduplication) {
        $categoryPath = $result.CategoryPath
        if (-not $categoryGroups.ContainsKey($categoryPath)) {
            $categoryGroups[$categoryPath] = @()
        }
        $categoryGroups[$categoryPath] += $result
    }
    
    # Phase 3: Check for parent-child relationships within each category
    $deduplicatedResults = @()
    $parentChildDuplicatesRemoved = 0
    
    foreach ($categoryPath in $categoryGroups.Keys) {
        $categoryResults = $categoryGroups[$categoryPath]
        
        if ($categoryResults.Count -eq 1) {
            # Only one result in this category, no parent-child relationships possible
            $deduplicatedResults += $categoryResults[0]
            continue
        }
        
        Write-Verbose "Processing $($categoryResults.Count) results for parent-child relationships in Category '$categoryPath'"
        
        # Build a hierarchy map to track all parent-child relationships
        $parentChildMap = @{}  # Key: child index, Value: array of parent indices
        
        for ($i = 0; $i -lt $categoryResults.Count; $i++) {
            for ($j = 0; $j -lt $categoryResults.Count; $j++) {
                if ($i -eq $j) { continue }
                
                $result1 = $categoryResults[$i]
                $result2 = $categoryResults[$j]
                
                # Check if result1's XML contains result2's XML (result1 is parent, result2 is child)
                # Handle XML namespace differences by checking if the parent contains the child content
                if ($result1.XmlNode.OuterXml -and $result2.XmlNode.OuterXml -and
                    $result1.XmlNode.OuterXml.Length -gt $result2.XmlNode.OuterXml.Length) {
                    
                    # Remove namespace declarations to normalize comparison
                    $parent = $result1.XmlNode.OuterXml -replace '\s+xmlns:\w+="[^"]*"', ''
                    $child = $result2.XmlNode.OuterXml -replace '\s+xmlns:\w+="[^"]*"', ''
                    
                    if ($parent.Contains($child)) {
                        Write-Verbose "Found parent-child relationship: '$($result1.XmlNode.XmlPath)' (index $i) contains '$($result2.XmlNode.XmlPath)' (index $j)"
                        
                        # Track this relationship
                        if (-not $parentChildMap.ContainsKey($j)) {
                            $parentChildMap[$j] = @()
                        }
                        $parentChildMap[$j] += $i
                    }
                }
            }
        }
        
        if ($parentChildMap.Count -eq 0) {
            Write-Verbose "No parent-child relationships found in category '$categoryPath', keeping all $($categoryResults.Count) results"
            $deduplicatedResults += $categoryResults
        }
        else {
            # Determine which results to keep
            # Strategy: Keep only the top-level parent (the one that isn't a child of anything else)
            # If multiple top-level parents exist, keep the first one encountered
            
            $childIndices = $parentChildMap.Keys
            $parentIndices = $parentChildMap.Values | ForEach-Object { $_ } | Sort-Object -Unique
            
            # Find top-level parents (parents that are not children of anything)
            $topLevelParents = $parentIndices | Where-Object { $childIndices -notcontains $_ }
            
            # If we have top-level parents, keep only the first one
            # All children and nested parents will be removed
            if ($topLevelParents) {
                $primaryParentIndex = $topLevelParents[0]
                Write-Verbose "Identified primary parent at index $primaryParentIndex with element '$($categoryResults[$primaryParentIndex].XmlNode.XmlPath)'"
                
                # Mark all children for removal
                $indicesToRemove = @()
                foreach ($childIndex in $childIndices) {
                    $indicesToRemove += $childIndex
                }
                
                # Also remove other top-level parents that are duplicates
                foreach ($otherParent in $topLevelParents | Where-Object { $_ -ne $primaryParentIndex }) {
                    $indicesToRemove += $otherParent
                }
                
                $indicesToRemove = $indicesToRemove | Sort-Object -Unique
                Write-Verbose "Removing $($indicesToRemove.Count) child/duplicate results from category '$categoryPath'"
                
                for ($i = 0; $i -lt $categoryResults.Count; $i++) {
                    if ($indicesToRemove -notcontains $i) {
                        $deduplicatedResults += $categoryResults[$i]
                    }
                    else {
                        $parentChildDuplicatesRemoved++
                    }
                }
            }
            else {
                # All results are in parent-child relationships, keep the first parent
                # This handles circular references or complex hierarchies
                Write-Verbose 'Complex hierarchy detected, keeping first parent only'
                $deduplicatedResults += $categoryResults[0]
                $parentChildDuplicatesRemoved += ($categoryResults.Count - 1)
            }
        }
    }
    
    $totalDuplicatesRemoved = $exactDuplicatesRemoved + $parentChildDuplicatesRemoved
    Write-Verbose "Deduplication complete: $($Results.Count) -> $($deduplicatedResults.Count) results (removed $totalDuplicatesRemoved duplicates: $exactDuplicatesRemoved exact + $parentChildDuplicatesRemoved parent-child)"
    
    return $deduplicatedResults
}

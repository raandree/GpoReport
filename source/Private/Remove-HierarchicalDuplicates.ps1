function Remove-HierarchicalDuplicates {
    <#
    .SYNOPSIS
    Removes hierarchical duplicates from search results while preserving legitimate different results.
    
    .DESCRIPTION
    This function analyzes search results to identify and remove hierarchical duplicates where
    a child element duplicate is found within a parent element. Uses a two-phase approach:
    1. Groups results by matched text and category path to find potential duplicates
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
        Write-Verbose "IncludeChildDuplicates specified - returning all results without deduplication"
        return $Results
    }
    
    if ($Results.Count -le 1) {
        Write-Verbose "Only $($Results.Count) result(s) - no deduplication needed"
        return $Results
    }
    
    Write-Verbose "Starting deduplication process with $($Results.Count) results"
    
    # Phase 1: Group by matched text and category path to find potential duplicates
    # Only results with the same matched text in the same category could be duplicates
    $potentialDuplicateGroups = $Results | Group-Object -Property { 
        "$($_.MatchedText)|$($_.CategoryPath)"
    }
    
    $deduplicatedResults = @()
    $duplicatesRemoved = 0
    
    foreach ($group in $potentialDuplicateGroups) {
        if ($group.Count -eq 1) {
            # No duplicates for this matched text/category, keep the result
            $deduplicatedResults += $group.Group[0]
            continue
        }
        
        Write-Verbose "Processing $($group.Count) potential duplicates for '$($group.Name)'"
        
        # Phase 2: Within each group, check for parent-child relationships
        $groupResults = $group.Group
        $parentChildPairs = @()
        
        for ($i = 0; $i -lt $groupResults.Count; $i++) {
            for ($j = 0; $j -lt $groupResults.Count; $j++) {
                if ($i -eq $j) { continue }
                
                $result1 = $groupResults[$i]
                $result2 = $groupResults[$j]
                
                # Check for parent-child relationship by examining OuterXml containment
                if ($result1.XmlNode.OuterXml -and $result2.XmlNode.OuterXml -and
                    $result1.XmlNode.OuterXml.Length -gt $result2.XmlNode.OuterXml.Length -and
                    $result1.XmlNode.OuterXml.Contains($result2.XmlNode.OuterXml)) {
                    
                    $parentChildPairs += @{
                        Parent = $result1
                        Child = $result2
                        ParentElement = $result1.XmlNode.ElementName
                        ChildElement = $result2.XmlNode.ElementName
                    }
                    
                    Write-Verbose "Found parent-child relationship: $($result1.XmlNode.ElementName) contains $($result2.XmlNode.ElementName)"
                }
            }
        }
        
        if ($parentChildPairs.Count -gt 0) {
            # We have hierarchical duplicates - keep parents, remove children
            $childResults = $parentChildPairs | ForEach-Object { $_.Child }
            $resultsToKeep = $groupResults | Where-Object { $_ -notin $childResults }
            
            Write-Verbose "Removing $($childResults.Count) child duplicate(s), keeping $($resultsToKeep.Count) parent(s)"
            $duplicatesRemoved += $childResults.Count
            
            $deduplicatedResults += $resultsToKeep
        } else {
            # No parent-child relationships found, but they have same matched text/category
            # These might be exact duplicates - keep only the first one
            Write-Verbose "No hierarchical relationship found for same matched text, treating as exact duplicates"
            $duplicatesRemoved += ($groupResults.Count - 1)
            
            $deduplicatedResults += $groupResults[0]
        }
    }
    
    Write-Verbose "Deduplication complete: $($Results.Count) -> $($deduplicatedResults.Count) results (removed $duplicatesRemoved duplicates)"
    return $deduplicatedResults
}

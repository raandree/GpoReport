<#
.SYNOPSIS
    Searches for Group Policy settings using wildcard patterns and returns the GPO context and path.

.DESCRIPTION
    This script searches through Group Policy report XML files for settings that match a wildcard pattern.
    It returns the Group Policy Object (GPO) information, the category/path where the setting was found,
    and the setting details.

.PARAMETER Path
    The path to the XML file to search. Supports both XML and JSON formats.

.PARAMETER SearchString
    The search string to look for. Supports wildcards (*).

.PARAMETER CaseSensitive
    If specified, performs case-sensitive search. Default is case-insensitive.

.PARAMETER IncludeAllMatches
    If specified, includes all matching text elements, not just those with meaningful content.

.PARAMETER MaxResults
    Maximum number of results to return. Default is unlimited (0).

.EXAMPLE
    .\Search-GPOSettings.ps1 -Path ".\2.xml" -SearchString "*Silently install*"
    Searches for settings containing "Silently install" in the specified XML file.

.EXAMPLE
    .\Search-GPOSettings.ps1 -Path ".\2.xml" -SearchString "*password*" -CaseSensitive
    Performs a case-sensitive search for settings containing "password".

.EXAMPLE
    .\Search-GPOSettings.ps1 -Path ".\2.xml" -SearchString "*audit*" -MaxResults 10
    Returns up to 10 matches for settings containing "audit".
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "File not found: $_"
        }
        if ($_ -notmatch '\.(xml|json)$') {
            throw "File must be either XML or JSON format"
        }
        return $true
    })]
    [string]$Path,
    
    [Parameter(Mandatory = $true, Position = 1)]
    [string]$SearchString,
    
    [Parameter()]
    [switch]$CaseSensitive,
    
    [Parameter()]
    [switch]$IncludeAllMatches,
    
    [Parameter()]
    [int]$MaxResults = 0
)

# Convert wildcard pattern to regex
function ConvertTo-RegexPattern {
    param([string]$WildcardPattern, [bool]$CaseSensitive = $false)
    
    # Escape special regex characters except * and ?
    $escaped = [regex]::Escape($WildcardPattern)
    
    # Convert wildcards to regex
    $pattern = $escaped -replace '\\\*', '.*' -replace '\\\?', '.'
    
    if (-not $CaseSensitive) {
        return "(?i)$pattern"
    }
    return $pattern
}

# Extract GPO information from a node
function Get-GpoInfo {
    param($Node)
    
    $gpoInfo = @{
        DisplayName = "Unknown"
        DomainName = "Unknown"  
        GUID = "Unknown"
        GpoType = "Unknown"
        PolicyName = $null
        PolicyState = $null
        PolicyCategory = $null
    }
    
    # Try to find GPO information in the current node or its ancestors
    $currentNode = $Node
    $searchDepth = 0
    
    while ($null -ne $currentNode -and $searchDepth -lt 30) {
        if ($currentNode.NodeType -eq [System.Xml.XmlNodeType]::Element) {
            # Look for MS (Member Set) elements that contain structured GPO information
            if ($currentNode.LocalName -eq "MS") {
                # Look for child S elements with specific N attributes
                foreach ($child in $currentNode.ChildNodes) {
                    if ($child.LocalName -eq "S" -and $child.HasAttribute("N")) {
                        $attributeName = $child.GetAttribute("N")
                        $attributeValue = $child.InnerText
                        
                        switch ($attributeName) {
                            "DisplayName" { $gpoInfo.DisplayName = $attributeValue }
                            "DomainName" { $gpoInfo.DomainName = $attributeValue }
                            "GUID" { $gpoInfo.GUID = $attributeValue }
                            "GpoType" { $gpoInfo.GpoType = $attributeValue }
                            "PolicyName" { $gpoInfo.PolicyName = $attributeValue }
                            "PolicyState" { $gpoInfo.PolicyState = $attributeValue }
                            "PolicyCategory" { $gpoInfo.PolicyCategory = $attributeValue }
                        }
                    }
                }
                
                # If we found essential GPO info, we can stop
                if ($gpoInfo.DisplayName -ne "Unknown" -and $gpoInfo.GUID -ne "Unknown") {
                    break
                }
            }
            
            # Also try the original approach for fallback
            $displayName = $currentNode.SelectSingleNode(".//S[@N='DisplayName']")
            $domainName = $currentNode.SelectSingleNode(".//S[@N='DomainName']")  
            $guid = $currentNode.SelectSingleNode(".//S[@N='GUID']")
            $gpoType = $currentNode.SelectSingleNode(".//S[@N='GpoType']")
            
            if ($displayName -and $gpoInfo.DisplayName -eq "Unknown") { $gpoInfo.DisplayName = $displayName.InnerText }
            if ($domainName -and $gpoInfo.DomainName -eq "Unknown") { $gpoInfo.DomainName = $domainName.InnerText }
            if ($guid -and $gpoInfo.GUID -eq "Unknown") { $gpoInfo.GUID = $guid.InnerText }
            if ($gpoType -and $gpoInfo.GpoType -eq "Unknown") { $gpoInfo.GpoType = $gpoType.InnerText }
        }
        
        $currentNode = $currentNode.ParentNode
        $searchDepth++
    }
    
    return $gpoInfo
}

# Get the category/path context
function Get-CategoryPath {
    param($Node)
    
    $pathElements = @()
    $currentNode = $Node
    $searchDepth = 0
    
    Write-Verbose "Starting category search for node: $($Node.LocalName) with value: $($Node.InnerText)"
    
    # Look for the main category structure in the PowerShell XML format
    while ($null -ne $currentNode -and $searchDepth -lt 50) {
        if ($currentNode.NodeType -eq [System.Xml.XmlNodeType]::Element) {
            Write-Verbose "Checking node: $($currentNode.LocalName) at depth $searchDepth"
            
            # Look for En (Entry) elements that contain category keys
            if ($currentNode.LocalName -eq "En") {
                $keyElement = $currentNode.SelectSingleNode("./S[@N='Key']")
                if ($keyElement) {
                    $pathElements += $keyElement.InnerText
                    Write-Verbose "Found En category key: $($keyElement.InnerText)"
                } else {
                    # Also try looking for direct child S elements with N='Key'
                    foreach ($child in $currentNode.ChildNodes) {
                        if ($child.LocalName -eq "S" -and $child.HasAttribute("N") -and $child.GetAttribute("N") -eq "Key") {
                            $pathElements += $child.InnerText
                            Write-Verbose "Found En category key (direct child): $($child.InnerText)"
                            break
                        }
                    }
                }
            }
            
            # Look for Key elements that indicate main categories (direct children)
            $keyElement = $currentNode.SelectSingleNode("./S[@N='Key']")
            if ($keyElement) {
                $pathElements += $keyElement.InnerText
                Write-Verbose "Found direct key element: $($keyElement.InnerText)"
            }
            
            # Look for Props sections that might contain category information
            if ($currentNode.LocalName -eq "Props") {
                $categoryElement = $currentNode.SelectSingleNode("./S[@N='PolicyCategory']")
                if ($categoryElement) {
                    $pathElements += $categoryElement.InnerText
                    Write-Verbose "Found PolicyCategory: $($categoryElement.InnerText)"
                }
            }
        }
        $currentNode = $currentNode.ParentNode
        $searchDepth++
    }
    
    Write-Verbose "Found path elements: $($pathElements -join ', ')"
    
    # Remove duplicates and reverse to get path from root to current
    $pathElements = $pathElements | Select-Object -Unique
    if ($pathElements.Count -gt 0) {
        [Array]::Reverse($pathElements)
    }
    
    # Add setting context if available
    $settingContext = Get-SettingContext -Node $Node
    if ($settingContext -and ($pathElements.Count -eq 0 -or $settingContext -ne $pathElements[-1])) {
        $pathElements += $settingContext
        Write-Verbose "Added setting context: $settingContext"
    }
    
    $result = if ($pathElements.Count -gt 0) { 
        ($pathElements -join " > ") 
    } else { 
        "Unknown" 
    }
    
    Write-Verbose "Final category path: $result"
    return $result
}

# Get setting context (like policy names)
function Get-SettingContext {
    param($Node)
    
    $currentNode = $Node
    $searchDepth = 0
    
    while ($null -ne $currentNode -and $searchDepth -lt 10) {
        if ($currentNode.NodeType -eq [System.Xml.XmlNodeType]::Element) {
            # Look for Props section with Name element
            $nameElement = $currentNode.SelectSingleNode("./Props/S[@N='Name']")
            if ($nameElement -and $nameElement.InnerText -ne $Node.InnerText) {
                return $nameElement.InnerText
            }
            
            # Look for Name in sibling elements
            $siblingName = $currentNode.SelectSingleNode("../Props/S[@N='Name']")
            if ($siblingName -and $siblingName.InnerText -ne $Node.InnerText) {
                return $siblingName.InnerText
            }
        }
        $currentNode = $currentNode.ParentNode
        $searchDepth++
    }
    
    return $null
}

# Get setting details from the context
function Get-SettingDetails {
    param($Node)
    
    $details = @{
        Name = "Unknown"
        State = "Unknown" 
        Value = $null
    }
    
    $currentNode = $Node
    $searchDepth = 0
    
    # Look for common setting properties in the nearby context
    while ($null -ne $currentNode -and $searchDepth -lt 15) {
        if ($currentNode.NodeType -eq [System.Xml.XmlNodeType]::Element) {
            
            # Handle MS (Member Set) elements that contain structured information
            if ($currentNode.LocalName -eq "MS") {
                foreach ($child in $currentNode.ChildNodes) {
                    if ($child.LocalName -eq "S" -and $child.HasAttribute("N")) {
                        $attributeName = $child.GetAttribute("N")
                        $attributeValue = $child.InnerText
                        
                        switch ($attributeName) {
                            "PolicyName" { if ($details.Name -eq "Unknown") { $details.Name = $attributeValue } }
                            "PolicyState" { if ($details.State -eq "Unknown") { $details.State = $attributeValue } }
                            "Value" { if ($null -eq $details.Value) { $details.Value = $attributeValue } }
                            "Name" { 
                                # Only use this if we don't have a PolicyName and it's not the matched text
                                if ($details.Name -eq "Unknown" -and $attributeValue -ne $Node.InnerText) { 
                                    $details.Name = $attributeValue 
                                } 
                            }
                            "State" { if ($details.State -eq "Unknown") { $details.State = $attributeValue } }
                        }
                    }
                }
            }
            
            # Look for Props section with Name and State elements
            $nameElement = $currentNode.SelectSingleNode("./Props/S[@N='Name']")
            $stateElement = $currentNode.SelectSingleNode("./Props/S[@N='State']")
            $valueElement = $currentNode.SelectSingleNode("./Props/S[@N='Value']") 
            
            # Also check parent's Props section
            if (-not $nameElement) {
                $nameElement = $currentNode.SelectSingleNode("../Props/S[@N='Name']")
            }
            if (-not $stateElement) {
                $stateElement = $currentNode.SelectSingleNode("../Props/S[@N='State']")
            }
            if (-not $valueElement) {
                $valueElement = $currentNode.SelectSingleNode("../Props/S[@N='Value']")
            }
            
            if ($nameElement -and $details.Name -eq "Unknown") { $details.Name = $nameElement.InnerText }
            if ($stateElement -and $details.State -eq "Unknown") { $details.State = $stateElement.InnerText }
            if ($valueElement -and $null -eq $details.Value) { $details.Value = $valueElement.InnerText }
            
            # Stop if we found meaningful setting information
            if ($details.Name -ne "Unknown" -and $details.State -ne "Unknown") { break }
        }
        
        $currentNode = $currentNode.ParentNode
        $searchDepth++
    }
    
    return $details
}

try {
    # Resolve the full path
    $filePath = Resolve-Path -Path $Path -ErrorAction Stop
    Write-Verbose "Processing file: $filePath"
    
    # Determine file type and load accordingly
    $fileExtension = [System.IO.Path]::GetExtension($filePath).ToLower()
    
    if ($fileExtension -eq '.xml') {
        # Load XML document
        Write-Verbose "Loading XML document..."
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.Load($filePath)
        $searchNodes = $xmlDoc.SelectNodes("//*[text()]")
    }
    elseif ($fileExtension -eq '.json') {
        Write-Verbose "Loading JSON document..."
        $jsonContent = Get-Content -Path $filePath -Raw
        
        # Convert JSON to XML for consistent processing
        $jsonObject = $jsonContent | ConvertFrom-Json
        $xmlContent = $jsonObject | ConvertTo-Xml -Depth 100
        $xmlDoc = [xml]$xmlContent
        $searchNodes = $xmlDoc.SelectNodes("//*[text()]")
    }
    else {
        throw "Unsupported file format: $fileExtension"
    }
    
    # Convert search string to regex pattern
    $regexPattern = ConvertTo-RegexPattern -WildcardPattern $SearchString -CaseSensitive $CaseSensitive.IsPresent
    Write-Verbose "Using regex pattern: $regexPattern"
    
    # Search through all text nodes
    $results = @()
    $resultCount = 0
    
    Write-Verbose "Searching through $($searchNodes.Count) nodes..."
    
    foreach ($node in $searchNodes) {
        if ($MaxResults -gt 0 -and $resultCount -ge $MaxResults) {
            break
        }
        
        $textContent = $node.InnerText
        
        # Skip empty or whitespace-only content unless specifically requested
        if (-not $IncludeAllMatches -and [string]::IsNullOrWhiteSpace($textContent)) {
            continue
        }
        
        # Skip very short content unless it's meaningful
        if (-not $IncludeAllMatches -and $textContent.Length -lt 3) {
            continue
        }
        
        if ($textContent -match $regexPattern) {
            Write-Verbose "Match found: $textContent"
            
            # Get GPO information
            $gpoInfo = Get-GpoInfo -Node $node
            
            # Get category path
            $categoryPath = Get-CategoryPath -Node $node
            
            # Get setting details
            $settingDetails = Get-SettingDetails -Node $node
            
            # Create result object
            $result = [PSCustomObject]@{
                MatchedText = $textContent.Trim()
                GPO = [PSCustomObject]@{
                    DisplayName = $gpoInfo.DisplayName
                    DomainName = $gpoInfo.DomainName
                    GUID = $gpoInfo.GUID
                    Type = $gpoInfo.GpoType
                }
                CategoryPath = if ($categoryPath) { $categoryPath } else { "Unknown" }
                Setting = [PSCustomObject]@{
                    Name = if ($settingDetails.Name -ne "Unknown") { $settingDetails.Name } else { 
                        if ($gpoInfo.PolicyName) { $gpoInfo.PolicyName } else { "Unknown" }
                    }
                    State = if ($settingDetails.State -ne "Unknown") { $settingDetails.State } else { 
                        if ($gpoInfo.PolicyState) { $gpoInfo.PolicyState } else { "Unknown" }
                    }
                    Value = if ($settingDetails.Value) { $settingDetails.Value } else { $null }
                    Category = if ($gpoInfo.PolicyCategory) { $gpoInfo.PolicyCategory } else { $null }
                }
                XPath = $node.OuterXml.Substring(0, [Math]::Min(200, $node.OuterXml.Length)) + "..."
            }
            
            $results += $result
            $resultCount++
            
            # Show progress for large searches
            if ($resultCount % 10 -eq 0) {
                Write-Verbose "Found $resultCount matches so far..."
            }
        }
    }
    
    Write-Host "Search completed. Found $($results.Count) matches." -ForegroundColor Green
    
    if ($results.Count -eq 0) {
        Write-Warning "No matches found for pattern: $SearchString"
        return
    }
    
    # Display results in a more readable format
    Write-Host "`n=== SEARCH RESULTS ===" -ForegroundColor Cyan
    Write-Host "Search Pattern: $SearchString" -ForegroundColor Yellow
    Write-Host "File: $filePath" -ForegroundColor Yellow
    Write-Host ("-" * 80) -ForegroundColor Gray
    
    $resultNumber = 1
    foreach ($result in $results) {
        Write-Host "`n[$resultNumber] MATCH FOUND" -ForegroundColor Green
        Write-Host "Matched Text: " -NoNewline -ForegroundColor White
        Write-Host "$($result.MatchedText)" -ForegroundColor Yellow
        
        Write-Host "`nGPO Details:" -ForegroundColor Cyan
        Write-Host "  Display Name: $($result.GPO.DisplayName)" -ForegroundColor White
        Write-Host "  Domain: $($result.GPO.DomainName)" -ForegroundColor White
        Write-Host "  GUID: $($result.GPO.GUID)" -ForegroundColor White  
        Write-Host "  Type: $($result.GPO.Type)" -ForegroundColor White
        
        Write-Host "`nSetting Details:" -ForegroundColor Cyan
        Write-Host "  Policy Name: $($result.Setting.Name)" -ForegroundColor White
        Write-Host "  State: $($result.Setting.State)" -ForegroundColor White
        if ($result.Setting.Category) {
            Write-Host "  Category: $($result.Setting.Category)" -ForegroundColor White
        }
        if ($result.Setting.Value) {
            Write-Host "  Value: $($result.Setting.Value)" -ForegroundColor White
        }
        
        if ($result.CategoryPath -ne "Unknown") {
            Write-Host "`nCategory Path: $($result.CategoryPath)" -ForegroundColor Magenta
        }
        
        Write-Host ("-" * 80) -ForegroundColor Gray
        $resultNumber++
    }
    
    # Also return the objects for further processing
    return $results
}
catch {
    Write-Error "Error processing file '$Path': $($_.Exception.Message)"
    throw
}

<#
.SYNOPSIS
    Searches for Group Policy settings containing specific text in an XML export file.
.DESCRIPTION
    This function reads an XML file (typically created with Add-ItemIdToXml.ps1) containing 
    Active Directory Group Policy settings and searches for all nodes/settings that contain 
    the specified text. It returns the policies that contain the matching settings.
.PARAMETER Path
    The path to the XML file. Defaults to '2.xml' in the script's directory.
.PARAMETER SearchText
    The text to search for within the GPO settings.
.PARAMETER CaseSensitive
    If specified, performs a case-sensitive search.
.PARAMETER PropertyNamesToSearch
    Array of property names to search within. If not specified, searches all text content.
.PARAMETER OutputFormat
    Specifies the output format: 'Object', 'Summary', or 'Detailed'. Defaults to 'Object'.
.EXAMPLE
    Search-GpoSettings -SearchText "wallpaper"
    Searches for all GPO settings containing "wallpaper" (case-insensitive).
.EXAMPLE
    Search-GpoSettings -Path "C:\data\gpo.xml" -SearchText "Administrator" -CaseSensitive
    Searches for "Administrator" with case-sensitive matching.
.EXAMPLE
    Search-GpoSettings -SearchText "password" -PropertyNamesToSearch @("PolicyName", "PolicyExplain")
    Searches only in PolicyName and PolicyExplain properties.
.EXAMPLE
    Search-GpoSettings -SearchText "enabled" -OutputFormat Detailed
    Searches for "enabled" and outputs detailed information.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$Path,
    
    [Parameter(Mandatory = $true, Position = 1)]
    [string]$SearchText,
    
    [Parameter()]
    [switch]$CaseSensitive,
    
    [Parameter()]
    [string[]]$PropertyNamesToSearch = @(),
    
    [Parameter()]
    [ValidateSet('Object', 'Summary', 'Detailed')]
    [string]$OutputFormat = 'Object'
)

# Resolve full path
$xmlFilePath = Resolve-Path -Path $Path -ErrorAction SilentlyContinue

# Check if the file exists
if (-not $xmlFilePath) {
    throw "XML file not found: $Path"
}

# Function to search text in an object recursively
function Search-InObject {
    param (
        [Parameter(Mandatory = $true)]
        $Object,
        
        [Parameter(Mandatory = $true)]
        [string]$SearchText,
        
        [Parameter()]
        [bool]$CaseSensitive,
        
        [Parameter()]
        [string[]]$PropertyNames,
        
        [Parameter()]
        [string]$Path = "",
        
        [Parameter()]
        [System.Collections.ArrayList]$Results
    )
    
    if ($null -eq $Results) {
        $Results = New-Object System.Collections.ArrayList
    }
    
    # Function to check if text matches
    function Test-TextMatch {
        param($Text, $SearchText, $CaseSensitive)
        
        if ($null -eq $Text) { return $false }
        
        if ($CaseSensitive) {
            return $Text.ToString().Contains($SearchText)
        }
        else {
            return $Text.ToString().ToLower().Contains($SearchText.ToLower())
        }
    }
    
    # Handle different object types
    if ($Object -is [System.Xml.XmlNode]) {
        # For XML nodes, check attributes and inner text
        foreach ($attr in $Object.Attributes) {
            if ($PropertyNames.Count -eq 0 -or $PropertyNames -contains $attr.Name) {
                if (Test-TextMatch -Text $attr.Value -SearchText $SearchText -CaseSensitive $CaseSensitive) {
                    $matchInfo = @{
                        Path = "$Path/@$($attr.Name)"
                        PropertyName = $attr.Name
                        Value = $attr.Value
                        Context = $Object.OuterXml
                        ItemId = $Object.GetAttribute("ItemId")
                    }
                    [void]$Results.Add($matchInfo)
                }
            }
        }
        
        # Check inner text
        if ($Object.InnerText -and ($PropertyNames.Count -eq 0 -or $PropertyNames -contains "#text")) {
            if (Test-TextMatch -Text $Object.InnerText -SearchText $SearchText -CaseSensitive $CaseSensitive) {
                $matchInfo = @{
                    Path = "$Path/#text"
                    PropertyName = "#text"
                    Value = $Object.InnerText
                    Context = $Object.OuterXml
                    ItemId = $Object.GetAttribute("ItemId")
                }
                [void]$Results.Add($matchInfo)
            }
        }
        
        # Recurse through child nodes
        foreach ($child in $Object.ChildNodes) {
            if ($child -is [System.Xml.XmlElement]) {
                $childPath = "$Path/$($child.LocalName)"
                Search-InObject -Object $child -SearchText $SearchText -CaseSensitive $CaseSensitive `
                    -PropertyNames $PropertyNames -Path $childPath -Results $Results
            }
        }
    }
    elseif ($Object -is [System.Management.Automation.PSCustomObject] -or $Object -is [hashtable]) {
        # For PSCustomObject or hashtable
        foreach ($property in $Object.PSObject.Properties) {
            $propPath = if ($Path) { "$Path.$($property.Name)" } else { $property.Name }
            
            if ($null -ne $property.Value) {
                # Check if we should search this property
                if ($PropertyNames.Count -eq 0 -or $PropertyNames -contains $property.Name) {
                    if ($property.Value -is [string]) {
                        if (Test-TextMatch -Text $property.Value -SearchText $SearchText -CaseSensitive $CaseSensitive) {
                            $matchInfo = @{
                                Path = $propPath
                                PropertyName = $property.Name
                                Value = $property.Value
                                Context = $Object
                                ItemId = $Object.ItemId
                            }
                            [void]$Results.Add($matchInfo)
                        }
                    }
                }
                
                # Recurse into property value
                if ($property.Value -is [System.Management.Automation.PSCustomObject] -or 
                    $property.Value -is [hashtable] -or 
                    $property.Value -is [System.Collections.IEnumerable]) {
                    Search-InObject -Object $property.Value -SearchText $SearchText -CaseSensitive $CaseSensitive `
                        -PropertyNames $PropertyNames -Path $propPath -Results $Results
                }
            }
        }
    }
    elseif ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string]) {
        # Handle arrays/collections
        $index = 0
        foreach ($item in $Object) {
            if ($null -ne $item) {
                $itemPath = "$Path[$index]"
                Search-InObject -Object $item -SearchText $SearchText -CaseSensitive $CaseSensitive `
                    -PropertyNames $PropertyNames -Path $itemPath -Results $Results
                $index++
            }
        }
    }
    
    return $Results
}

# Function to extract GPO information from a match
function Get-GpoInfoFromMatch {
    param (
        [Parameter(Mandatory = $true)]
        $Match,
        
        [Parameter(Mandatory = $true)]
        $RootObject
    )
    
    # Try to find the GPO information by traversing up the path
    $pathParts = $Match.Path -split '[./\[\]]' | Where-Object { $_ }
    
    # Look for common GPO properties
    $gpoInfo = @{
        DisplayName = $null
        DomainName = $null
        GUID = $null
        GpoType = $null
        Category = $null
        MatchedProperty = $Match.PropertyName
        MatchedValue = $Match.Value
        MatchPath = $Match.Path
    }
    
    # If we have context object, try to extract GPO info
    if ($Match.Context -is [System.Management.Automation.PSCustomObject]) {
        $contextObj = $Match.Context
        
        # Direct properties
        if ($contextObj.DisplayName) { $gpoInfo.DisplayName = $contextObj.DisplayName }
        if ($contextObj.DomainName) { $gpoInfo.DomainName = $contextObj.DomainName }
        if ($contextObj.GUID) { $gpoInfo.GUID = $contextObj.GUID }
        if ($contextObj.GpoType) { $gpoInfo.GpoType = $contextObj.GpoType }
        
        # Try to find category from the path
        if ($pathParts.Count -gt 0) {
            $gpoInfo.Category = $pathParts[0]
        }
    }
    
    return $gpoInfo
}

# Main execution
try {
    Write-Verbose "Reading XML file: $xmlFilePath"
    
    # Try to load as XML first
    $xmlDoc = New-Object System.Xml.XmlDocument
    try {
        $xmlDoc.Load($xmlFilePath)
        $rootObject = $xmlDoc.DocumentElement
        $isXmlFormat = $true
    }
    catch {
        # If XML loading fails, try to import as PowerShell serialized object
        Write-Verbose "Failed to load as XML, trying as PowerShell serialized object"
        $rootObject = Import-Clixml -Path $xmlFilePath
        $isXmlFormat = $false
    }
    
    Write-Verbose "Searching for: '$SearchText' (Case Sensitive: $CaseSensitive)"
    if ($PropertyNamesToSearch.Count -gt 0) {
        Write-Verbose "Searching in properties: $($PropertyNamesToSearch -join ', ')"
    }
    
    # Perform the search
    $matches = Search-InObject -Object $rootObject -SearchText $SearchText `
        -CaseSensitive $CaseSensitive.IsPresent -PropertyNames $PropertyNamesToSearch
    
    Write-Verbose "Found $($matches.Count) matches"
    
    if ($matches.Count -eq 0) {
        Write-Host "No matches found for '$SearchText'" -ForegroundColor Yellow
        return
    }
    
    # Process results based on output format
    switch ($OutputFormat) {
        'Summary' {
            # Group by GPO
            $gpoGroups = @{}
            
            foreach ($match in $matches) {
                $gpoInfo = Get-GpoInfoFromMatch -Match $match -RootObject $rootObject
                $key = "$($gpoInfo.DisplayName)|$($gpoInfo.GUID)"
                
                if (-not $gpoGroups.ContainsKey($key)) {
                    $gpoGroups[$key] = @{
                        Info = $gpoInfo
                        Matches = @()
                    }
                }
                
                $gpoGroups[$key].Matches += $match
            }
            
            # Output summary
            Write-Host "`nFound $($matches.Count) matches in $($gpoGroups.Count) GPOs:" -ForegroundColor Green
            Write-Host "=" * 60
            
            foreach ($gpoGroup in $gpoGroups.Values) {
                $info = $gpoGroup.Info
                Write-Host "`nGPO: $($info.DisplayName)" -ForegroundColor Cyan
                Write-Host "  GUID: $($info.GUID)"
                Write-Host "  Domain: $($info.DomainName)"
                Write-Host "  Type: $($info.GpoType)"
                Write-Host "  Matches: $($gpoGroup.Matches.Count)"
                
                foreach ($match in $gpoGroup.Matches | Select-Object -First 5) {
                    Write-Host "    - $($match.PropertyName): $($match.Value.Substring(0, [Math]::Min(50, $match.Value.Length)))..." -ForegroundColor Gray
                }
                
                if ($gpoGroup.Matches.Count -gt 5) {
                    Write-Host "    ... and $($gpoGroup.Matches.Count - 5) more matches" -ForegroundColor DarkGray
                }
            }
        }
        
        'Detailed' {
            # Output detailed information
            Write-Host "`nDetailed search results for '$SearchText':" -ForegroundColor Green
            Write-Host "=" * 80
            
            $matchNum = 1
            foreach ($match in $matches) {
                Write-Host "`nMatch #$matchNum" -ForegroundColor Yellow
                Write-Host "  Path: $($match.Path)"
                Write-Host "  Property: $($match.PropertyName)"
                Write-Host "  Value: $($match.Value)"
                if ($match.ItemId) {
                    Write-Host "  ItemId: $($match.ItemId)" -ForegroundColor DarkGray
                }
                
                # Try to get GPO info
                $gpoInfo = Get-GpoInfoFromMatch -Match $match -RootObject $rootObject
                if ($gpoInfo.DisplayName) {
                    Write-Host "  GPO: $($gpoInfo.DisplayName)" -ForegroundColor Cyan
                    Write-Host "  GUID: $($gpoInfo.GUID)"
                }
                
                $matchNum++
            }
        }
        
        Default {
            # Return objects
            $results = @()
            
            foreach ($match in $matches) {
                $gpoInfo = Get-GpoInfoFromMatch -Match $match -RootObject $rootObject
                
                $resultObject = [PSCustomObject]@{
                    DisplayName = $gpoInfo.DisplayName
                    GUID = $gpoInfo.GUID
                    DomainName = $gpoInfo.DomainName
                    GpoType = $gpoInfo.GpoType
                    Category = $gpoInfo.Category
                    MatchedProperty = $match.PropertyName
                    MatchedValue = $match.Value
                    MatchPath = $match.Path
                    ItemId = $match.ItemId
                }
                
                $results += $resultObject
            }
            
            return $results
        }
    }
}
catch {
    throw $_
}

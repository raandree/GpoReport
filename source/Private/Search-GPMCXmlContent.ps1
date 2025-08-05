function Search-GPMCXmlContent {
    <#
    .SYNOPSIS
        Searches XML content for matching patterns and extracts GPO information
        
    .DESCRIPTION
        Internal helper function that performs the core search logic on XML content
        
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
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$XmlString,
        
        [Parameter(Mandatory = $true)]
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
        
        # Parse XML
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.LoadXml($XmlString)
        
        # Get GPO information
        $gpoInfo = Get-GPMCGpoInfo -XmlDocument $xmlDoc -SourceFilePath $SourceFile
        
        # Convert search string to regex pattern
        $pattern = ConvertTo-RegexPattern -WildcardPattern $SearchString -CaseSensitive $CaseSensitive
        $regex = New-Object System.Text.RegularExpressions.Regex($pattern)
        
        # Search all text nodes
        $textNodes = $xmlDoc.SelectNodes("//text()")
        
        foreach ($node in $textNodes) {
            $text = $node.Value.Trim()
            
            # Skip empty or whitespace-only content
            if ([string]::IsNullOrWhiteSpace($text)) {
                continue
            }
            
            # Check if text matches the pattern
            if ($regex.IsMatch($text)) {
                # Get section information
                $section = Get-GPMCSettingSection -Element $node.ParentNode
                
                # Get comment information
                $comment = Get-GPMCSettingComment -Element $node.ParentNode
                
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
                }
                
                $results += $result
            }
        }
        
        return $results
    }
    catch {
        Write-Error "Failed to search XML content: $($_.Exception.Message)"
        return @()
    }
}

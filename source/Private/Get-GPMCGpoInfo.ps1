function Get-GPMCGpoInfo {
    <#
    .SYNOPSIS
        Extracts GPO information from GPMC XML document
        
    .DESCRIPTION
        Internal helper function to extract GPO metadata like name, GUID, domain from GPMC XML
        
    .PARAMETER XmlDocument
        The XML document to extract info from
        
    .PARAMETER SourceFilePath
        Optional source file path for fallback naming
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$XmlDocument,
        
        [Parameter()]
        [string]$SourceFilePath = $null
    )
    
    $gpoInfo = @{
        DisplayName = "Unknown"
        DomainName = "Unknown"  
        GUID = "Unknown"
        CreatedTime = $null
        ModifiedTime = $null
    }
    
    try {
        # Use source file path for display name fallback if provided
        if ($SourceFilePath) {
            $gpoInfo.DisplayName = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path $SourceFilePath -Leaf))
        }
        elseif ($XmlDocument.BaseURI) {
            $gpoInfo.DisplayName = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path $XmlDocument.BaseURI -Leaf))
        }
        
        # Try to get the actual GPO name from XML structure
        $nameElement = $XmlDocument.SelectSingleNode("//*[local-name()='Name' and not(*)]")
        if ($nameElement -and $nameElement.ParentNode.LocalName -eq "GPO") {
            $gpoInfo.DisplayName = $nameElement.InnerText
        }
        
        # Try alternative structure for name
        $nElements = $XmlDocument.SelectNodes("//*[local-name()='n']")
        foreach ($elem in $nElements) {
            if ($elem.ParentNode -and $elem.ParentNode.LocalName -eq "GPO") {
                $gpoInfo.DisplayName = $elem.InnerText
                break
            }
        }
        
        # Get domain and GUID from Identifier section
        $domainElement = $XmlDocument.SelectSingleNode("//*[local-name()='Domain']")
        if ($domainElement) {
            $gpoInfo.DomainName = $domainElement.InnerText
        }
        
        $guidElement = $XmlDocument.SelectSingleNode("//*[local-name()='Identifier' and not(*)]")
        if ($guidElement) {
            $gpoInfo.GUID = $guidElement.InnerText -replace '[{}]', ''
        }
        
        # Get timestamps
        $createdElement = $XmlDocument.SelectSingleNode("//CreatedTime")
        if ($createdElement) {
            $gpoInfo.CreatedTime = $createdElement.InnerText
        }
        
        $modifiedElement = $XmlDocument.SelectSingleNode("//ModifiedTime")
        if ($modifiedElement) {
            $gpoInfo.ModifiedTime = $modifiedElement.InnerText
        }
    }
    catch {
        Write-Verbose "Error extracting GPO info: $($_.Exception.Message)"
    }
    
    return $gpoInfo
}

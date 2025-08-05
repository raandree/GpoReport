function Search-GPMCXmlFile {
    <#
    .SYNOPSIS
        Searches a single GPMC XML file for matching patterns
        
    .DESCRIPTION
        Internal helper function to process a single GPMC XML file and find matching patterns
        
    .PARAMETER FilePath
        Path to the XML file to search
        
    .PARAMETER SearchString
        Search pattern to look for
        
    .PARAMETER CaseSensitive
        Whether to perform case-sensitive search
        
    .PARAMETER IncludeAllMatches
        Whether to include all matches or filter for meaningful content
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$SearchString,
        
        [Parameter()]
        [switch]$CaseSensitive,
        
        [Parameter()]
        [switch]$IncludeAllMatches
    )
    
    try {
        Write-Verbose "Processing file: $FilePath"
        
        if (-not (Test-Path $FilePath)) {
            Write-Warning "File not found: $FilePath"
            return @()
        }
        
        # Read and parse XML
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.Load($FilePath)
        
        # Use the XML content search function
        return Search-GPMCXmlContent -XmlString $xmlDoc.OuterXml -SearchString $SearchString -SourceFile $FilePath -CaseSensitive:$CaseSensitive -IncludeAllMatches:$IncludeAllMatches
    }
    catch {
        Write-Error "Failed to process XML file $FilePath`: $($_.Exception.Message)"
        return @()
    }
}

<#
.SYNOPSIS
    Adds a GUID attribute named ItemId to every element in the XML file recursively.
.DESCRIPTION
    This script reads an XML file, adds a unique GUID attribute named 'ItemId' to every element 
    in the XML structure recursively, and saves the result.
.PARAMETER Path
    The path to the XML file. Defaults to '1.xml' in the script's directory.
.PARAMETER AttributeName
    The name of the attribute to add. Defaults to 'ItemId'.
.PARAMETER Force
    If specified, overwrites existing ItemId attributes.
.PARAMETER OutputPath
    The path where the modified XML file will be saved. If not specified, the original file will be overwritten.
.PARAMETER ExcludeElements
    Array of element names to exclude from processing (e.g., comments, text nodes).
.EXAMPLE
    .\Add-ItemIdToXml.ps1
    Adds ItemId to all elements in 1.xml in the script's directory.
.EXAMPLE
    .\Add-ItemIdToXml.ps1 -Path "C:\data\myfile.xml" -OutputPath "C:\data\myfile_with_ids.xml"
    Adds ItemId to all elements in the specified file and saves to a new file.
.EXAMPLE
    .\Add-ItemIdToXml.ps1 -AttributeName "UniqueId" -Force
    Adds UniqueId attribute to all elements, overwriting existing values.
.EXAMPLE
    .\Add-ItemIdToXml.ps1 -Path "input.xml" -OutputPath "output.xml" -AttributeName "Id" -Force
    Reads from input.xml, adds Id attribute to all elements, and saves to output.xml.
.EXAMPLE
    .\Add-ItemIdToXml.ps1 -ExcludeElements @("comment", "metadata")
    Adds ItemId to all elements except 'comment' and 'metadata' elements.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path,
    
    [Parameter(Position = 1)]
    [string]$OutputPath,
    
    [Parameter()]
    [string]$AttributeName = "ItemId",
    
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [string[]]$ExcludeElements = @()
)

# If no path specified, use default
if ([string]::IsNullOrWhiteSpace($Path)) {
    $scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    $Path = Join-Path -Path $scriptDir -ChildPath "1.xml"
}

# Resolve full path
$xmlFilePath = Resolve-Path -Path $Path -ErrorAction SilentlyContinue

# Check if the file exists
if (-not $xmlFilePath) {
    throw "XML file not found: $Path"
}

# Function to add ItemId recursively to all elements
function Add-ItemIdRecursively {
    param (
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNode]$Node,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeName,
        
        [Parameter()]
        [bool]$Force = $false,
        
        [Parameter()]
        [string[]]$ExcludeElements = @()
    )

    # Process only element nodes
    if ($Node.NodeType -eq [System.Xml.XmlNodeType]::Element) {
        # Check if this element should be excluded
        if ($ExcludeElements -notcontains $Node.LocalName) {
            # Add attribute if it doesn't exist or if Force is specified
            $existingAttribute = $Node.GetAttribute($AttributeName)
            
            if ([string]::IsNullOrEmpty($existingAttribute) -or $Force) {
                $Node.SetAttribute($AttributeName, (New-Guid).ToString())
                Write-Verbose "Added $AttributeName to element: $($Node.LocalName)"
            }
            else {
                Write-Verbose "Skipped element (attribute exists): $($Node.LocalName)"
            }
        }
        else {
            Write-Verbose "Excluded element: $($Node.LocalName)"
        }
        
        # Process all child nodes recursively
        foreach ($childNode in $Node.ChildNodes) {
            Add-ItemIdRecursively -Node $childNode -AttributeName $AttributeName -Force $Force -ExcludeElements $ExcludeElements
        }
    }
}

# Main script execution
try {
    # Read the XML file
    Write-Verbose "Reading XML file: $xmlFilePath"
    $xmlDocument = New-Object System.Xml.XmlDocument
    
    # Preserve formatting
    $xmlDocument.PreserveWhitespace = $true
    
    try {
        $xmlDocument.Load($xmlFilePath)
    }
    catch {
        throw "Invalid XML format in file '$xmlFilePath': $_"
    }
    
    # Count elements before processing
    $elementCount = ($xmlDocument.SelectNodes("//*") | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element }).Count
    Write-Verbose "Found $elementCount elements in the XML document"
    
    # Add attribute to all elements recursively
    Write-Verbose "Adding '$AttributeName' to all elements..."
    Add-ItemIdRecursively -Node $xmlDocument.DocumentElement -AttributeName $AttributeName -Force $Force.IsPresent -ExcludeElements $ExcludeElements
    
    # Determine output path
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        # If no output path specified, overwrite the original file
        $outputFilePath = $xmlFilePath
        
        # Create backup of original file
        $backupPath = "$xmlFilePath.bak"
        Copy-Item -Path $xmlFilePath -Destination $backupPath -Force
        Write-Verbose "Created backup at: $backupPath"
        Write-Host "Backup saved: $backupPath" -ForegroundColor Yellow
    }
    else {
        # Use the specified output path
        $outputFilePath = $OutputPath
        
        # Create output directory if it doesn't exist
        $outputDir = Split-Path -Path $outputFilePath -Parent
        if ($outputDir -and -not (Test-Path -Path $outputDir)) {
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
            Write-Verbose "Created output directory: $outputDir"
        }
    }
    
    # Save the updated XML to the output file
    Write-Verbose "Saving updated XML to: $outputFilePath"
    
    # Create XmlWriterSettings for proper formatting
    $xmlSettings = New-Object System.Xml.XmlWriterSettings
    $xmlSettings.Indent = $true
    $xmlSettings.IndentChars = "  "
    $xmlSettings.NewLineChars = "`r`n"
    $xmlSettings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
    $xmlSettings.Encoding = [System.Text.Encoding]::UTF8
    
    # Save with formatting
    $xmlWriter = [System.Xml.XmlWriter]::Create($outputFilePath, $xmlSettings)
    try {
        $xmlDocument.Save($xmlWriter)
    }
    finally {
        $xmlWriter.Close()
    }
    
    Write-Host "Successfully added '$AttributeName' to all elements in the XML file!" -ForegroundColor Green
    Write-Host "Source file: $xmlFilePath" -ForegroundColor Cyan
    Write-Host "Output file: $outputFilePath" -ForegroundColor Green
    
    if ($xmlFilePath -eq $outputFilePath) {
        Write-Host "Original file was overwritten (backup available)" -ForegroundColor Yellow
    }
    else {
        Write-Host "Original file was preserved" -ForegroundColor Green
    }
    
    # Count elements with the new attribute
    $elementsWithAttribute = ($xmlDocument.SelectNodes("//*[@$AttributeName]")).Count
    Write-Host "Added '$AttributeName' to $elementsWithAttribute elements" -ForegroundColor Cyan
}
catch {
    # Throw the exception to allow proper error handling by the caller
    throw $_
}

<#
.SYNOPSIS
    Adds a GUID named ItemId to every item in the JSON file recursively.
.DESCRIPTION
    This script reads a JSON file, adds a unique GUID named 'ItemId' to every object 
    in the JSON structure recursively, and saves the result back to the same file.
.PARAMETER Path
    The path to the JSON file. Defaults to '1.json' in the script's directory.
.PARAMETER PropertyName
    The name of the property to add. Defaults to 'ItemId'.
.PARAMETER Force
    If specified, overwrites existing ItemId properties.
.PARAMETER OutputPath
    The path where the modified JSON file will be saved. If not specified, the original file will be overwritten.
.EXAMPLE
    .\Add-ItemIdToJson.ps1
    Adds ItemId to all objects in 1.json in the script's directory.
.EXAMPLE
    .\Add-ItemIdToJson.ps1 -Path "C:\data\myfile.json" -OutputPath "C:\data\myfile_with_ids.json"
    Adds ItemId to all objects in the specified file and saves to a new file.
.EXAMPLE
    .\Add-ItemIdToJson.ps1 -PropertyName "UniqueId" -Force
    Adds UniqueId to all objects, overwriting existing values.
.EXAMPLE
    .\Add-ItemIdToJson.ps1 -Path "input.json" -OutputPath "output.json" -PropertyName "Id" -Force
    Reads from input.json, adds Id property to all objects, and saves to output.json.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path,
    
    [Parameter(Position = 1)]
    [string]$OutputPath,
    
    [Parameter()]
    [string]$PropertyName = "ItemId",
    
    [Parameter()]
    [switch]$Force
)

# If no path specified, use default
if ([string]::IsNullOrWhiteSpace($Path)) {
    $scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    $Path = Join-Path -Path $scriptDir -ChildPath "1.json"
}

# Resolve full path
$jsonFilePath = Resolve-Path -Path $Path -ErrorAction SilentlyContinue

# Check if the file exists
if (-not $jsonFilePath) {
    throw "JSON file not found: $Path"
}

# Function to add ItemId recursively to all objects
function Add-ItemIdRecursively {
    param (
        [Parameter(Mandatory = $true)]
        $Object,
        
        [Parameter(Mandatory = $true)]
        [string]$PropertyName,
        
        [Parameter()]
        [bool]$Force = $false
    )

    if ($Object -is [System.Management.Automation.PSCustomObject] -or $Object -is [hashtable]) {
        # Add property if it doesn't exist or if Force is specified
        if (-not $Object.PSObject.Properties[$PropertyName] -or $Force) {
            if ($Object.PSObject.Properties[$PropertyName] -and $Force) {
                # Remove existing property before adding new one
                $Object.PSObject.Properties.Remove($PropertyName)
            }
            $Object | Add-Member -MemberType NoteProperty -Name $PropertyName -Value (New-Guid).ToString() -Force
        }

        # Process all properties recursively
        foreach ($property in $Object.PSObject.Properties) {
            if ($null -ne $property.Value -and $property.Name -ne $PropertyName) {
                Add-ItemIdRecursively -Object $property.Value -PropertyName $PropertyName -Force $Force
            }
        }
    }
    elseif ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string]) {
        # Process arrays/collections
        foreach ($item in $Object) {
            if ($null -ne $item) {
                Add-ItemIdRecursively -Object $item -PropertyName $PropertyName -Force $Force
            }
        }
    }
}

# Main script execution
try {
    # Read the JSON file
    Write-Verbose "Reading JSON file: $jsonFilePath"
    $jsonContent = Get-Content -Path $jsonFilePath -Raw -ErrorAction Stop
    
    if ([string]::IsNullOrWhiteSpace($jsonContent)) {
        throw "JSON file is empty: $jsonFilePath"
    }
    
    # Convert JSON to PowerShell object
    Write-Verbose "Parsing JSON content..."
    try {
        $jsonObject = $jsonContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Invalid JSON format in file '$jsonFilePath': $_"
    }
    
    # Add property to all objects recursively
    Write-Verbose "Adding '$PropertyName' to all objects..."
    Add-ItemIdRecursively -Object $jsonObject -PropertyName $PropertyName -Force $Force.IsPresent
    
    # Convert back to JSON with proper formatting
    Write-Verbose "Converting back to JSON..."
    $updatedJson = $jsonObject | ConvertTo-Json -Depth 100 -Compress:$false
    
    # Determine output path
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        # If no output path specified, overwrite the original file
        $outputFilePath = $jsonFilePath
        
        # Create backup of original file
        $backupPath = "$jsonFilePath.bak"
        Copy-Item -Path $jsonFilePath -Destination $backupPath -Force
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
    
    # Save the updated JSON to the output file
    Write-Verbose "Saving updated JSON to: $outputFilePath"
    Set-Content -Path $outputFilePath -Value $updatedJson -Encoding UTF8 -ErrorAction Stop
    
    Write-Host "Successfully added '$PropertyName' to all objects in the JSON file!" -ForegroundColor Green
    Write-Host "Source file: $jsonFilePath" -ForegroundColor Cyan
    Write-Host "Output file: $outputFilePath" -ForegroundColor Green
    
    if ($jsonFilePath -eq $outputFilePath) {
        Write-Host "Original file was overwritten (backup available)" -ForegroundColor Yellow
    }
    else {
        Write-Host "Original file was preserved" -ForegroundColor Green
    }
}
catch {
    # Throw the exception to allow proper error handling by the caller
    throw $_
}

# Group Policy Settings Search Script

## Overview

The `Search-GPOSettings.ps1` script allows you to search through Group Policy XML reports to find specific settings using wildcard patterns. It returns detailed context information including the GPO name, GUID, policy details, and setting information.

## Usage

### Basic Search
```powershell
.\Search-GPOSettings.ps1 -Path ".\content\2.xml" -SearchString "*Silently install*"
```

### Case-Sensitive Search
```powershell
.\Search-GPOSettings.ps1 -Path ".\content\2.xml" -SearchString "*Password*" -CaseSensitive
```

### Limit Results
```powershell
.\Search-GPOSettings.ps1 -Path ".\content\2.xml" -SearchString "*audit*" -MaxResults 10
```

### Include All Matches (including short/minimal content)
```powershell
.\Search-GPOSettings.ps1 -Path ".\content\2.xml" -SearchString "*log*" -IncludeAllMatches
```

## Parameters

- **Path** (Required): Path to the XML or JSON file to search
- **SearchString** (Required): Text to search for (supports wildcards * and ?)
- **CaseSensitive**: Perform case-sensitive search (default is case-insensitive)
- **IncludeAllMatches**: Include all text matches, even short ones
- **MaxResults**: Maximum number of results to return (0 = unlimited)

## Output Information

For each match found, the script displays:

- **Matched Text**: The actual text that matched your search pattern
- **GPO Details**: 
  - Display Name
  - Domain Name  
  - GUID
  - Type (Computer/User)
- **Setting Details**:
  - Policy Name
  - State (Enabled/Disabled/Not Configured)
  - Category
  - Value (if applicable)

## Examples

### Search for ActiveX settings
```powershell
.\Search-GPOSettings.ps1 -Path ".\content\2.xml" -SearchString "*ActiveX*"
```

### Search for wallpaper-related settings
```powershell
.\Search-GPOSettings.ps1 -Path ".\content\2.xml" -SearchString "*wallpaper*"
```

### Search for security policies (case-sensitive)
```powershell
.\Search-GPOSettings.ps1 -Path ".\content\2.xml" -SearchString "*Security*" -CaseSensitive
```

## File Support

The script supports both XML and JSON Group Policy report files. It automatically detects the file format based on the file extension.

## Notes

- The script returns both formatted console output and PowerShell objects for further processing
- Use wildcards (*) to broaden your search or search for partial matches
- The script filters out very short or meaningless text matches by default (use -IncludeAllMatches to override)
- Results are deduplicated based on matched text and policy information

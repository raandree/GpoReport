# Usage Guide

## Quick Start

### Basic Search Operations

#### Search a Single GPO File
```powershell
# Search for any setting containing "password"
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "*password*"

# Case-sensitive search
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "EnableGuestAccount" -CaseSensitive

# Search for exact text
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "SeTakeOwnershipPrivilege"
```

#### Search Multiple Files
```powershell
# Search all XML files in current directory
.\Search-GPMCReports.ps1 -Path "." -SearchString "*audit*"

# Recursive search through subdirectories
.\Search-GPMCReports.ps1 -Path "C:\GPO-Reports" -SearchString "*security*" -Recurse

# Search specific files
.\Search-GPMCReports.ps1 -Path @("GPO1.xml", "GPO2.xml") -SearchString "MaxTicketAge"
```

## Command-Line Parameters

### Search-GPMCReports.ps1 Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-Path` | String/Array | Yes | File path, directory, or array of paths to search |
| `-SearchString` | String | Yes | Search pattern (supports wildcards) |
| `-CaseSensitive` | Switch | No | Perform case-sensitive search (default: case-insensitive) |
| `-IncludeAllMatches` | Switch | No | Include all matches, not just meaningful content |
| `-MaxResults` | Int | No | Maximum number of results to return (0 = unlimited) |
| `-Recurse` | Switch | No | Search recursively through subdirectories |

### Search-GPOSettings.ps1 Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-XMLPath` | String | Yes | Path to PowerShell-exported GPO XML file |
| `-SearchTerm` | String | Yes | Search pattern (supports wildcards) |
| `-CaseSensitive` | Switch | No | Perform case-sensitive search |

## Search Pattern Examples

### Wildcard Patterns
```powershell
# Find all password-related settings
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*password*"

# Find settings starting with "Enable"
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "Enable*"

# Find audit settings
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*audit*"

# Find specific privilege assignments
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "Se*Privilege"
```

### Exact Text Searches
```powershell
# Find specific security option
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "EnableGuestAccount"

# Find specific user right
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "SeTakeOwnershipPrivilege"

# Find specific administrative template
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "Force a specific default lock screen"
```

### Member and Account Searches
```powershell
# Find specific user accounts
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "contoso\Chile"

# Find domain references
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*contoso*"

# Find group memberships
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "DnsAdmins"
```

## Understanding Output

### Output Structure
Each search result contains:

```powershell
MatchedText  : "EnableGuestAccount"           # The text that matched your search
MatchType    : "Text Content"                 # Where the match was found
GPO          : @{                             # GPO information
    DisplayName = "test1"
    DomainName = "contoso.com"  
    GUID = "4C969D54-F618-4C7B-B779-4D5CA078E206"
}
CategoryPath : "Security Settings > Local Policies > Security Options"  # Where the setting is located
Setting      : @{                             # Setting details
    Name = "EnableGuestAccount"
    State = "1"
    Value = "EnableGuestAccount"
    Context = "Security Options"
}
SourceFile   : "D:\GPO\test1.xml"            # Source file path
XPath        : "<q1:SystemAccessPolicyName>..." # XML location
```

### Category Path Interpretation

#### Security Settings Hierarchy
```
Security Settings
├── Account Policies
│   ├── Password Policy
│   ├── Account Lockout Policy
│   └── Kerberos Policy
├── Local Policies
│   ├── Audit Policy
│   ├── User Rights Assignment
│   └── Security Options
│       ├── Domain Controller
│       ├── Devices
│       ├── Network
│       └── Other
├── Advanced Audit Configuration
│   ├── Account Logon
│   ├── Account Management
│   └── DS Access
├── Event Log
├── Restricted Groups
├── System Services
├── Registry
└── File System
```

#### Administrative Templates Hierarchy
```
Administrative Templates
├── Control Panel
│   └── Personalization
├── Network
│   └── Lanman Server
├── System
│   ├── Display
│   └── Access-Denied Assistance
├── Windows Components
│   ├── Biometrics
│   ├── Camera
│   ├── ActiveX Installer Service
│   └── Security Center
└── Start Menu and Taskbar
    └── Notifications
```

#### Group Policy Preferences
```
Group Policy Preferences
├── Environment Variables
├── Local Users and Groups
├── Files
├── Folders  
├── Registry
├── Network Shares
├── Services
├── Devices
├── Data Sources
├── Ini Files
├── Scheduled Tasks
├── Shortcuts
└── Power Options
```

## Common Use Cases

### Security Auditing
```powershell
# Find all password policies
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*password*"

# Find all audit configurations  
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*audit*"

# Find security options
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*security*"

# Find user rights assignments
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "Se*Privilege"
```

### Compliance Checking
```powershell
# Check for guest account settings
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*guest*"

# Check for encryption settings
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*encrypt*"

# Check for remote access settings
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*remote*"
```

### Policy Troubleshooting
```powershell
# Find specific setting causing issues
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "EnableGuestAccount"

# Find all settings affecting a specific user
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "contoso\username"

# Find conflicting settings
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*disable*"
```

## Advanced Techniques

### Filtering Results with PowerShell
```powershell
# Get results and filter by category
$results = .\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*password*"
$results | Where-Object { $_.CategoryPath -like "*Security*" }

# Filter by GPO name
$results | Where-Object { $_.GPO.DisplayName -eq "Security Policy" }

# Filter by setting state
$results | Where-Object { $_.Setting.State -eq "Enabled" }
```

### Exporting Results
```powershell
# Export to CSV
$results = .\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*audit*"
$results | Select-Object MatchedText, CategoryPath, @{n='GPO';e={$_.GPO.DisplayName}} | Export-Csv -Path "audit-settings.csv"

# Export to JSON
$results | ConvertTo-Json -Depth 3 | Out-File "search-results.json"

# Create summary report
$results | Group-Object CategoryPath | Select-Object Name, Count | Sort-Object Count -Descending
```

### Batch Processing
```powershell
# Process multiple search patterns
$patterns = @("*password*", "*audit*", "*security*")
$allResults = @()

foreach ($pattern in $patterns) {
    $results = .\Search-GPMCReports.ps1 -Path "*.xml" -SearchString $pattern
    $allResults += $results
}

# Remove duplicates and export
$uniqueResults = $allResults | Sort-Object MatchedText -Unique
$uniqueResults | Export-Csv -Path "comprehensive-search.csv"
```

## Performance Tips

### Optimizing Search Performance
```powershell
# Use specific patterns instead of broad wildcards
# Good: "Se*Privilege" 
# Better than: "*e*"

# Process single files when possible
.\Search-GPMCReports.ps1 -Path "specific-gpo.xml" -SearchString "pattern"

# Use MaxResults for quick sampling
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*password*" -MaxResults 10
```

### Large File Handling
```powershell
# For very large GPO files, use verbose output to monitor progress
.\Search-GPMCReports.ps1 -Path "large-gpo.xml" -SearchString "pattern" -Verbose

# Process one file at a time for large batches
Get-ChildItem "*.xml" | ForEach-Object {
    Write-Host "Processing $($_.Name)..."
    .\Search-GPMCReports.ps1 -Path $_.FullName -SearchString "pattern"
}
```

## Integration Examples

### PowerShell Scripts
```powershell
# Function to search multiple patterns
function Search-GPOMultiPattern {
    param(
        [string[]]$Patterns,
        [string]$Path = "*.xml"
    )
    
    $allResults = @()
    foreach ($pattern in $Patterns) {
        $results = .\Search-GPMCReports.ps1 -Path $Path -SearchString $pattern
        $allResults += $results
    }
    
    return $allResults | Sort-Object CategoryPath, MatchedText
}

# Usage
$securityPatterns = @("*password*", "*audit*", "*security*", "*privilege*")
$securitySettings = Search-GPOMultiPattern -Patterns $securityPatterns
```

### Scheduled Tasks
```powershell
# Weekly GPO compliance scan
$results = .\Search-GPMCReports.ps1 -Path "\\server\gpo-reports\*.xml" -SearchString "*guest*"
if ($results) {
    $results | Export-Csv -Path "C:\Reports\Weekly-Compliance-$(Get-Date -Format 'yyyy-MM-dd').csv"
    # Send email alert if needed
}
```

### SIEM Integration
```powershell
# Export results in format suitable for SIEM ingestion
$results = .\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*security*"
$siemData = $results | Select-Object @{
    n='timestamp'; e={(Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')}
}, @{
    n='event_type'; e={'gpo_setting_found'}
}, @{
    n='gpo_name'; e={$_.GPO.DisplayName}
}, @{
    n='setting_category'; e={$_.CategoryPath}
}, @{
    n='setting_name'; e={$_.MatchedText}
}

$siemData | ConvertTo-Json | Out-File "siem-export.json"
```

## Troubleshooting Common Issues

### File Not Found Errors
```powershell
# Verify file exists
Test-Path "MyGPO.xml"

# Check current directory
Get-Location

# Use full paths
.\Search-GPMCReports.ps1 -Path "C:\Full\Path\To\MyGPO.xml" -SearchString "pattern"
```

### No Results Found
```powershell
# Try broader search pattern
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "*password*" -Verbose

# Check if file has content
Get-Content "MyGPO.xml" | Select-String "password" 

# Verify file is valid XML
[xml]$xml = Get-Content "MyGPO.xml"
```

### Encoding Issues
```powershell
# The script automatically handles encoding issues, but you can verify:
# Check file encoding
Get-Content "MyGPO.xml" -TotalCount 1

# For manual verification
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "pattern" -Verbose
# Look for "Direct load failed, trying with encoding fix" message
```

### Performance Issues
```powershell
# For large files, monitor memory usage
Get-Process powershell | Select-Object Name, WorkingSet

# Use specific patterns
# Instead of: "*a*"
# Use: "EnableGuestAccount" or "Se*Privilege"

# Process files individually for large batches
```

## Best Practices

### Search Pattern Design
1. **Be Specific**: Use exact text when you know it
2. **Use Targeted Wildcards**: "Se*Privilege" instead of "*e*"
3. **Case Sensitivity**: Usually unnecessary for setting names
4. **Test Incrementally**: Start with broad patterns, then narrow down

### File Organization
1. **Consistent Naming**: Use descriptive GPO report names
2. **Directory Structure**: Organize by domain, OU, or function
3. **Regular Updates**: Keep GPO exports current
4. **Backup Strategy**: Maintain historical snapshots for comparison

### Result Analysis
1. **Category Grouping**: Group results by CategoryPath for analysis
2. **Cross-Reference**: Compare results across multiple GPOs
3. **Documentation**: Record significant findings for future reference
4. **Validation**: Verify critical settings in actual GPO management tools

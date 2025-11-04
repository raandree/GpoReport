# Quick Reference Guide

## Search-GPMCReports.ps1 Command Reference

### Basic Syntax
```powershell
# File-based search
.\Search-GPMCReports.ps1 -Path <FilePath> -SearchString <Pattern> [Options]

# XML string array search (✨ NEW)
.\Search-GPMCReports.ps1 -XmlContent <String[]> -SearchString <Pattern> [Options]
```

### Common Usage Patterns

#### Single File Search
```powershell
# Basic search
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "password"

# Case-sensitive search
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "Password" -CaseSensitive

# Wildcard search
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "*audit*"

# Limit results
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "security" -MaxResults 5
```

#### XML String Array Search (✨ NEW)
```powershell
# Search XML content from memory
$xmlContent = Get-Content "MyGPO.xml" -Raw
.\Search-GPMCReports.ps1 -XmlContent @($xmlContent) -SearchString "password"

# Search multiple XML strings
$xml1 = Get-Content "GPO1.xml" -Raw
$xml2 = Get-Content "GPO2.xml" -Raw
.\Search-GPMCReports.ps1 -XmlContent @($xml1, $xml2) -SearchString "audit"

# Pipeline integration
Get-Content "*.xml" -Raw | ForEach-Object { 
    .\Search-GPMCReports.ps1 -XmlContent @($_) -SearchString "security" 
}
```

#### Multiple File Search
```powershell
# Search all XML files in directory
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "password"

# Search specific files
.\Search-GPMCReports.ps1 -Path @("GPO1.xml", "GPO2.xml") -SearchString "audit"

# Search with verbose output
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "security" -Verbose
```

## Enhanced Capabilities Quick Reference (✨ NEW)

### Professional Export
```powershell
# Export in all formats (JSON, CSV, HTML, XML)
$results | .\Export-SearchResults.ps1 -OutputPath "report" -Format All
```

### Compliance Analysis
```powershell
# CIS compliance check
.\Search-GPOCompliance.ps1 -Path "*.xml" -Framework CIS

# Custom security patterns
.\Search-GPOCompliance.ps1 -Path "*.xml" -CustomPatterns @("*password*", "*audit*")
```

### High-Performance Caching
```powershell
# Enable caching for large environments
.\Search-GPOCached.ps1 -Path "*.xml" -SearchString "*password*" -UseCache -ParallelProcessing
```

### AI-Powered Insights
```powershell
# Generate security insights
.\Get-GPOInsights.ps1 -Path "*.xml" -Focus Security -IncludeRecommendations
```

### Search Pattern Cheat Sheet

| Pattern Type | Example | Description |
|--------------|---------|-------------|
| Exact Match | `"PasswordHistorySize"` | Find exact text |
| Wildcard | `"*password*"` | Contains 'password' |
| Start With | `"Enable*"` | Starts with 'Enable' |
| End With | `"*Policy"` | Ends with 'Policy' |
| Case Sensitive | `"Password" -CaseSensitive` | Exact case match |
| Multiple Terms | `"audit\|password"` | Contains 'audit' OR 'password' |

### Parameter Quick Reference

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `-Path` | String/Array | File(s) to search | `"MyGPO.xml"` |
| `-XmlContent` | String[] | XML content as string array | `@($xmlContent)` |
| `-SearchString` | String | Pattern to find | `"*password*"` |
| `-CaseSensitive` | Switch | Case-sensitive search | `-CaseSensitive` |
| `-MaxResults` | Int | Limit result count | `-MaxResults 10` |
| `-Verbose` | Switch | Detailed output | `-Verbose` |

*Note: Either `-Path` or `-XmlContent` is required (parameter sets)*

### Output Object Properties (Enhanced ✨)

Each result object contains:
```powershell
MatchedText     # The text that matched your search
CategoryPath    # Where the setting was found
ElementType     # XML element type (Attribute/Text)
GPOName         # Name of the Group Policy Object
GPOGuid         # Unique identifier of the GPO
Section         # Computer or User section (✨ NEW)
Comment         # Policy comment if available (✨ NEW)
XPath           # XML path to the element
Context         # Surrounding text/attributes
SourceFile      # Original file path (if file-based search)
```

### Example Output Interpretation

```powershell
PS> .\Search-GPMCReports.ps1 -Path "AllSettings1.xml" -SearchString "PasswordHistorySize"

MatchedText      : PasswordHistorySize
CategoryPath     : Security Settings > Account Policies > Password Policy
ElementType      : Attribute
GPOName          : Test GPO
GPOGuid          : {12345678-1234-5678-9012-123456789012}
XPath            : /GPO/Computer/ExtensionData/Extension/PasswordPolicy
Context          : Display Name: Enforce password history
```

**Interpretation**:
- **MatchedText**: Found the exact text "PasswordHistorySize"
- **CategoryPath**: Located in Security Settings under Password Policy
- **ElementType**: Found as an XML attribute (not element text)
- **GPOName/GPOGuid**: Identifies which GPO contains this setting
- **XPath**: Technical XML location
- **Context**: Human-readable description

### Common Search Scenarios

#### Find All Password-Related Settings
```powershell
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*password*"
```

#### Search for Audit Policies
```powershell
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*audit*"
```

#### Find Security Options
```powershell
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*Account*"
```

#### Search for Registry Settings
```powershell
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*Registry*"
```

#### Find Administrative Templates
```powershell
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*Policy*"
```

### Category Path Examples

Common category paths you'll see in results:

```
Administrative Templates > [Category] > [Subcategory]
Security Settings > Account Policies > Password Policy
Security Settings > Local Policies > Security Options
Security Settings > Advanced Audit Policy Configuration > [Category]
Computer Configuration > Preferences > [Type]
User Configuration > Administrative Templates > [Category]
```

### Advanced Usage

#### Export Results to CSV
```powershell
$results = .\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*password*"
$results | Export-Csv -Path "password-settings.csv" -NoTypeInformation
```

#### Filter Results by Category
```powershell
$results = .\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*audit*"
$results | Where-Object {$_.CategoryPath -like "*Security Settings*"}
```

#### Group Results by GPO
```powershell
$results = .\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*security*"
$results | Group-Object GPOName | Format-Table Name, Count
```

#### Search Multiple Patterns
```powershell
@("*password*", "*audit*", "*account*") | ForEach-Object {
    Write-Host "=== Results for $_ ==="
    .\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString $_
}
```

### Testing and Validation

#### Verify Script Installation
```powershell
# Check script exists
Test-Path ".\Search-GPMCReports.ps1"

# Test basic functionality
.\Search-GPMCReports.ps1 -Path "AllSettings1.xml" -SearchString "PasswordHistorySize"
```

#### Run Test Suite
```powershell
# Install Pester if needed
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run validation tests
Invoke-Pester .\Test-GPMCSearch.Tests.ps1
```

### Performance Tips

#### For Large Files
```powershell
# Use MaxResults to limit output
.\Search-GPMCReports.ps1 -Path "large-file.xml" -SearchString "*pattern*" -MaxResults 20

# Be specific with patterns
# Good: "EnableGuestAccount"
# Avoid: "*e*"
```

#### For Multiple Files
```powershell
# Process files one at a time for better memory management
Get-ChildItem "*.xml" | ForEach-Object {
    Write-Host "Processing $($_.Name)..."
    .\Search-GPMCReports.ps1 -Path $_.FullName -SearchString "pattern"
}
```

### Troubleshooting Quick Fixes

#### No Results Found
```powershell
# Check if pattern exists in file
Get-Content "MyGPO.xml" | Select-String "your-pattern"

# Try broader pattern
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "*broader*"

# Enable verbose output
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "pattern" -Verbose
```

#### File Not Found
```powershell
# Check current directory
Get-Location
Get-ChildItem "*.xml"

# Use absolute path
.\Search-GPMCReports.ps1 -Path "C:\Full\Path\To\File.xml" -SearchString "pattern"
```

### Integration Examples

#### PowerShell Pipeline
```powershell
# Chain with other commands
.\Search-GPMCReports.ps1 -Path "*.xml" -SearchString "*audit*" |
    Where-Object {$_.GPOName -eq "Default Domain Policy"} |
    Select-Object MatchedText, CategoryPath |
    Format-Table -AutoSize
```

#### Scheduled Task
```powershell
# Create script for scheduled execution
$results = .\Search-GPMCReports.ps1 -Path "\\server\gpo\*.xml" -SearchString "*security*"
$results | Export-Csv -Path "C:\Reports\daily-security-audit.csv" -NoTypeInformation
Send-MailMessage -To "admin@company.com" -Subject "Daily GPO Audit" -Attachments "C:\Reports\daily-security-audit.csv"
```

### Version Compatibility

| PowerShell Version | Support Level |
|-------------------|---------------|
| 5.1 (Windows PS) | ✅ Full Support |
| 7.0+ (PS Core) | ✅ Full Support |
| Earlier versions | ❌ Not tested |

### File Type Support

| File Type | Description | Support |
|-----------|-------------|---------|
| GPMC XML | Group Policy Management Console exports | ✅ Primary target |
| PowerShell XML | Get-GPOReport PowerShell exports | ✅ Via Search-GPOSettings.ps1 |
| HTML Reports | GPMC HTML exports | ❌ Not supported |
| CSV Files | Exported GPO data | ❌ Not supported |

### Memory and Performance Guidelines

| File Size | Expected Performance | Recommendations |
|-----------|---------------------|-----------------|
| < 1 MB | Instant | No special handling |
| 1-10 MB | < 30 seconds | Monitor memory usage |
| 10-50 MB | 1-5 minutes | Use MaxResults |
| > 50 MB | 5+ minutes | Process in batches |

### Regular Expressions

The script converts wildcard patterns to regex automatically:

| Input Pattern | Converted Regex | Matches |
|---------------|-----------------|---------|
| `password` | `(?i)password` | "password", "Password", "PASSWORD" |
| `*password*` | `(?i).*password.*` | "MyPassword", "PasswordPolicy" |
| `Enable*` | `(?i)Enable.*` | "EnableAudit", "EnableGuest" |
| `*Policy` | `(?i).*Policy` | "PasswordPolicy", "AuditPolicy" |

**Note**: The `(?i)` prefix makes searches case-insensitive by default unless `-CaseSensitive` is used.

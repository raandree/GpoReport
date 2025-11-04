# GpoFilter Parameter - Active Directory GPO Search

## Overview

The `GpoFilter` parameter has been added to both `Search-GPMCReports` and `Show-GPOSearchReport` functions, enabling direct Active Directory GPO queries without requiring pre-exported XML files.

## Feature Description

### What It Does

When using the `GpoFilter` parameter, the functions will:

1. **Query Active Directory** for all GPOs matching the filter pattern (supports wildcards)
2. **Export GPOs to temporary directory** using `Get-GPOReport`
3. **Search the exported XML files** using the existing search functionality
4. **Return results** with full categorization and context
5. **Clean up temporary files** automatically

### Key Benefits

- **No pre-export required**: Search GPOs directly from Active Directory
- **Wildcard support**: Use patterns like `Default*`, `*Security*`, or `*` for all GPOs
- **Automatic cleanup**: Temporary files are removed after search completion
- **Cross-domain support**: Optional `Domain` parameter for multi-domain environments
- **Same rich results**: Full categorization, XML context, and parsed data structures

## Requirements

- **GroupPolicy Module**: Windows RSAT (Remote Server Administration Tools) must be installed
- **Active Directory Access**: Account must have read access to GPOs in the target domain
- **PowerShell 5.1+**: Or PowerShell Core 7+ on Windows

### Installing RSAT

**Windows 10/11:**
```powershell
# Using Windows Optional Features
Add-WindowsCapability -Online -Name Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0

# Or using Settings app
# Settings > Apps > Optional Features > Add a feature > RSAT: Group Policy Management Tools
```

**Windows Server:**
```powershell
Install-WindowsFeature -Name GPMC
```

## Usage

### Search-GPMCReports with GpoFilter

#### Basic Usage
```powershell
# Search all GPOs starting with "Default" for password-related settings
Search-GPMCReports -GpoFilter "Default*" -SearchString "*password*"

# Search all GPOs for audit settings
Search-GPMCReports -GpoFilter "*" -SearchString "*audit*"

# Search security-related GPOs
Search-GPMCReports -GpoFilter "*Security*" -SearchString "*firewall*"
```

#### With Domain Parameter
```powershell
# Search GPOs in a specific domain
Search-GPMCReports -GpoFilter "Corp*" -SearchString "*Remote*" -Domain "contoso.com"

# Cross-domain search
Search-GPMCReports -GpoFilter "*" -SearchString "*policy*" -Domain "subsidiary.contoso.com"
```

#### With Additional Parameters
```powershell
# Limit results and use verbose output
Search-GPMCReports -GpoFilter "Default*" -SearchString "*user*" -MaxResults 10 -Verbose

# Case-sensitive search
Search-GPMCReports -GpoFilter "*Security*" -SearchString "Audit*" -CaseSensitive

# Include child duplicates
Search-GPMCReports -GpoFilter "*" -SearchString "*registry*" -IncludeChildDuplicates
```

### Show-GPOSearchReport with GpoFilter

#### Generate HTML Reports from AD Queries
```powershell
# Generate HTML report from AD query
Show-GPOSearchReport -GpoFilter "Default*" -SearchString "password*"

# Save to specific location
Show-GPOSearchReport -GpoFilter "*Security*" -SearchString "audit*" -OutputPath "C:\Reports\SecurityAudit.html"

# Cross-domain report
Show-GPOSearchReport -GpoFilter "*" -SearchString "RemoteDesktop" -Domain "contoso.com" -OutputPath "C:\Reports\RDP.html"
```

## Parameter Reference

### GpoFilter
- **Type**: String
- **Mandatory**: Yes (when using GpoFilter parameter set)
- **Position**: Named
- **Supports Wildcards**: Yes
- **Description**: Active Directory GPO display name filter. Use `*` for all GPOs.

### Domain
- **Type**: String
- **Mandatory**: No
- **Position**: Named
- **Description**: Target domain name. If not specified, uses the current user's domain.

## Technical Details

### Process Flow

1. **Module Check**: Verifies GroupPolicy module availability
2. **Temporary Directory Creation**: Creates unique temp folder with timestamp
3. **GPO Query**: Uses `Get-GPO -All` and filters by DisplayName
4. **XML Export**: Exports each matching GPO using `Get-GPOReport -ReportType Xml`
5. **Search Execution**: Processes exported XML files with existing search logic
6. **Result Compilation**: Aggregates results with full categorization
7. **Cleanup**: Removes temporary directory and all exported files

### Temporary File Location

Temporary files are created in:
```
%TEMP%\GpoReport_YYYYMMDD_HHmmss\
```

Example: `C:\Users\YourName\AppData\Local\Temp\GpoReport_20251104_092315\`

### Error Handling

The implementation includes robust error handling:

- **Missing GroupPolicy Module**: Clear error message with installation instructions
- **AD Query Failures**: Warning message if no GPOs match the filter
- **Export Failures**: Individual GPO export failures don't stop the entire process
- **Cleanup Failures**: Warning if temp directory can't be removed (doesn't fail the search)

### Performance Considerations

- **Initial Query**: `Get-GPO -All` retrieves all GPOs in the domain (can take time in large environments)
- **Export Time**: Each GPO export takes ~1-2 seconds
- **Network Dependency**: Requires Active Directory connectivity
- **Large Environments**: Consider using specific filters rather than `*` to reduce processing time

**Example Timing:**
- 10 GPOs: ~15-20 seconds
- 50 GPOs: ~1-2 minutes
- 100+ GPOs: ~2-5 minutes

## Comparison: GpoFilter vs Path Parameter

### Use GpoFilter When:
- ✓ You want current GPO data from Active Directory
- ✓ You don't have pre-exported XML files
- ✓ You want to search across multiple GPOs dynamically
- ✓ You need up-to-date information
- ✓ You're doing ad-hoc queries

### Use Path Parameter When:
- ✓ You already have exported XML files
- ✓ You need faster repeated searches on the same data
- ✓ You're working offline or without AD access
- ✓ You're analyzing historical GPO exports
- ✓ You're processing large numbers of GPOs multiple times

## Examples by Scenario

### Security Audit
```powershell
# Find all password policies across all GPOs
Search-GPMCReports -GpoFilter "*" -SearchString "*password*" |
    Export-Csv "PasswordPolicies.csv" -NoTypeInformation

# Check for weak encryption settings
Search-GPMCReports -GpoFilter "*" -SearchString "*encryption*" |
    Where-Object { $_.CategoryPath -like "*Security*" }
```

### Compliance Check
```powershell
# Find all audit policy settings
$auditResults = Search-GPMCReports -GpoFilter "*" -SearchString "*audit*"
Show-GPOSearchReport -GpoFilter "*" -SearchString "*audit*" -OutputPath "AuditCompliance.html"

# Check for specific security settings
Search-GPMCReports -GpoFilter "*" -SearchString "Remote Desktop" |
    Select-Object GPOName, CategoryPath, SettingName
```

### Troubleshooting
```powershell
# Find which GPO sets a specific registry value
Search-GPMCReports -GpoFilter "*" -SearchString "HKEY_LOCAL_MACHINE\Software\YourApp" -Verbose

# Track down firewall rules
Search-GPMCReports -GpoFilter "*Firewall*" -SearchString "*port*" |
    Group-Object GPOName
```

### Documentation
```powershell
# Generate comprehensive report of all security-related GPOs
Show-GPOSearchReport -GpoFilter "*Security*" -SearchString "*" -OutputPath "SecurityGPOs.html"

# Export all GPO settings to JSON
Search-GPMCReports -GpoFilter "*" -SearchString "*" |
    ConvertTo-Json -Depth 10 |
    Out-File "AllGPOSettings.json"
```

## Troubleshooting

### "GroupPolicy module is not available"
**Solution**: Install RSAT Group Policy Management Tools
```powershell
Add-WindowsCapability -Online -Name Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0
```

### "No GPOs found matching filter"
**Causes**:
- Filter pattern doesn't match any GPO DisplayNames
- Insufficient permissions to read GPOs
- Not connected to domain

**Solutions**:
- Verify filter pattern: `Get-GPO -All | Select-Object DisplayName`
- Check permissions: Must have read access to GPOs
- Verify domain connectivity: `Test-Connection -ComputerName DomainController`

### Temporary files not cleaned up
**Causes**:
- Files locked by antivirus
- Permissions issue
- Process interrupted

**Solutions**:
- Manually remove: `Remove-Item "$env:TEMP\GpoReport_*" -Recurse -Force`
- Check antivirus exclusions
- Ensure process completes normally

### Slow performance with "*" filter
**Solutions**:
- Use more specific filters: `Default*`, `*Security*`, `Corp-*`
- Filter results after: `Search-GPMCReports -GpoFilter "*" -SearchString "audit" -MaxResults 50`
- Consider pre-exporting: Export GPOs once, then use Path parameter for repeated searches

## Migration Guide

### From Path-based to GpoFilter

**Before:**
```powershell
# Export GPOs manually
$gpos = Get-GPO -All
foreach ($gpo in $gpos) {
    Get-GPOReport -Guid $gpo.Id -ReportType Xml -Path "C:\GPOExports\$($gpo.DisplayName).xml"
}

# Search exported files
Search-GPMCReports -Path "C:\GPOExports" -SearchString "*password*"
```

**After:**
```powershell
# Query and search in one step
Search-GPMCReports -GpoFilter "*" -SearchString "*password*"
```

### Combining Both Approaches

```powershell
# Use GpoFilter for current data
$liveResults = Search-GPMCReports -GpoFilter "*" -SearchString "*audit*"

# Use Path for historical comparison
$historicalResults = Search-GPMCReports -Path "C:\GPOArchive\2024" -SearchString "*audit*"

# Compare
Compare-Object $liveResults $historicalResults -Property GPOName, SettingName
```

## See Also

- [Search-GPMCReports Documentation](../README.md#search-gpmcreports)
- [Show-GPOSearchReport Documentation](../README.md#show-gpomcreports)
- [Usage Guide](06-usage-guide.md)
- [Quick Reference](08-quick-reference.md)

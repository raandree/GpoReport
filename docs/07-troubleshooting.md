# Troubleshooting Guide

## Common Issues and Solutions

### 1. File Access and Loading Issues

#### Problem: "File not found" or "Path does not exist"
**Symptoms**:
```
Cannot find path 'MyGPO.xml' because it does not exist.
```

**Solutions**:
```powershell
# Verify file exists
Test-Path "MyGPO.xml"

# Check current directory
Get-Location
Get-ChildItem "*.xml"

# Use absolute paths
.\Search-GPMCReports.ps1 -Path "C:\Full\Path\To\MyGPO.xml" -SearchString "pattern"

# Check file permissions
Get-Acl "MyGPO.xml"
```

#### Problem: XML encoding errors
**Symptoms**:
```
Exception calling "Load" with "1" argument(s): "There is no Unicode byte order mark. Cannot switch to Unicode."
```

**Solutions**:
The script automatically handles this issue, but you can verify:
```powershell
# Check file encoding declaration
Get-Content "MyGPO.xml" -TotalCount 1

# Use verbose mode to see encoding fix in action
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "pattern" -Verbose
# Look for: "Direct load failed, trying with encoding fix"
```

#### Problem: Malformed XML files
**Symptoms**:
```
XML document is not well-formed
```

**Solutions**:
```powershell
# Test XML validity
try {
    [xml]$xml = Get-Content "MyGPO.xml"
    Write-Host "XML is valid"
} catch {
    Write-Host "XML is malformed: $($_.Exception.Message)"
}

# Check file completeness
$content = Get-Content "MyGPO.xml" -Raw
if ($content -notlike "*</GPO>") {
    Write-Host "XML file appears incomplete"
}
```

### 2. Search Results Issues

#### Problem: No search results found
**Symptoms**:
```
Search completed. Found 0 matches.
WARNING: No matches found for pattern: password
```

**Diagnostic Steps**:
```powershell
# 1. Verify search term exists in file
Get-Content "MyGPO.xml" | Select-String "password" -AllMatches

# 2. Try broader search pattern
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "*password*" -Verbose

# 3. Case sensitivity check
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "Password" -CaseSensitive

# 4. Check file content type
$firstLines = Get-Content "MyGPO.xml" -TotalCount 10
$firstLines | Out-String
```

**Common Causes**:
- Search pattern too specific
- Wrong file type (PowerShell XML vs GPMC XML)
- Case sensitivity mismatch
- Pattern syntax errors

#### Problem: Incorrect categorization
**Symptoms**:
- Settings appear in wrong category
- Category path shows "Unknown" or generic paths

**Debugging**:
```powershell
# Enable verbose output to see categorization logic
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "pattern" -Verbose

# Look for these verbose messages:
# "Starting category search for node: [NodeName]"
# "Found ExtensionData category: [CategoryName]"
# "Final category path: [Path]"
```

**Solutions**:
- Report specific categorization issues for future enhancement
- Use XPath information to understand XML structure
- Verify the setting is in expected XML location

### 3. Performance Issues

#### Problem: Slow processing of large files
**Symptoms**:
- Script takes several minutes to process single file
- High memory usage
- PowerShell becomes unresponsive

**Solutions**:
```powershell
# 1. Use MaxResults for testing
.\Search-GPMCReports.ps1 -Path "large-file.xml" -SearchString "pattern" -MaxResults 10

# 2. Monitor memory usage
Get-Process powershell | Select-Object Name, WorkingSet

# 3. Process files individually
Get-ChildItem "*.xml" | ForEach-Object {
    Write-Host "Processing $($_.Name)..."
    .\Search-GPMCReports.ps1 -Path $_.FullName -SearchString "pattern"
}

# 4. Use more specific search patterns
# Good: "EnableGuestAccount"
# Bad: "*e*"
```

#### Problem: Out of memory errors
**Symptoms**:
```
Out of memory exception
```

**Solutions**:
```powershell
# Increase PowerShell memory limit (if possible)
$env:PSModulePath = $env:PSModulePath

# Process smaller batches
$files = Get-ChildItem "*.xml"
$batchSize = 5
for ($i = 0; $i -lt $files.Count; $i += $batchSize) {
    $batch = $files[$i..($i + $batchSize - 1)]
    # Process batch
}

# Close and restart PowerShell session between large operations
```

### 4. Output and Formatting Issues

#### Problem: Output appears corrupted or truncated
**Symptoms**:
- Text appears cut off
- Special characters display incorrectly
- Tables don't align properly

**Solutions**:
```powershell
# 1. Adjust console width
$Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(150, 3000)

# 2. Export to file for better viewing
$results = .\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "pattern"
$results | Out-File -FilePath "results.txt" -Width 200

# 3. Use structured output
$results | Format-Table -Property MatchedText, CategoryPath -AutoSize
$results | Format-List
```

#### Problem: Cannot export results
**Symptoms**:
```
Cannot bind argument to parameter because it is null
```

**Solutions**:
```powershell
# Check if results exist
$results = .\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "pattern"
if ($results) {
    $results | Export-Csv -Path "output.csv"
} else {
    Write-Host "No results to export"
}

# Handle null values in export
$results | Select-Object @{
    n='MatchedText'; e={$_.MatchedText ?? 'N/A'}
}, @{
    n='CategoryPath'; e={$_.CategoryPath ?? 'Unknown'}
} | Export-Csv -Path "output.csv"
```

### 5. Script Execution Issues

#### Problem: Execution policy restrictions
**Symptoms**:
```
Execution of scripts is disabled on this system
```

**Solutions**:
```powershell
# Check current execution policy
Get-ExecutionPolicy

# Set execution policy for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run with bypass (temporary)
PowerShell -ExecutionPolicy Bypass -File ".\Search-GPMCReports.ps1" -Path "MyGPO.xml" -SearchString "pattern"
```

#### Problem: PowerShell version compatibility
**Symptoms**:
- Cmdlets not recognized
- Syntax errors on seemingly correct code

**Solutions**:
```powershell
# Check PowerShell version
$PSVersionTable

# Minimum requirements:
# PowerShell 5.1+ (Windows PowerShell)
# PowerShell 7+ (PowerShell Core)

# Update PowerShell if needed
# Windows PowerShell: Built into Windows
# PowerShell Core: Download from GitHub
```

### 6. Pester Testing Issues

#### Problem: Pester tests failing
**Symptoms**:
```
Test failed: Expected 'Expected Category' but got 'Actual Category'
```

**Diagnostic Steps**:
```powershell
# Run individual test pattern
.\Search-GPMCReports.ps1 -Path "AllSettings1.xml" -SearchString "FailingPattern" -Verbose

# Check test file exists
Test-Path "AllSettings1.xml"

# Run single test case
Invoke-Pester .\Test-GPMCSearch.Tests.ps1 -TestName "*FailingPattern*"
```

#### Problem: Test file not found
**Symptoms**:
```
Cannot find file: AllSettings1.xml
```

**Solutions**:
```powershell
# Update test file path in Test-GPMCSearch.Tests.ps1
# Look for: $testXmlFile = "path/to/AllSettings1.xml"

# Or copy test file to correct location
Copy-Item "old\reports\AllSettings1.xml" -Destination ".\AllSettings1.xml"
```

## Diagnostic Commands

### Quick Health Check
```powershell
# Test basic functionality
.\Search-GPMCReports.ps1 -Path "AllSettings1.xml" -SearchString "PasswordHistorySize"

# Should return one result with:
# CategoryPath: "Security Settings > Account Policies > Password Policy"
```

### Verbose Debugging
```powershell
# Enable verbose output for detailed troubleshooting
.\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "pattern" -Verbose

# Key verbose messages to look for:
# "Using regex pattern: (?i)pattern"
# "Processing file: [filename]"
# "Searching through [N] nodes..."
# "Found [N] potential matches"
# "Final category path: [path]"
```

### File Content Analysis
```powershell
# Check XML structure
[xml]$xml = Get-Content "MyGPO.xml"
$xml.GPO | Get-Member

# Look for namespaces
$xml.GPO.Computer.ExtensionData | ForEach-Object {
    Write-Host "Extension: $($_.Name)"
    Write-Host "Namespace: $($_.Extension.NamespaceURI)"
}

# Search for specific elements
$xml.SelectNodes("//*[local-name()='SecurityOptions']")
```

## Error Code Reference

### Common Error Patterns

| Error Message | Likely Cause | Solution |
|---------------|--------------|----------|
| "Cannot find path" | File path incorrect | Use absolute paths, verify file exists |
| "Cannot switch to Unicode" | Encoding mismatch | Script handles automatically |
| "XML document is not well-formed" | Malformed XML | Check file integrity |
| "No matches found" | Pattern too specific | Try broader wildcard patterns |
| "Out of memory" | File too large | Process in smaller batches |
| "Execution policy" | PowerShell security | Adjust execution policy |

### Exit Codes
- **0**: Success, matches found
- **1**: Success, no matches found  
- **2**: File not found or access error
- **3**: XML parsing error
- **4**: Invalid parameters

## Getting Help

### Built-in Help
```powershell
# Get parameter help
Get-Help .\Search-GPMCReports.ps1 -Parameter Path

# Get examples
Get-Help .\Search-GPMCReports.ps1 -Examples

# Get full help
Get-Help .\Search-GPMCReports.ps1 -Full
```

### Debug Information Collection
When reporting issues, collect this information:

```powershell
# System information
$PSVersionTable
Get-ExecutionPolicy

# File information
Get-Item "MyGPO.xml" | Select-Object Name, Length, LastWriteTime

# Error details
try {
    .\Search-GPMCReports.ps1 -Path "MyGPO.xml" -SearchString "pattern" -Verbose
} catch {
    $_ | Format-List * -Force
}

# XML structure sample
[xml]$xml = Get-Content "MyGPO.xml"
$xml.GPO.Computer.ExtensionData[0] | Format-List
```

## Best Practices for Troubleshooting

### Systematic Approach
1. **Start Simple**: Test with known working files and patterns
2. **Isolate Issues**: Test one variable at a time
3. **Use Verbose Output**: Enable verbose mode for diagnostics
4. **Check Prerequisites**: Verify PowerShell version and execution policy
5. **Document Steps**: Record what works and what doesn't

### Common Solutions
1. **Use Absolute Paths**: Avoid relative path issues
2. **Test File Integrity**: Verify XML files are complete and valid
3. **Start Broad**: Use wildcard patterns to confirm content exists
4. **Check Examples**: Compare with working examples in documentation
5. **Update Regularly**: Keep scripts updated with latest fixes

### Prevention Strategies
1. **Validate Files**: Check XML structure before processing
2. **Use Test Files**: Keep known working GPO files for testing
3. **Regular Testing**: Run test suite periodically
4. **Monitor Performance**: Watch for memory and performance issues
5. **Document Changes**: Track modifications to GPO structures

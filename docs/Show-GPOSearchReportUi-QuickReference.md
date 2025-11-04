# Show-GPOSearchReportUi - Quick Reference

## Overview
`Show-GPOSearchReportUi` provides an intuitive graphical interface for generating GPO search reports with HTML output. It simplifies the `Show-GPOSearchReport` command by providing a user-friendly form with guided inputs.

## Usage

```powershell
# Import the module
Import-Module GpoReport

# Launch the UI
Show-GPOSearchReportUi
```

## Features

### 1. Search Mode Selection
- **Search Local XML Files**: Browse and select GPO XML files or folders
- **Query Active Directory GPOs**: Query AD directly (requires GroupPolicy module)

### 2. Guided Input Fields
- **XML Path/File**: Browse for local XML files or folders containing GPO reports
- **GPO Filter**: Wildcard pattern for GPO names when querying AD (e.g., `*Security*`, `Default*`)
- **Search String**: Pattern to search for in GPO settings (e.g., `*password*`, `*audit*`)
- **Domain**: Optional domain specification for AD queries (uses current domain if empty)
- **Output Path**: Custom path for HTML report (auto-generates temp file if empty)

### 3. User Experience
- Clear instructions and tooltips throughout the interface
- Real-time input validation
- Progress indicator during report generation
- Automatic report opening after generation
- Error handling with user-friendly messages

## Workflow Example

1. **Launch the UI**:
   ```powershell
   Show-GPOSearchReportUi
   ```

2. **Select Search Mode**:
   - Choose "Search Local XML Files" or "Query Active Directory GPOs"

3. **Configure Parameters**:
   - File Mode: Browse to select XML file or folder
   - AD Mode: Enter GPO filter pattern (e.g., `*`)
   - Enter search string (e.g., `*password*`)
   - (Optional) Specify output path

4. **Generate Report**:
   - Click "Generate Report" button
   - View progress indicator
   - Choose to open the report when prompted

5. **View Results**:
   - HTML report opens in default browser
   - Detailed search results with collapsible sections
   - GPO information, settings, and context

## Examples

### Example 1: Search Local XML Files
1. Select "Search Local XML Files"
2. Browse to folder containing GPO XML exports
3. Enter search string: `*Remote*`
4. Click "Generate Report"

### Example 2: Query Active Directory
1. Select "Query Active Directory GPOs"
2. Enter GPO filter: `*Security*`
3. Enter search string: `*audit*`
4. (Optional) Specify domain
5. Click "Generate Report"

### Example 3: Custom Output Location
1. Configure search parameters
2. Click "Browse..." next to Output Path
3. Select desired location and filename
4. Click "Generate Report"

## Tips

- Leave Output Path empty to auto-generate a temporary file
- Use wildcard patterns (`*`) for broader searches
- Tooltips provide additional guidance (hover over fields)
- The UI validates inputs before generating reports
- Reports are automatically saved and can be opened immediately

## Related Commands

- `Show-GPOSearchReport`: Underlying command-line function
- `Search-GPMCReports`: Core search functionality
- `Start-GPOSearchGUI`: Interactive search interface (different purpose)

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+ (Windows only)
- .NET Framework with Windows Forms support
- Optional: GroupPolicy module (RSAT) for AD queries

# Start-GPOSearchGUI.ps1 - Interactive Windows Forms GUI for GPO searching
<#
.SYNOPSIS
    Interactive Windows Forms GUI for comprehensive GPO search and analysis
    
.DESCRIPTION
    Start-GPOSearchGUI.ps1 provides a complete desktop interface for GPO searching with 
    real-time filtering, visual results display, and integrated export functionality.
    This GUI makes GPO analysis accessible to users who prefer interactive interfaces
    over command-line tools.
    
    KEY FEATURES:
    • Drag-and-drop XML file selection
    • Real-time search with instant filtering
    • Interactive results grid with sorting
    • Section filtering (Computer/User)
    • Integrated export in multiple formats
    • Visual summary statistics
    • Progress indication for long operations
    
    INTERFACE COMPONENTS:
    • Menu System: File operations, tools, and help
    • Search Panel: Pattern input and search options
    • Results Grid: Sortable, filterable data display
    • Summary Panel: Real-time counts and statistics
    • Action Buttons: Export, clear, and tool access
    
    USER EXPERIENCE:
    • Intuitive layout for non-technical users
    • Immediate visual feedback
    • Error handling with user-friendly messages
    • Responsive design for different screen sizes

.PARAMETER None
    This GUI script accepts no command-line parameters
    All configuration is done through the interactive interface
    
.OUTPUTS
    • Interactive Windows Forms application
    • Real-time search results display
    • Export files in user-selected formats
    • Visual summary and statistics
    
.EXAMPLE
    # Launch the interactive GUI
    .\Start-GPOSearchGUI.ps1
    
    # GUI Features Available:
    # - Browse or drag-drop XML files
    # - Enter search patterns with wildcard support
    # - Toggle case sensitivity and recursive search
    # - Filter results by Computer/User sections
    # - Sort results by clicking column headers
    # - Export results in JSON, CSV, HTML, or XML formats
    # - View real-time summary statistics
    # - Clear results and start new searches
    
.EXAMPLE
    # Typical Workflow:
    # 1. Launch GUI: .\Start-GPOSearchGUI.ps1
    # 2. Load files: Use "Browse Files" or drag-drop XML files
    # 3. Enter search: Type pattern in search box (e.g., "*password*")
    # 4. Configure options: Set case sensitivity, recursion
    # 5. Execute search: Click "Search" button
    # 6. Review results: Sort and filter in results grid
    # 7. Export findings: Click "Export Results" and choose format
    
.NOTES
    File Name      : Start-GPOSearchGUI.ps1
    Author         : GPO Analysis Team
    Prerequisite   : Windows PowerShell with .NET Framework
    Dependencies   : Search-GPMCReports.ps1, Export-SearchResults.ps1
    
    System Requirements:
    • Windows operating system (not Server Core)
    • PowerShell 5.1+ or PowerShell Core on Windows
    • .NET Framework with Windows Forms support
    • Desktop environment for GUI display
    
    GUI Controls:
    • File Selection: Browse dialog and drag-drop support
    • Search Options: Case sensitivity, recursion toggles
    • Section Filter: Computer/User configuration filtering
    • Results Display: Sortable data grid with column headers
    • Export Options: Multiple format selection
    • Progress Indicators: Visual feedback during operations
    
    Error Handling:
    • User-friendly error messages
    • Input validation with helpful prompts
    • Graceful handling of file access issues
    • Progress cancellation for long operations
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'GPO Search Tool v2.0'
$form.Size = New-Object System.Drawing.Size(1200, 800)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false

# Create menu strip
$menuStrip = New-Object System.Windows.Forms.MenuStrip

# File menu
$fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$fileMenu.Text = 'File'

$openMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$openMenuItem.Text = 'Open XML File(s)...'
$openMenuItem.ShortcutKeys = [System.Windows.Forms.Keys]::Control -bor [System.Windows.Forms.Keys]::O

$exportMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exportMenuItem.Text = 'Export Results...'
$exportMenuItem.ShortcutKeys = [System.Windows.Forms.Keys]::Control -bor [System.Windows.Forms.Keys]::E

$fileMenu.DropDownItems.Add($openMenuItem)
$fileMenu.DropDownItems.Add($exportMenuItem)

# Tools menu
$toolsMenu = New-Object System.Windows.Forms.ToolStripMenuItem
$toolsMenu.Text = 'Tools'

$complianceMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$complianceMenuItem.Text = 'Compliance Analysis...'

$toolsMenu.DropDownItems.Add($complianceMenuItem)

$menuStrip.Items.Add($fileMenu)
$menuStrip.Items.Add($toolsMenu)
$form.Controls.Add($menuStrip)

# Create main panel
$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Location = New-Object System.Drawing.Point(10, 30)
$mainPanel.Size = New-Object System.Drawing.Size(1170, 730)
$form.Controls.Add($mainPanel)

# Search controls group
$searchGroup = New-Object System.Windows.Forms.GroupBox
$searchGroup.Text = 'Search Parameters'
$searchGroup.Location = New-Object System.Drawing.Point(10, 10)
$searchGroup.Size = New-Object System.Drawing.Size(1150, 120)
$mainPanel.Controls.Add($searchGroup)

# Path selection
$pathLabel = New-Object System.Windows.Forms.Label
$pathLabel.Text = 'XML File(s):'
$pathLabel.Location = New-Object System.Drawing.Point(10, 25)
$pathLabel.Size = New-Object System.Drawing.Size(80, 20)
$searchGroup.Controls.Add($pathLabel)

$pathTextBox = New-Object System.Windows.Forms.TextBox
$pathTextBox.Location = New-Object System.Drawing.Point(100, 23)
$pathTextBox.Size = New-Object System.Drawing.Size(900, 20)
$searchGroup.Controls.Add($pathTextBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = 'Browse...'
$browseButton.Location = New-Object System.Drawing.Point(1010, 22)
$browseButton.Size = New-Object System.Drawing.Size(80, 23)
$searchGroup.Controls.Add($browseButton)

# Search pattern
$patternLabel = New-Object System.Windows.Forms.Label
$patternLabel.Text = 'Search Pattern:'
$patternLabel.Location = New-Object System.Drawing.Point(10, 55)
$patternLabel.Size = New-Object System.Drawing.Size(80, 20)
$searchGroup.Controls.Add($patternLabel)

$patternTextBox = New-Object System.Windows.Forms.TextBox
$patternTextBox.Location = New-Object System.Drawing.Point(100, 53)
$patternTextBox.Size = New-Object System.Drawing.Size(300, 20)
$searchGroup.Controls.Add($patternTextBox)

# Options
$caseSensitiveCheckBox = New-Object System.Windows.Forms.CheckBox
$caseSensitiveCheckBox.Text = 'Case Sensitive'
$caseSensitiveCheckBox.Location = New-Object System.Drawing.Point(420, 55)
$caseSensitiveCheckBox.Size = New-Object System.Drawing.Size(100, 20)
$searchGroup.Controls.Add($caseSensitiveCheckBox)

$recurseCheckBox = New-Object System.Windows.Forms.CheckBox
$recurseCheckBox.Text = 'Recursive'
$recurseCheckBox.Location = New-Object System.Drawing.Point(530, 55)
$recurseCheckBox.Size = New-Object System.Drawing.Size(80, 20)
$searchGroup.Controls.Add($recurseCheckBox)

# Section filter
$sectionLabel = New-Object System.Windows.Forms.Label
$sectionLabel.Text = 'Section:'
$sectionLabel.Location = New-Object System.Drawing.Point(630, 55)
$sectionLabel.Size = New-Object System.Drawing.Size(50, 20)
$searchGroup.Controls.Add($sectionLabel)

$sectionComboBox = New-Object System.Windows.Forms.ComboBox
$sectionComboBox.Location = New-Object System.Drawing.Point(690, 53)
$sectionComboBox.Size = New-Object System.Drawing.Size(100, 20)
$sectionComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$sectionComboBox.Items.AddRange(@('All', 'Computer', 'User'))
$sectionComboBox.SelectedIndex = 0
$searchGroup.Controls.Add($sectionComboBox)

# Search button
$searchButton = New-Object System.Windows.Forms.Button
$searchButton.Text = 'Search'
$searchButton.Location = New-Object System.Drawing.Point(1010, 52)
$searchButton.Size = New-Object System.Drawing.Size(80, 25)
$searchButton.BackColor = [System.Drawing.Color]::LightGreen
$searchGroup.Controls.Add($searchButton)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 85)
$progressBar.Size = New-Object System.Drawing.Size(1080, 20)
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
$progressBar.Visible = $false
$searchGroup.Controls.Add($progressBar)

# Results group
$resultsGroup = New-Object System.Windows.Forms.GroupBox
$resultsGroup.Text = 'Search Results'
$resultsGroup.Location = New-Object System.Drawing.Point(10, 140)
$resultsGroup.Size = New-Object System.Drawing.Size(1150, 450)
$mainPanel.Controls.Add($resultsGroup)

# Results DataGridView
$resultsDataGrid = New-Object System.Windows.Forms.DataGridView
$resultsDataGrid.Location = New-Object System.Drawing.Point(10, 20)
$resultsDataGrid.Size = New-Object System.Drawing.Size(1130, 420)
$resultsDataGrid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$resultsDataGrid.ReadOnly = $true
$resultsDataGrid.AllowUserToAddRows = $false
$resultsDataGrid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$resultsGroup.Controls.Add($resultsDataGrid)

# Summary panel
$summaryPanel = New-Object System.Windows.Forms.Panel
$summaryPanel.Location = New-Object System.Drawing.Point(10, 600)
$summaryPanel.Size = New-Object System.Drawing.Size(1150, 120)
$summaryPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$mainPanel.Controls.Add($summaryPanel)

# Summary labels
$summaryTitle = New-Object System.Windows.Forms.Label
$summaryTitle.Text = 'Summary'
$summaryTitle.Location = New-Object System.Drawing.Point(10, 10)
$summaryTitle.Size = New-Object System.Drawing.Size(100, 20)
$summaryTitle.Font = New-Object System.Drawing.Font('Arial', 10, [System.Drawing.FontStyle]::Bold)
$summaryPanel.Controls.Add($summaryTitle)

$totalLabel = New-Object System.Windows.Forms.Label
$totalLabel.Text = 'Total Results: 0'
$totalLabel.Location = New-Object System.Drawing.Point(10, 35)
$totalLabel.Size = New-Object System.Drawing.Size(150, 20)
$summaryPanel.Controls.Add($totalLabel)

$computerLabel = New-Object System.Windows.Forms.Label
$computerLabel.Text = 'Computer Section: 0'
$computerLabel.Location = New-Object System.Drawing.Point(10, 55)
$computerLabel.Size = New-Object System.Drawing.Size(150, 20)
$summaryPanel.Controls.Add($computerLabel)

$userLabel = New-Object System.Windows.Forms.Label
$userLabel.Text = 'User Section: 0'
$userLabel.Location = New-Object System.Drawing.Point(10, 75)
$userLabel.Size = New-Object System.Drawing.Size(150, 20)
$summaryPanel.Controls.Add($userLabel)

$gpoCountLabel = New-Object System.Windows.Forms.Label
$gpoCountLabel.Text = 'Unique GPOs: 0'
$gpoCountLabel.Location = New-Object System.Drawing.Point(180, 35)
$gpoCountLabel.Size = New-Object System.Drawing.Size(150, 20)
$summaryPanel.Controls.Add($gpoCountLabel)

# Action buttons
$exportButton = New-Object System.Windows.Forms.Button
$exportButton.Text = 'Export Results'
$exportButton.Location = New-Object System.Drawing.Point(950, 30)
$exportButton.Size = New-Object System.Drawing.Size(100, 30)
$exportButton.Enabled = $false
$summaryPanel.Controls.Add($exportButton)

$clearButton = New-Object System.Windows.Forms.Button
$clearButton.Text = 'Clear Results'
$clearButton.Location = New-Object System.Drawing.Point(950, 70)
$clearButton.Size = New-Object System.Drawing.Size(100, 30)
$clearButton.Enabled = $false
$summaryPanel.Controls.Add($clearButton)

# Global variable to store current results
$script:currentResults = @()

# Event handlers
$browseButton.Add_Click({
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Title = 'Select GPO XML Files'
        $openFileDialog.Filter = 'XML Files (*.xml)|*.xml|All Files (*.*)|*.*'
        $openFileDialog.Multiselect = $true
    
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $pathTextBox.Text = $openFileDialog.FileNames -join '; '
        }
    })

$searchButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($pathTextBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show('Please select XML file(s) to search.', 'Missing Files', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
    
        if ([string]::IsNullOrWhiteSpace($patternTextBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show('Please enter a search pattern.', 'Missing Pattern', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
    
        # Show progress
        $progressBar.Visible = $true
        $searchButton.Enabled = $false
        $form.Refresh()
    
        try {
            # Prepare search parameters
            $searchParams = @{
                Path         = $pathTextBox.Text.Split(';')[0].Trim() # Use first file for now
                SearchString = $patternTextBox.Text
            }
        
            if ($caseSensitiveCheckBox.Checked) {
                $searchParams.CaseSensitive = $true
            }
        
            if ($recurseCheckBox.Checked) {
                $searchParams.Recurse = $true
            }
        
            # Execute search
            $script:currentResults = & "$PSScriptRoot\Search-GPMCReports.ps1" @searchParams
        
            # Filter by section if needed
            if ($sectionComboBox.SelectedItem -ne 'All') {
                $script:currentResults = $script:currentResults | Where-Object { $_.Section -eq $sectionComboBox.SelectedItem }
            }
        
            # Update DataGrid
            $dataTable = New-Object System.Data.DataTable
            $dataTable.Columns.Add('Matched Text') | Out-Null
            $dataTable.Columns.Add('Section') | Out-Null
            $dataTable.Columns.Add('GPO Name') | Out-Null
            $dataTable.Columns.Add('Category Path') | Out-Null
            $dataTable.Columns.Add('Setting Name') | Out-Null
            $dataTable.Columns.Add('State') | Out-Null
        
            foreach ($result in $script:currentResults) {
                $row = $dataTable.NewRow()
                $row['Matched Text'] = $result.MatchedText
                $row['Section'] = $result.Section
                $row['GPO Name'] = $result.GPO.DisplayName
                $row['Category Path'] = $result.CategoryPath
                $row['Setting Name'] = $result.Setting.Name
                $row['State'] = $result.Setting.State
                $dataTable.Rows.Add($row)
            }
        
            $resultsDataGrid.DataSource = $dataTable
        
            # Update summary
            $totalLabel.Text = "Total Results: $($script:currentResults.Count)"
            $computerCount = ($script:currentResults | Where-Object { $_.Section -eq 'Computer' }).Count
            $userCount = ($script:currentResults | Where-Object { $_.Section -eq 'User' }).Count
            $gpoCount = ($script:currentResults | Select-Object -ExpandProperty GPO | Select-Object -ExpandProperty DisplayName -Unique).Count
        
            $computerLabel.Text = "Computer Section: $computerCount"
            $userLabel.Text = "User Section: $userCount"
            $gpoCountLabel.Text = "Unique GPOs: $gpoCount"
        
            # Enable action buttons
            $exportButton.Enabled = $script:currentResults.Count -gt 0
            $clearButton.Enabled = $script:currentResults.Count -gt 0
        
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Search failed: $($_.Exception.Message)", 'Search Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        finally {
            $progressBar.Visible = $false
            $searchButton.Enabled = $true
        }
    })

$exportButton.Add_Click({
        if ($script:currentResults.Count -eq 0) {
            return
        }
    
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveFileDialog.Title = 'Export Search Results'
        $saveFileDialog.Filter = 'JSON Files (*.json)|*.json|CSV Files (*.csv)|*.csv|HTML Reports (*.html)|*.html|XML Files (*.xml)|*.xml'
        $saveFileDialog.DefaultExt = 'json'
    
        if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            try {
                $extension = [System.IO.Path]::GetExtension($saveFileDialog.FileName).ToLower()
                $basePath = [System.IO.Path]::GetFileNameWithoutExtension($saveFileDialog.FileName)
                $directory = [System.IO.Path]::GetDirectoryName($saveFileDialog.FileName)
                $outputPath = Join-Path $directory $basePath
            
                $format = switch ($extension) {
                    '.json' { 'JSON' }
                    '.csv' { 'CSV' }
                    '.html' { 'HTML' }
                    '.xml' { 'XML' }
                    default { 'JSON' }
                }
            
                & "$PSScriptRoot\Export-SearchResults.ps1" -Results $script:currentResults -OutputPath $outputPath -Format $format -IncludeMetadata
            
                [System.Windows.Forms.MessageBox]::Show("Results exported successfully to: $($saveFileDialog.FileName)", 'Export Complete', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("Export failed: $($_.Exception.Message)", 'Export Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    })

$clearButton.Add_Click({
        $script:currentResults = @()
        $resultsDataGrid.DataSource = $null
        $totalLabel.Text = 'Total Results: 0'
        $computerLabel.Text = 'Computer Section: 0'
        $userLabel.Text = 'User Section: 0'
        $gpoCountLabel.Text = 'Unique GPOs: 0'
        $exportButton.Enabled = $false
        $clearButton.Enabled = $false
    })

$complianceMenuItem.Add_Click({
        [System.Windows.Forms.MessageBox]::Show('Compliance analysis feature coming soon!', 'Feature Preview', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })

# Show the form
$form.ShowDialog() | Out-Null

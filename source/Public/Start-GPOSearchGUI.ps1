function Start-GPOSearchGUI {
    <#
    .SYNOPSIS
        Interactive Windows Forms GUI for comprehensive GPO search and analysis
        
    .DESCRIPTION
        Start-GPOSearchGUI provides a complete desktop interface for GPO searching with 
        real-time filtering, visual results display, and integrated export functionality.
        This GUI makes GPO analysis accessible to users who prefer interactive interfaces
        over command-line tools.
        
    .PARAMETER None
        This GUI function accepts no parameters
        All configuration is done through the interactive interface
        
    .EXAMPLE
        Start-GPOSearchGUI
        
        # GUI Features Available:
        # - Browse or drag-drop XML files
        # - Enter search patterns with wildcard support
        # - Real-time filtering and sorting
        # - Export results in multiple formats
    #>
    
    [CmdletBinding()]
    param()

    begin {
        Write-Verbose 'Starting GPO Search GUI'
        
        # Check for required assemblies
        try {
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
        }
        catch {
            Write-Error 'Failed to load Windows Forms assemblies. GUI requires Windows PowerShell or PowerShell with Windows compatibility.'
            return
        }
    }

    process {
        try {
            # Create main form
            $form = New-Object System.Windows.Forms.Form
            $form.Text = 'GPO Search Tool'
            $form.Size = New-Object System.Drawing.Size(1000, 700)
            $form.StartPosition = 'CenterScreen'
            $form.MinimumSize = New-Object System.Drawing.Size(800, 600)

            # Create menu strip
            $menuStrip = New-Object System.Windows.Forms.MenuStrip
            $fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem
            $fileMenu.Text = '&File'
            
            $openMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
            $openMenuItem.Text = '&Open XML Files'
            $openMenuItem.ShortcutKeys = 'Control+O'
            
            $exitMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
            $exitMenuItem.Text = 'E&xit'
            
            $separator = New-Object System.Windows.Forms.ToolStripSeparator
            
            $fileMenu.DropDownItems.AddRange(@($openMenuItem, $separator, $exitMenuItem))
            $menuStrip.Items.Add($fileMenu)
            
            $form.MainMenuStrip = $menuStrip
            $form.Controls.Add($menuStrip)

            # Create search panel
            $searchPanel = New-Object System.Windows.Forms.Panel
            $searchPanel.Dock = 'Top'
            $searchPanel.Height = 80
            $searchPanel.BackColor = [System.Drawing.Color]::LightGray
            
            # Search label and textbox
            $searchLabel = New-Object System.Windows.Forms.Label
            $searchLabel.Text = 'Search Pattern:'
            $searchLabel.Location = New-Object System.Drawing.Point(10, 15)
            $searchLabel.Size = New-Object System.Drawing.Size(100, 20)
            
            $searchTextBox = New-Object System.Windows.Forms.TextBox
            $searchTextBox.Location = New-Object System.Drawing.Point(120, 12)
            $searchTextBox.Size = New-Object System.Drawing.Size(300, 25)
            $searchTextBox.Text = '*'
            
            # Search button
            $searchButton = New-Object System.Windows.Forms.Button
            $searchButton.Text = 'Search'
            $searchButton.Location = New-Object System.Drawing.Point(430, 10)
            $searchButton.Size = New-Object System.Drawing.Size(80, 30)
            
            # Case sensitive checkbox
            $caseSensitiveCheckBox = New-Object System.Windows.Forms.CheckBox
            $caseSensitiveCheckBox.Text = 'Case Sensitive'
            $caseSensitiveCheckBox.Location = New-Object System.Drawing.Point(520, 15)
            $caseSensitiveCheckBox.Size = New-Object System.Drawing.Size(120, 20)
            
            # Export button
            $exportButton = New-Object System.Windows.Forms.Button
            $exportButton.Text = 'Export Results'
            $exportButton.Location = New-Object System.Drawing.Point(650, 10)
            $exportButton.Size = New-Object System.Drawing.Size(100, 30)
            $exportButton.Enabled = $false
            
            $searchPanel.Controls.AddRange(@($searchLabel, $searchTextBox, $searchButton, $caseSensitiveCheckBox, $exportButton))
            $form.Controls.Add($searchPanel)

            # Create file selection panel
            $filePanel = New-Object System.Windows.Forms.Panel
            $filePanel.Dock = 'Top'
            $filePanel.Height = 40
            $filePanel.BackColor = [System.Drawing.Color]::WhiteSmoke
            
            $fileLabel = New-Object System.Windows.Forms.Label
            $fileLabel.Text = 'XML Files: (Drop files here or use File > Open)'
            $fileLabel.Location = New-Object System.Drawing.Point(10, 10)
            $fileLabel.Size = New-Object System.Drawing.Size(400, 20)
            $fileLabel.ForeColor = [System.Drawing.Color]::DarkBlue
            
            $filePanel.Controls.Add($fileLabel)
            $form.Controls.Add($filePanel)

            # Create results DataGridView
            $resultsGrid = New-Object System.Windows.Forms.DataGridView
            $resultsGrid.Dock = 'Fill'
            $resultsGrid.AllowUserToAddRows = $false
            $resultsGrid.AllowUserToDeleteRows = $false
            $resultsGrid.ReadOnly = $true
            $resultsGrid.AutoSizeColumnsMode = 'AllCells'
            $resultsGrid.SelectionMode = 'FullRowSelect'
            $resultsGrid.MultiSelect = $true
            
            $form.Controls.Add($resultsGrid)

            # Create status strip
            $statusStrip = New-Object System.Windows.Forms.StatusStrip
            $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
            $statusLabel.Text = 'Ready'
            $statusStrip.Items.Add($statusLabel)
            $form.Controls.Add($statusStrip)

            # Variables to hold data
            $script:xmlFiles = @()
            $script:searchResults = @()

            # Event handlers
            $openMenuItem.Add_Click({
                    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
                    $openFileDialog.Filter = 'XML Files (*.xml)|*.xml|All Files (*.*)|*.*'
                    $openFileDialog.Multiselect = $true
                    $openFileDialog.Title = 'Select GPO XML Report Files'
                
                    if ($openFileDialog.ShowDialog() -eq 'OK') {
                        $script:xmlFiles = $openFileDialog.FileNames
                        $fileLabel.Text = "XML Files: $($script:xmlFiles.Count) files selected"
                        $statusLabel.Text = "Loaded $($script:xmlFiles.Count) XML files"
                    }
                })

            $exitMenuItem.Add_Click({
                    $form.Close()
                })

            $searchButton.Add_Click({
                    if ($script:xmlFiles.Count -eq 0) {
                        [System.Windows.Forms.MessageBox]::Show('Please select XML files first.', 'No Files Selected', 'OK', 'Warning')
                        return
                    }
                
                    if ([string]::IsNullOrWhiteSpace($searchTextBox.Text)) {
                        [System.Windows.Forms.MessageBox]::Show('Please enter a search pattern.', 'No Search Pattern', 'OK', 'Warning')
                        return
                    }
                
                    $statusLabel.Text = 'Searching...'
                    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
                
                    try {
                        $script:searchResults = @()
                    
                        foreach ($file in $script:xmlFiles) {
                            $results = Search-GPMCReports -Path $file -SearchString $searchTextBox.Text -CaseSensitive:$caseSensitiveCheckBox.Checked
                            $script:searchResults += $results
                        }
                    
                        # Update grid
                        if ($script:searchResults.Count -gt 0) {
                            $dataTable = New-Object System.Data.DataTable
                            $dataTable.Columns.Add('GPO Name', [string])
                            $dataTable.Columns.Add('Category Path', [string])
                            $dataTable.Columns.Add('Setting Name', [string])
                            $dataTable.Columns.Add('Setting Value', [string])
                            $dataTable.Columns.Add('Context', [string])
                            $dataTable.Columns.Add('Source File', [string])
                        
                            foreach ($result in $script:searchResults) {
                                $row = $dataTable.NewRow()
                                $row['GPO Name'] = $result.GPOName
                                $row['Category Path'] = $result.CategoryPath
                                $row['Setting Name'] = $result.SettingName
                                $row['Setting Value'] = $result.SettingValue
                                $row['Context'] = $result.Context
                                $row['Source File'] = (Split-Path $result.SourceFile -Leaf)
                                $dataTable.Rows.Add($row)
                            }
                        
                            $resultsGrid.DataSource = $dataTable
                            $exportButton.Enabled = $true
                            $statusLabel.Text = "Found $($script:searchResults.Count) matches"
                        }
                        else {
                            $resultsGrid.DataSource = $null
                            $exportButton.Enabled = $false
                            $statusLabel.Text = 'No matches found'
                        }
                    }
                    catch {
                        [System.Windows.Forms.MessageBox]::Show("Search failed: $($_.Exception.Message)", 'Search Error', 'OK', 'Error')
                        $statusLabel.Text = 'Search failed'
                    }
                    finally {
                        $form.Cursor = [System.Windows.Forms.Cursors]::Default
                    }
                })

            $exportButton.Add_Click({
                    if ($script:searchResults.Count -eq 0) {
                        return
                    }
                
                    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
                    $saveFileDialog.Filter = 'HTML Files (*.html)|*.html|CSV Files (*.csv)|*.csv|JSON Files (*.json)|*.json|XML Files (*.xml)|*.xml'
                    $saveFileDialog.Title = 'Export Search Results'
                    $saveFileDialog.FileName = 'GPO-Search-Results'
                
                    if ($saveFileDialog.ShowDialog() -eq 'OK') {
                        try {
                            $extension = [System.IO.Path]::GetExtension($saveFileDialog.FileName).ToLower()
                            $basePath = [System.IO.Path]::GetFileNameWithoutExtension($saveFileDialog.FileName)
                            $directory = [System.IO.Path]::GetDirectoryName($saveFileDialog.FileName)
                            $outputPath = Join-Path $directory $basePath
                        
                            switch ($extension) {
                                '.html' { $format = 'HTML' }
                                '.csv' { $format = 'CSV' }
                                '.json' { $format = 'JSON' }
                                '.xml' { $format = 'XML' }
                                default { $format = 'HTML' }
                            }
                        
                            Export-SearchResults -Results $script:searchResults -OutputPath $outputPath -Format $format -IncludeMetadata
                        
                            [System.Windows.Forms.MessageBox]::Show("Results exported successfully to:`n$($saveFileDialog.FileName)", 'Export Complete', 'OK', 'Information')
                            $statusLabel.Text = 'Results exported successfully'
                        }
                        catch {
                            [System.Windows.Forms.MessageBox]::Show("Export failed: $($_.Exception.Message)", 'Export Error', 'OK', 'Error')
                            $statusLabel.Text = 'Export failed'
                        }
                    }
                })

            # Enable drag-and-drop
            $form.AllowDrop = $true
            $form.Add_DragEnter({
                    if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
                        $_.Effect = [Windows.Forms.DragDropEffects]::Copy
                    }
                    else {
                        $_.Effect = [Windows.Forms.DragDropEffects]::None
                    }
                })
            
            $form.Add_DragDrop({
                    $files = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
                    $xmlFilesList = $files | Where-Object { $_ -match '\.xml$' }
                
                    if ($xmlFilesList) {
                        $script:xmlFiles = $xmlFilesList
                        $fileLabel.Text = "XML Files: $($script:xmlFiles.Count) files selected"
                        $statusLabel.Text = "Loaded $($script:xmlFiles.Count) XML files via drag-and-drop"
                    }
                })

            # Show the form
            $form.ShowDialog() | Out-Null
        }
        catch {
            Write-Error "GUI initialization failed: $($_.Exception.Message)"
            throw
        }
    }
}

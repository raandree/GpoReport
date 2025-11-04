function Show-GPOSearchReportUi {
    <#
    .SYNOPSIS
        Interactive GUI for generating GPO search reports with HTML output
        
    .DESCRIPTION
        Show-GPOSearchReportUi provides an intuitive graphical interface for the Show-GPOSearchReport
        command. Users can easily configure search parameters, select between file-based or Active Directory
        GPO searches, and generate comprehensive HTML reports with visual feedback.
        
        This GUI simplifies the report generation process by providing:
        - Clear selection between file-based and AD-based searches
        - Guided input fields with helpful tooltips
        - Instant validation and feedback
        - Direct HTML report generation and viewing
        
    .PARAMETER None
        This GUI function accepts no parameters
        All configuration is done through the interactive interface
        
    .EXAMPLE
        Show-GPOSearchReportUi
        
        Launches the interactive GUI for generating GPO search reports.
        
    .NOTES
        Author: GPO Analysis Team
        Requires: Show-GPOSearchReport function
        Optional: GroupPolicy module for Active Directory queries
    #>
    
    [CmdletBinding()]
    param()

    begin {
        Write-Verbose 'Starting GPO Search Report UI'
        
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
            $form.Text = 'GPO Search Report Generator'
            $form.Size = New-Object System.Drawing.Size(650, 550)
            $form.StartPosition = 'CenterScreen'
            $form.MinimumSize = New-Object System.Drawing.Size(650, 550)
            $form.MaximizeBox = $false
            $form.FormBorderStyle = 'FixedDialog'

            # Create header label with instructions
            $headerLabel = New-Object System.Windows.Forms.Label
            $headerLabel.Text = @"
Generate HTML Reports from GPO Search Results

This tool allows you to search Group Policy Objects and generate comprehensive 
HTML reports. Choose between searching local XML files or querying Active Directory.
"@
            $headerLabel.Location = New-Object System.Drawing.Point(20, 20)
            $headerLabel.Size = New-Object System.Drawing.Size(590, 60)
            $headerLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
            $form.Controls.Add($headerLabel)

            # Create separator line
            $separator1 = New-Object System.Windows.Forms.Label
            $separator1.BorderStyle = 'Fixed3D'
            $separator1.Location = New-Object System.Drawing.Point(20, 85)
            $separator1.Size = New-Object System.Drawing.Size(590, 2)
            $form.Controls.Add($separator1)

            # Create search mode group box
            $modeGroupBox = New-Object System.Windows.Forms.GroupBox
            $modeGroupBox.Text = 'Search Mode'
            $modeGroupBox.Location = New-Object System.Drawing.Point(20, 100)
            $modeGroupBox.Size = New-Object System.Drawing.Size(590, 70)
            $form.Controls.Add($modeGroupBox)

            # Radio button for file-based search
            $fileRadio = New-Object System.Windows.Forms.RadioButton
            $fileRadio.Text = 'Search Local XML Files'
            $fileRadio.Location = New-Object System.Drawing.Point(20, 25)
            $fileRadio.Size = New-Object System.Drawing.Size(250, 20)
            $fileRadio.Checked = $true
            $modeGroupBox.Controls.Add($fileRadio)

            # Radio button for AD-based search
            $adRadio = New-Object System.Windows.Forms.RadioButton
            $adRadio.Text = 'Query Active Directory GPOs'
            $adRadio.Location = New-Object System.Drawing.Point(20, 45)
            $adRadio.Size = New-Object System.Drawing.Size(250, 20)
            $modeGroupBox.Controls.Add($adRadio)

            # Tooltip for AD radio
            $tooltip = New-Object System.Windows.Forms.ToolTip
            $tooltip.SetToolTip($adRadio, 'Requires GroupPolicy module (RSAT)')

            # Create input fields group box
            $inputGroupBox = New-Object System.Windows.Forms.GroupBox
            $inputGroupBox.Text = 'Search Parameters'
            $inputGroupBox.Location = New-Object System.Drawing.Point(20, 180)
            $inputGroupBox.Size = New-Object System.Drawing.Size(590, 200)
            $form.Controls.Add($inputGroupBox)

            # File/Path input
            $pathLabel = New-Object System.Windows.Forms.Label
            $pathLabel.Text = 'XML Path/File:'
            $pathLabel.Location = New-Object System.Drawing.Point(20, 30)
            $pathLabel.Size = New-Object System.Drawing.Size(100, 20)
            $inputGroupBox.Controls.Add($pathLabel)

            $pathTextBox = New-Object System.Windows.Forms.TextBox
            $pathTextBox.Location = New-Object System.Drawing.Point(130, 28)
            $pathTextBox.Size = New-Object System.Drawing.Size(340, 25)
            $inputGroupBox.Controls.Add($pathTextBox)

            $browseButton = New-Object System.Windows.Forms.Button
            $browseButton.Text = 'Browse...'
            $browseButton.Location = New-Object System.Drawing.Point(480, 26)
            $browseButton.Size = New-Object System.Drawing.Size(85, 25)
            $inputGroupBox.Controls.Add($browseButton)

            # GPO Filter input
            $gpoFilterLabel = New-Object System.Windows.Forms.Label
            $gpoFilterLabel.Text = 'GPO Filter:'
            $gpoFilterLabel.Location = New-Object System.Drawing.Point(20, 65)
            $gpoFilterLabel.Size = New-Object System.Drawing.Size(100, 20)
            $gpoFilterLabel.Enabled = $false
            $inputGroupBox.Controls.Add($gpoFilterLabel)

            $gpoFilterTextBox = New-Object System.Windows.Forms.TextBox
            $gpoFilterTextBox.Location = New-Object System.Drawing.Point(130, 63)
            $gpoFilterTextBox.Size = New-Object System.Drawing.Size(340, 25)
            $gpoFilterTextBox.Text = '*'
            $gpoFilterTextBox.Enabled = $false
            $inputGroupBox.Controls.Add($gpoFilterTextBox)

            $tooltip.SetToolTip($gpoFilterTextBox, 'Wildcard pattern for GPO names (e.g., *Security*, Default*)')

            # Search String input
            $searchLabel = New-Object System.Windows.Forms.Label
            $searchLabel.Text = 'Search String:'
            $searchLabel.Location = New-Object System.Drawing.Point(20, 100)
            $searchLabel.Size = New-Object System.Drawing.Size(100, 20)
            $inputGroupBox.Controls.Add($searchLabel)

            $searchTextBox = New-Object System.Windows.Forms.TextBox
            $searchTextBox.Location = New-Object System.Drawing.Point(130, 98)
            $searchTextBox.Size = New-Object System.Drawing.Size(340, 25)
            $searchTextBox.Text = '*'
            $inputGroupBox.Controls.Add($searchTextBox)

            $tooltip.SetToolTip($searchTextBox, 'Pattern to search for in GPO settings (e.g., *password*, *audit*)')

            # Domain input
            $domainLabel = New-Object System.Windows.Forms.Label
            $domainLabel.Text = 'Domain:'
            $domainLabel.Location = New-Object System.Drawing.Point(20, 135)
            $domainLabel.Size = New-Object System.Drawing.Size(100, 20)
            $domainLabel.Enabled = $false
            $inputGroupBox.Controls.Add($domainLabel)

            $domainTextBox = New-Object System.Windows.Forms.TextBox
            $domainTextBox.Location = New-Object System.Drawing.Point(130, 133)
            $domainTextBox.Size = New-Object System.Drawing.Size(340, 25)
            $domainTextBox.Enabled = $false
            $inputGroupBox.Controls.Add($domainTextBox)

            $tooltip.SetToolTip($domainTextBox, 'Optional: Specify domain (leave empty for current domain)')

            # Output Path input
            $outputLabel = New-Object System.Windows.Forms.Label
            $outputLabel.Text = 'Output Path:'
            $outputLabel.Location = New-Object System.Drawing.Point(20, 170)
            $outputLabel.Size = New-Object System.Drawing.Size(100, 20)
            $inputGroupBox.Controls.Add($outputLabel)

            $outputTextBox = New-Object System.Windows.Forms.TextBox
            $outputTextBox.Location = New-Object System.Drawing.Point(130, 168)
            $outputTextBox.Size = New-Object System.Drawing.Size(340, 25)
            $inputGroupBox.Controls.Add($outputTextBox)

            $outputBrowseButton = New-Object System.Windows.Forms.Button
            $outputBrowseButton.Text = 'Browse...'
            $outputBrowseButton.Location = New-Object System.Drawing.Point(480, 166)
            $outputBrowseButton.Size = New-Object System.Drawing.Size(85, 25)
            $inputGroupBox.Controls.Add($outputBrowseButton)

            $tooltip.SetToolTip($outputTextBox, 'Optional: Custom path for HTML report (leave empty for auto-generated temp file)')
            $tooltip.SetToolTip($outputLabel, 'Leave empty for auto-generated temp file')

            # Create action buttons
            $generateButton = New-Object System.Windows.Forms.Button
            $generateButton.Text = 'Generate Report'
            $generateButton.Location = New-Object System.Drawing.Point(350, 400)
            $generateButton.Size = New-Object System.Drawing.Size(130, 35)
            $generateButton.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
            $generateButton.BackColor = [System.Drawing.Color]::LightGreen
            $form.Controls.Add($generateButton)

            $closeButton = New-Object System.Windows.Forms.Button
            $closeButton.Text = 'Close'
            $closeButton.Location = New-Object System.Drawing.Point(490, 400)
            $closeButton.Size = New-Object System.Drawing.Size(120, 35)
            $form.Controls.Add($closeButton)

            # Create status label
            $statusLabel = New-Object System.Windows.Forms.Label
            $statusLabel.Text = 'Ready to generate report'
            $statusLabel.Location = New-Object System.Drawing.Point(20, 410)
            $statusLabel.Size = New-Object System.Drawing.Size(320, 20)
            $statusLabel.ForeColor = [System.Drawing.Color]::DarkBlue
            $form.Controls.Add($statusLabel)

            # Create progress bar
            $progressBar = New-Object System.Windows.Forms.ProgressBar
            $progressBar.Location = New-Object System.Drawing.Point(20, 440)
            $progressBar.Size = New-Object System.Drawing.Size(590, 20)
            $progressBar.Style = 'Marquee'
            $progressBar.MarqueeAnimationSpeed = 0
            $progressBar.Visible = $false
            $form.Controls.Add($progressBar)

            # Event handlers
            $fileRadio.Add_CheckedChanged({
                if ($fileRadio.Checked) {
                    $pathLabel.Enabled = $true
                    $pathTextBox.Enabled = $true
                    $browseButton.Enabled = $true
                    $gpoFilterLabel.Enabled = $false
                    $gpoFilterTextBox.Enabled = $false
                    $domainLabel.Enabled = $false
                    $domainTextBox.Enabled = $false
                    $pathLabel.Text = 'XML Path/File:'
                    $statusLabel.Text = 'Ready to generate report from local XML files'
                }
            })

            $adRadio.Add_CheckedChanged({
                if ($adRadio.Checked) {
                    $pathLabel.Enabled = $false
                    $pathTextBox.Enabled = $false
                    $browseButton.Enabled = $false
                    $gpoFilterLabel.Enabled = $true
                    $gpoFilterTextBox.Enabled = $true
                    $domainLabel.Enabled = $true
                    $domainTextBox.Enabled = $true
                    $statusLabel.Text = 'Ready to generate report from Active Directory'
                }
            })

            $browseButton.Add_Click({
                $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
                $folderBrowser.Description = 'Select folder containing GPO XML files or select a specific XML file'
                $folderBrowser.ShowNewFolderButton = $false
                
                # Also allow file selection
                $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
                $openFileDialog.Filter = 'XML Files (*.xml)|*.xml|All Files (*.*)|*.*'
                $openFileDialog.Title = 'Select GPO XML File or Cancel to Select Folder'
                
                $result = [System.Windows.Forms.MessageBox]::Show(
                    'Do you want to select a specific XML file? Click No to select a folder.',
                    'File or Folder?',
                    'YesNoCancel',
                    'Question'
                )
                
                if ($result -eq 'Yes') {
                    if ($openFileDialog.ShowDialog() -eq 'OK') {
                        $pathTextBox.Text = $openFileDialog.FileName
                    }
                }
                elseif ($result -eq 'No') {
                    if ($folderBrowser.ShowDialog() -eq 'OK') {
                        $pathTextBox.Text = $folderBrowser.SelectedPath
                    }
                }
            })

            $outputBrowseButton.Add_Click({
                $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
                $saveFileDialog.Filter = 'HTML Files (*.html)|*.html'
                $saveFileDialog.Title = 'Save Report As'
                $saveFileDialog.FileName = "GPO-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
                
                if ($saveFileDialog.ShowDialog() -eq 'OK') {
                    $outputTextBox.Text = $saveFileDialog.FileName
                }
            })

            $generateButton.Add_Click({
                # Validate inputs
                if ($fileRadio.Checked) {
                    if ([string]::IsNullOrWhiteSpace($pathTextBox.Text)) {
                        [System.Windows.Forms.MessageBox]::Show(
                            'Please specify a path to XML files or folder.',
                            'Missing Path',
                            'OK',
                            'Warning'
                        )
                        return
                    }
                    if (-not (Test-Path $pathTextBox.Text)) {
                        [System.Windows.Forms.MessageBox]::Show(
                            'The specified path does not exist.',
                            'Invalid Path',
                            'OK',
                            'Error'
                        )
                        return
                    }
                }
                
                if ([string]::IsNullOrWhiteSpace($searchTextBox.Text)) {
                    [System.Windows.Forms.MessageBox]::Show(
                        'Please enter a search string.',
                        'Missing Search String',
                        'OK',
                        'Warning'
                    )
                    return
                }

                # Disable controls during generation
                $generateButton.Enabled = $false
                $progressBar.Visible = $true
                $progressBar.MarqueeAnimationSpeed = 30
                $statusLabel.Text = 'Generating report...'
                $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

                try {
                    # Build parameters
                    $params = @{
                        SearchString = $searchTextBox.Text
                    }

                    if ($fileRadio.Checked) {
                        $params['Path'] = $pathTextBox.Text
                    }
                    else {
                        $params['GpoFilter'] = $gpoFilterTextBox.Text
                        if (-not [string]::IsNullOrWhiteSpace($domainTextBox.Text)) {
                            $params['Domain'] = $domainTextBox.Text
                        }
                    }

                    if (-not [string]::IsNullOrWhiteSpace($outputTextBox.Text)) {
                        $params['OutputPath'] = $outputTextBox.Text
                    }

                    # Generate report
                    $outputFile = Show-GPOSearchReport @params

                    if ($outputFile -and (Test-Path $outputFile)) {
                        $statusLabel.Text = 'Report generated successfully!'
                        $statusLabel.ForeColor = [System.Drawing.Color]::Green
                        
                        $result = [System.Windows.Forms.MessageBox]::Show(
                            "Report generated successfully!`n`nPath: $outputFile`n`nWould you like to open it now?",
                            'Success',
                            'YesNo',
                            'Information'
                        )
                        
                        if ($result -eq 'Yes') {
                            Start-Process $outputFile
                        }
                    }
                    else {
                        throw 'Report generation failed - no output file created'
                    }
                }
                catch {
                    $statusLabel.Text = 'Report generation failed'
                    $statusLabel.ForeColor = [System.Drawing.Color]::Red
                    [System.Windows.Forms.MessageBox]::Show(
                        "Failed to generate report:`n`n$($_.Exception.Message)",
                        'Error',
                        'OK',
                        'Error'
                    )
                }
                finally {
                    $generateButton.Enabled = $true
                    $progressBar.Visible = $false
                    $progressBar.MarqueeAnimationSpeed = 0
                    $form.Cursor = [System.Windows.Forms.Cursors]::Default
                }
            })

            $closeButton.Add_Click({
                $form.Close()
            })

            # Show the form
            [void]$form.ShowDialog()
        }
        catch {
            Write-Error "Failed to create GUI: $($_.Exception.Message)"
        }
    }
}

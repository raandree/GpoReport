<#
.SYNOPSIS
    GPO Search Results HTML Report Generator

.DESCRIPTION
    Searches GPO XML reports using the GpoReport module and generates an HTML report with detailed results.
    Optionally retrieves additional GPO information from Active Directory if the GroupPolicy module is available.

.PARAMETER SearchString
    The search string to look for in GPO settings. Supports wildcards (*).

.PARAMETER OutputPath
    Path where the HTML report will be saved. Defaults to C:\Temp\GPOSearchReport.html

.EXAMPLE
    .\Go.ps1 -SearchString "Remote *"
    Searches for settings containing "Remote" and generates an HTML report.

.EXAMPLE
    .\Go.ps1 -SearchString "password*" -OutputPath "C:\Reports\PasswordPolicies.html"
    Searches for password-related settings and saves the report to a custom location.

.NOTES
    Author: Generated from GpoReport testing
    Date: November 3, 2025
    
    Dependencies:
    - Required: GpoReport module (Search-GPMCReports function)
    - Optional: GroupPolicy module (for enhanced GPO description lookup)
#>

#Requires -Modules GpoReport

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$SearchString,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = 'C:\Temp\GPOSearchReport.html'
)

# Script configuration
$here = $PSScriptRoot

# Search GPO XML files
Write-Host "Searching for '$SearchString' in XML files..." -ForegroundColor Cyan
$allResults = Get-ChildItem -Path "$here\..\Test Reports\*.xml" | ForEach-Object {
    Write-Verbose "Processing file: $($_.Name)"
    Search-GPMCReports -Path $_.FullName -SearchString $SearchString
}

Write-Host "Found $($allResults.Count) results" -ForegroundColor Green

#region Helper Functions

<#
.SYNOPSIS
    Generates an HTML report from GPO search results

.PARAMETER PageTitle
    The title of the HTML report page

.PARAMETER SearchString
    The search string used to find results

.PARAMETER TableOfResults
    HTML table content with search results

.PARAMETER ResultCount
    Total number of results found

.PARAMETER OutputPath
    Path where the HTML file will be saved
#>
function New-Report {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PageTitle,

        [Parameter(Mandatory)]
        [string]$SearchString,

        [Parameter(Mandatory)]
        [string[]]$TableOfResults,

        [Parameter(Mandatory)]
        [int]$ResultCount,

        [Parameter()]
        [string]$OutputPath = 'C:\Temp\test.html'
    )

    $dateCreate = (Get-Date).ToString('dd.MM.yyyy HH:mm:ss')

    $htmlDocument = @"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <title>$PageTitle</title>
        <style type="text/css">
            /* default body configuration */
            body {
                background: white; /* #ffffff */
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
                text-align: left; 
                font-family: "Segoe UI", Verdana, sans-serif; 
                font-style: normal; 
            }
            
            /* Table in the head section if the web page  */
            table.HeadLine {
                background: #ffffff;
                width: 100%; 
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
                border-collapse: collapse; /* no cell spacing */
                /*border: 0px solid black;*/
                text-align: left; 
                font-family: "Segoe UI", Verdana, sans-serif; 
            }
            tr.HeadLine {
                height: 38px;
                border-collapse: collapse; /* no cell spacing */
            }
            th.HeadLine {
                color: #ffffff; 
                background: #0078d4;
                border-collapse: collapse; /* no cell spacing */
                line-height: 30px; 
                /* vertical-align: bottom; */
                /* padding: 6px 5px; */
                /* text-align: left; */
                /* font-size: 18px; */
            }
            td.HeadLine { 
                color: #ffffff; 
                background: #004b76;
                border-collapse: collapse; /* no cell spacing */
                /* padding: 6px 5px; */
                line-height: 30px;
                /* text-align: left; */
                /* font-size: 12px; */
                vertical-align: bottom;
            }
            h1.HeadLine {
                margin-left: 5px;
                color: #ffffff;
                font-size: 16px;
                font-weight: lighter;
            }
            h2.HeadLine {
                margin-left: 5px;
                color: #ffffff;
                font-size: 14px;
                font-weight: lighter;
            }

            h1 { 
                text-align: left; 
                font-family: Segoe UI, Verdana, sans-serif;
                font-size: 20px;
                color: #ffffff;
                background: #0078d4;
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
            }
            h2 {
                text-align: left; 
                font-family: Segoe UI, Verdana, sans-serif; 
                font-style: normal; 
                font-size: 14px;
                color: #ffffff;
                /* background: #004b76;*/
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
            }

            table { 
                background: #ffffff;
                border-collapse: collapse;
                align: left; 
                width: 100%; 
                font-family: Segoe UI, Verdana, sans-serif; 
                font-style: normal; 
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
            }
            tr {
            }
            th { 
                /* background: #0078d4; */
                background: #004b76;
                color: #ffffff; 
                width: 50%; 
                text-align: left;
                padding: 5px 10px; 
                font-size: 14px;
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
            }
            td { 
                color: #000000; 
                width: 50%; 
                vertical-align: top; 
                padding: 5px 20px;  
                text-align: left;
                font-size: 12px; 
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
            }
            tr { background: #ffffff; }
            tr:nth-child(even) { background: #bec5C933; }
            tr:nth-child(odd) { background: #b8d1f3; }

            p { font-family: Segoe UI, Verdana, sans-serif; }

        </style>
    </head>
    <body>
        <table Class="HeadLine">
            <tr>
                <th Class="HeadLine"><h1 Class="HeadLine">$PageTitle</h1></th>
                <th Class="HeadLine"><h2 Class="HeadLine">$SearchString</h2></th>
            </tr>
            <tr>
                <td Class="HeadLine"><h2 Class="HeadLine">Found entries:</h2></td>
                <td class="HeadLine"><h2 Class="HeadLine">$ResultCount</h2></td>
            </tr>
        </table>
        <br>
        $($TableOfResults -join "`n")
        <table Class="HeadLine">
            <tr Class="HeadLine">
                <td Class="HeadLine"></td>
                <td class="HeadLine"></td>
            </tr>
            <tr>
                <th Class="HeadLine"><h1 Class="HeadLine">Automatically generated on: $($env:COMPUTERNAME)</h1></th>
                <th Class="HeadLine"><h2 Class="HeadLine">at: $dateCreate</h2></th>
            </tr>
        </table>
    </body>
</html>
"@

    # Save HTML report
    Write-Verbose "Saving report to $OutputPath"
    $htmlDocument | Out-File -FilePath $OutputPath -Force -Encoding utf8

    # Open report in browser
    Write-Verbose "Opening report in browser"
    Start-Process 'msedge.exe' -ArgumentList $OutputPath
}

#endregion Helper Functions

#region Generate HTML Report

$tableOfResults = @()

foreach ($result in $allResults) {
    # Initialize table for this result
    $tableOfResults += '<table>'

    # Get GPO information from Active Directory if available
    $gpo = $null
    if (Get-Command -Name Get-GPO -ErrorAction SilentlyContinue) {
        try {
            $gpo = Get-GPO -Name $result.GPOName -ErrorAction Stop
        }
        catch {
            Write-Verbose "Could not retrieve GPO '$($result.GPOName)' from Active Directory"
        }
    }

    # Extract timestamps
    $creationTime = $result.CreatedTime
    $modificationTime = $result.ModifiedTime

    # GPO Header Information
    $tableOfResults += "<tr><th>GPO name:</th><th>$($result.GPOName)</th></tr>"

    $gpoDescription = if ($gpo) {
        $gpo.Description -replace ';', '<br>'
    }
    else {
        'Description not available'
    }

    $tableOfResults += "<tr><td><b>GPO description:</b></td><td>$gpoDescription</td></tr>"
    $tableOfResults += "<tr><td><b>GPO created:</b></td><td>$creationTime</td></tr>"
    $tableOfResults += "<tr><td><b>GPO modified:</b></td><td>$modificationTime</td></tr>"

    # Setting Details Section
    $tableOfResults += '<tr><td><u>Setting Details:</u></td><td></td></tr>'
    $tableOfResults += "<tr><td><b>Setting Path:</b></td><td>$($result.Section) > $($result.CategoryPath)</td></tr>"

    if ($result.XmlNode.ParsedXml.Name) {
        $tableOfResults += "<tr><td><b>Policy Name:</b></td><td>$($result.XmlNode.ParsedXml.Name)</td></tr>"
    }

    # Local Security Settings - Members
    if ($result.XmlNode.parsedXml.Member) {
        $member = ($result.XmlNode.parsedXml.Member.Name.Text) -join '<br>'
        $tableOfResults += "<tr><td><b>Policy Member:</b></td><td>$member</td></tr>"
    }

    # Certificate Settings
    if ($result.XmlNode.ElementName -eq 'IssuedTo') {
        $tableOfResults += "<tr><td><b>Certificate Name:</b></td><td>$($result.XmlNode.ParsedXml.Text)</td></tr>"
        $certificationType = ($result.XmlNode.ParentHierarchy)[($result.XmlNode.ParentHierarchy.Count - 1)]
        $tableOfResults += "<tr><td><b>Certification Type:</b></td><td>$certificationType</td></tr>"
    }

    # Policy Settings
    if ($result.XmlNode.ElementName -eq 'Policy') {
        if ($result.XmlNode.ParsedXml.State) {
            $tableOfResults += "<tr><td><b>State:</b></td><td>$($result.XmlNode.ParsedXml.State)</td></tr>"
        }

        # Policy with ListBox
        if ($result.XmlNode.ParsedXml.ListBox) {
            $listBoxString = ($result.XmlNode.ParsedXml.ListBox.Value.Element.Data) -join '<br>'
            $tableOfResults += "<tr><td><b>ListBox:</b></td><td>$listBoxString</td></tr>"
        }
    }

    # Group Policy Preferences - General Name
    if ($result.xmlnode.ParsedXml._name) {
        $tableOfResults += "<tr><td><b>Name:</b></td><td>$($result.xmlnode.ParsedXml._name)</td></tr>"
    }

    # File Settings
    if ($result.XmlNode.ParentHierarchy -contains 'FilesSettings') {
        $tableOfResults += '<tr><td><b>Source file:</b></td><td>Not yet implemented</td></tr>'
        if ($result.xmlnode.ParsedXml.Properties._targetPath) {
            $tableOfResults += "<tr><td><b>Target File:</b></td><td>$($result.xmlnode.ParsedXml.Properties._targetPath)</td></tr>"
        }
    }

    # Folder Settings
    if ($result.XmlNode.ParentHierarchy -contains 'Folder') {
        $tableOfResults += "<tr><td><b>Setting Name:</b></td><td>$($result.SettingName)</td></tr>"
        if ($result.xmlnode.ParsedXml._Path) {
            $tableOfResults += "<tr><td><b>Folder Path:</b></td><td>$($result.xmlnode.ParsedXml._Path)</td></tr>"
        }
    }

    # Registry Settings
    if ($result.XmlNode.ParentHierarchy -contains 'Registry') {
        if ($result.xmlnode.ParsedXml.Properties._hive) {
            $tableOfResults += "<tr><td><b>Hive:</b></td><td>$($result.xmlnode.ParsedXml.Properties._hive)</td></tr>"
        }
        if ($result.xmlnode.ParsedXml.Properties._key) {
            $tableOfResults += "<tr><td><b>Key:</b></td><td>$($result.xmlnode.ParsedXml.Properties._key)</td></tr>"
        }
        if ($result.xmlnode.ParsedXml.Properties._type) {
            $tableOfResults += "<tr><td><b>Type:</b></td><td>$($result.xmlnode.ParsedXml.Properties._type)</td></tr>"
        }
        if ($result.xmlnode.ParsedXml.Properties._value) {
            $tableOfResults += "<tr><td><b>Value:</b></td><td>$($result.xmlnode.ParsedXml.Properties._value)</td></tr>"
        }
    }

    # Shortcut Settings
    if ($result.XmlNode.ParentHierarchy -contains 'Shortcut') {
        $tableOfResults += "<tr><td><b>Element Type:</b></td><td>$($result.XmlNode.ElementName)</td></tr>"
        if ($result.xmlnode.ParsedXml.Properties._shortcutPath) {
            $tableOfResults += "<tr><td><b>Shortcut Path:</b></td><td>$($result.xmlnode.ParsedXml.Properties._shortcutPath)</td></tr>"
        }
        if ($result.xmlnode.ParsedXml.Properties._targetPath) {
            $tableOfResults += "<tr><td><b>Target Path:</b></td><td>$($result.xmlnode.ParsedXml.Properties._targetPath)</td></tr>"
        }
        if ($result.xmlnode.ParsedXml.Properties._arguments) {
            $tableOfResults += "<tr><td><b>Arguments:</b></td><td>$($result.xmlnode.ParsedXml.Properties._arguments)</td></tr>"
        }
    }

    # Scheduled Tasks
    if ($result.XmlNode.ParentHierarchy -contains 'ScheduledTasks') {
        if ($result.XmlNode.parsedXml.task.triggers.LogonTrigger) {
            $tableOfResults += '<tr><td><b>Trigger:</b></td><td>Logon</td></tr>'
        }
        if ($result.XmlNode.parsedXml.task.triggers.EventTrigger) {
            $tableOfResults += "<tr><td><b>Trigger:</b></td><td>Event: $($result.XmlNode.parsedXml.task.Triggers.EventTrigger.Subscription)</td></tr>"
        }
        if ($result.XmlNode.parsedXml.task.triggers.CalendarTrigger) {
            $tableOfResults += "<tr><td><b>Trigger:</b></td><td>Calendar: $($result.XmlNode.parsedXml.task.Triggers.CalendarTrigger)</td></tr>"
        }
        if ($result.XmlNode.parsedXml.task.Actions.exec.command) {
            $tableOfResults += "<tr><td><b>Command:</b></td><td>$($result.XmlNode.parsedXml.task.Actions.exec.command)</td></tr>"
        }
        if ($result.XmlNode.parsedXml.task.Actions.exec.Arguments) {
            $tableOfResults += "<tr><td><b>Arguments:</b></td><td>$($result.XmlNode.parsedXml.task.Actions.exec.Arguments)</td></tr>"
        }
    }

    # Element Type (for debugging)
    $tableOfResults += "<tr><td><b>Element Type:</b></td><td>$($result.XmlNode.ElementName)</td></tr>"

    # GPP-specific Information
    if ($result.xmlnode.ParsedXml._desc) {
        $description = ($result.xmlnode.ParsedXml._desc) -replace ';', '<br>'
        $tableOfResults += "<tr><td><b>Description:</b></td><td>$description</td></tr>"
    }

    # Action Type
    $actionValue = $result.XmlNode.parsedXml._action ?? $result.xmlnode.ParsedXml.Properties._action
    if ($actionValue) {
        $actionText = switch ($actionValue) {
            'R' { 'Replace' }
            'U' { 'Update' }
            'D' { 'Delete' }
            default { $actionValue }
        }
        $tableOfResults += "<tr><td><b>Action:</b></td><td>$actionText</td></tr>"
    }

    # Last Changed
    if ($result.xmlnode.ParsedXml._changed) {
        $tableOfResults += "<tr><td><b>Last Changed:</b></td><td>$($result.xmlnode.ParsedXml._changed)</td></tr>"
    }

    # Policy Comment
    if ($result.XmlNode.ParsedXml.Comment) {
        $comment = ($result.XmlNode.ParsedXml.Comment) -replace ';', '<br>'
        $tableOfResults += "<tr><td><b>Comment:</b></td><td>$comment</td></tr>"
    }

    # Policy Explanation
    if ($result.XmlNode.ParsedXml.Explain) {
        $tableOfResults += "<tr><td><b>Explanation:</b></td><td>$($result.XmlNode.ParsedXml.Explain)</td></tr>"
    }

    # Close table for this result
    $tableOfResults += '</table>'
    $tableOfResults += '<br>'
}
#endregion Generate HTML Report

#region Generate and Display Report

# Generate the HTML report
Write-Host "`nGenerating HTML report..." -ForegroundColor Cyan
Write-Host "  Search String: '$SearchString'" -ForegroundColor White
Write-Host "  Total Results: $($allResults.Count)" -ForegroundColor White
Write-Host "  Output Path: $OutputPath" -ForegroundColor White

New-Report `
    -PageTitle 'GPO Search Results' `
    -SearchString $SearchString `
    -TableOfResults $tableOfResults `
    -ResultCount $allResults.Count `
    -OutputPath $OutputPath

Write-Host "`nReport generated successfully!" -ForegroundColor Green
Write-Host "Report saved to: $OutputPath" -ForegroundColor Green

#endregion Generate and Display Report


function Export-ToHTML {
    <#
    .SYNOPSIS
        Exports results to HTML format
        
    .DESCRIPTION
        Internal helper function to export search results to HTML format with styling
        
    .PARAMETER Results
        The search results to export
        
    .PARAMETER OutputPath
        Output file path
        
    .PARAMETER IncludeMetadata
        Whether to include metadata in the export
        
    .PARAMETER Metadata
        Metadata object to include
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter()]
        [switch]$IncludeMetadata,
        
        [Parameter()]
        [hashtable]$Metadata
    )
    
    try {
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>GPO Search Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .metadata { background-color: #e7f3ff; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .summary { background-color: #fff3cd; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>GPO Search Results Report</h1>
        <p>Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    </div>
"@

        if ($IncludeMetadata -and $Metadata) {
            $html += @'
    <div class="metadata">
        <h2>Export Information</h2>
        <ul>
'@
            foreach ($key in $Metadata.Keys) {
                $html += "            <li><strong>$key</strong>: $($Metadata[$key])</li>`n"
            }
            $html += @'
        </ul>
    </div>
'@
        }

        $html += @"
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Total Results:</strong> $($Results.Count)</p>
        <p><strong>Unique GPOs:</strong> $($Results | Select-Object -Unique GPOName | Measure-Object | Select-Object -ExpandProperty Count)</p>
        <p><strong>Configuration Types:</strong> $($Results | Select-Object -Unique Context | Measure-Object | Select-Object -ExpandProperty Count)</p>
    </div>

    <table>
        <tr>
            <th>GPO Name</th>
            <th>Category Path</th>
            <th>Setting Name</th>
            <th>Setting Value</th>
            <th>Context</th>
            <th>Source File</th>
        </tr>
"@

        foreach ($result in $Results) {
            $html += @"
        <tr>
            <td>$([System.Web.HttpUtility]::HtmlEncode($result.GPOName))</td>
            <td>$([System.Web.HttpUtility]::HtmlEncode($result.CategoryPath))</td>
            <td>$([System.Web.HttpUtility]::HtmlEncode($result.SettingName))</td>
            <td>$([System.Web.HttpUtility]::HtmlEncode($result.SettingValue))</td>
            <td>$([System.Web.HttpUtility]::HtmlEncode($result.Context))</td>
            <td>$([System.Web.HttpUtility]::HtmlEncode((Split-Path $result.SourceFile -Leaf)))</td>
        </tr>
"@
        }

        $html += @'
    </table>
</body>
</html>
'@

        $html | Out-File -FilePath $OutputPath -Encoding UTF8
        
        Write-Verbose "HTML export completed: $OutputPath"
    }
    catch {
        Write-Error "HTML export failed: $($_.Exception.Message)"
        throw
    }
}

function Get-ConflictAnalysis {
    <#
    .SYNOPSIS
        Performs conflict analysis on GPO search results
        
    .DESCRIPTION
        Internal helper function to analyze search results for potential conflicts
        
    .PARAMETER Results
        The search results to analyze
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results
    )
    
    try {
        $conflictFindings = @()
        
        # Group results by setting path to find potential conflicts
        $settingGroups = $Results | Group-Object @{Expression={$_.CategoryPath + '::' + $_.SettingName}}
        
        foreach ($group in $settingGroups) {
            if ($group.Count -gt 1) {
                # Multiple GPOs setting the same thing - potential conflict
                $gpoNames = $group.Group | Select-Object -ExpandProperty GPOName -Unique
                $values = $group.Group | Select-Object -ExpandProperty SettingValue -Unique
                
                if ($values.Count -gt 1) {
                    # Different values for same setting - definite conflict
                    $conflict = [PSCustomObject]@{
                        SettingPath = $group.Name -replace '::', ' > '
                        ConflictType = 'Value Mismatch'
                        AffectedGPOs = ($gpoNames -join ', ')
                        ConflictingValues = ($values -join ' | ')
                        Severity = 'High'
                        Resolution = 'Review GPO precedence and consolidate conflicting settings'
                        AnalysisDate = Get-Date
                    }
                    
                    $conflictFindings += $conflict
                }
                elseif ($gpoNames.Count -gt 1) {
                    # Same value but multiple GPOs - potential redundancy
                    $conflict = [PSCustomObject]@{
                        SettingPath = $group.Name -replace '::', ' > '
                        ConflictType = 'Redundant Configuration'
                        AffectedGPOs = ($gpoNames -join ', ')
                        ConflictingValues = $values[0]
                        Severity = 'Medium'
                        Resolution = 'Consider consolidating redundant settings into single GPO'
                        AnalysisDate = Get-Date
                    }
                    
                    $conflictFindings += $conflict
                }
            }
        }
        
        return $conflictFindings
    }
    catch {
        Write-Error "Conflict analysis failed: $($_.Exception.Message)"
        return @()
    }
}

function Get-RiskScore {
    <#
    .SYNOPSIS
        Calculates risk score for a compliance result
        
    .DESCRIPTION
        Internal helper function to calculate numerical risk score
        
    .PARAMETER Result
        The compliance result to score
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Result
    )
    
    try {
        $score = 0
        
        # Base score based on risk level
        switch ($Result.RiskLevel) {
            'High' { $score += 75 }
            'Medium' { $score += 50 }
            'Low' { $score += 25 }
            default { $score += 10 }
        }
        
        # Adjust score based on setting type
        if ($Result.SettingValue -match '(?i)(password|credential|secret)') {
            $score += 20
        }
        
        if ($Result.SettingValue -match '(?i)(guest|anonymous|everyone)') {
            $score += 15
        }
        
        if ($Result.CategoryPath -match '(?i)(security|audit)') {
            $score += 10
        }
        
        # Cap score at 100
        return [Math]::Min($score, 100)
    }
    catch {
        Write-Warning "Failed to calculate risk score: $($_.Exception.Message)"
        return 50  # Default medium risk
    }
}

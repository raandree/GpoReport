function Get-ComplianceStatus {
    <#
    .SYNOPSIS
        Determines compliance status for a result
        
    .DESCRIPTION
        Internal helper function to determine compliance status based on template and result
        
    .PARAMETER Result
        The result to evaluate
        
    .PARAMETER Template
        The compliance template being used
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Result,
        
        [Parameter(Mandatory = $true)]
        [string]$Template
    )
    
    try {
        # Determine compliance status based on template and result content
        $status = 'Compliant'
        
        # Check for non-compliant patterns
        if ($Result.RiskLevel -eq 'High') {
            $status = 'Non-Compliant'
        }
        elseif ($Result.RiskLevel -eq 'Medium') {
            $status = 'Requires Review'
        }
        
        # Template-specific compliance checks
        switch ($Template) {
            'CIS' {
                if ($Result.SettingValue -match '(?i)(guest.*enabled|anonymous.*allowed)') {
                    $status = 'Non-Compliant'
                }
            }
            'NIST' {
                if ($Result.CategoryPath -match '(?i)audit' -and $Result.SettingValue -match '(?i)(disabled|no)') {
                    $status = 'Non-Compliant'
                }
            }
            'SOX' {
                if ($Result.CategoryPath -match '(?i)(audit|log)') {
                    $status = 'Critical for Compliance'
                }
            }
            'HIPAA' {
                if ($Result.SettingValue -match '(?i)(health|medical|patient)') {
                    $status = 'Critical for Compliance'
                }
            }
        }
        
        return $status
    }
    catch {
        Write-Warning "Failed to determine compliance status: $($_.Exception.Message)"
        return 'Unknown'
    }
}

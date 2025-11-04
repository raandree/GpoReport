function Get-CompliancePatterns {
    <#
    .SYNOPSIS
        Gets compliance patterns for specified template and security level
        
    .DESCRIPTION
        Internal helper function to retrieve compliance patterns based on template and security level
        
    .PARAMETER Template
        The compliance template to use
        
    .PARAMETER SecurityLevel
        The security level for patterns
        
    .PARAMETER CustomFile
        Custom pattern file path
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Template,
        
        [Parameter(Mandatory = $true)]
        [string]$SecurityLevel,
        
        [Parameter()]
        [string]$CustomFile
    )
    
    try {
        $patterns = @()
        
        # Define base patterns for different templates
        switch ($Template) {
            'CIS' {
                $patterns += @(
                    @{ Name = 'CIS-Password-Policy'; SearchString = '*password*'; RiskLevel = 'High'; Recommendation = 'Review password complexity requirements' }
                    @{ Name = 'CIS-Audit-Policy'; SearchString = '*audit*'; RiskLevel = 'Medium'; Recommendation = 'Ensure comprehensive audit logging' }
                    @{ Name = 'CIS-Guest-Account'; SearchString = '*guest*'; RiskLevel = 'High'; Recommendation = 'Disable guest accounts' }
                    @{ Name = 'CIS-Firewall'; SearchString = '*firewall*'; RiskLevel = 'High'; Recommendation = 'Verify firewall configuration' }
                )
            }
            'NIST' {
                $patterns += @(
                    @{ Name = 'NIST-Access-Control'; SearchString = '*access*'; RiskLevel = 'Medium'; Recommendation = 'Review access control policies' }
                    @{ Name = 'NIST-Authentication'; SearchString = '*authentication*'; RiskLevel = 'High'; Recommendation = 'Verify authentication mechanisms' }
                    @{ Name = 'NIST-Logging'; SearchString = '*log*'; RiskLevel = 'Medium'; Recommendation = 'Ensure proper logging configuration' }
                )
            }
            'SOX' {
                $patterns += @(
                    @{ Name = 'SOX-Financial-Systems'; SearchString = '*financial*'; RiskLevel = 'High'; Recommendation = 'Review financial system access controls' }
                    @{ Name = 'SOX-Audit-Trail'; SearchString = '*audit*'; RiskLevel = 'High'; Recommendation = 'Maintain comprehensive audit trails' }
                )
            }
            'HIPAA' {
                $patterns += @(
                    @{ Name = 'HIPAA-Data-Access'; SearchString = '*health*'; RiskLevel = 'High'; Recommendation = 'Protect health information access' }
                    @{ Name = 'HIPAA-Encryption'; SearchString = '*encrypt*'; RiskLevel = 'High'; Recommendation = 'Ensure data encryption compliance' }
                )
            }
            'Custom' {
                if ($CustomFile -and (Test-Path $CustomFile)) {
                    # Load custom patterns from file
                    $customPatterns = Import-Csv $CustomFile
                    foreach ($pattern in $customPatterns) {
                        $patterns += @{
                            Name           = $pattern.Name
                            SearchString   = $pattern.SearchString
                            RiskLevel      = $pattern.RiskLevel
                            Recommendation = $pattern.Recommendation
                        }
                    }
                }
            }
        }
        
        # Filter patterns based on security level
        switch ($SecurityLevel) {
            'Critical' {
                $patterns = $patterns | Where-Object { $_.RiskLevel -eq 'High' }
            }
            'High' {
                $patterns = $patterns | Where-Object { $_.RiskLevel -in @('High', 'Medium') }
            }
            'Standard' {
                # Include all patterns
            }
            'Basic' {
                $patterns = $patterns | Where-Object { $_.RiskLevel -eq 'Low' }
            }
        }
        
        return $patterns
    }
    catch {
        Write-Error "Failed to get compliance patterns: $($_.Exception.Message)"
        return @()
    }
}

<#
    .SYNOPSIS
        Resolves SIDs in GPO backup XML files and replaces any that cannot
        be resolved with new SIDs from the current domain.

    .DESCRIPTION
        Scans all XML files under the specified GPO backup path for domain
        SIDs (S-1-5-21-*-RID).  Each unique SID is tested against Active
        Directory.  SIDs that resolve successfully are left untouched.

        Unresolvable SIDs are replaced with newly generated SIDs that use
        the current domain's SID as the base and a random RID.  The same
        source SID always maps to the same replacement SID across all files,
        keeping internal references consistent.

        Well-known SIDs (S-1-5-9, S-1-5-18, S-1-5-32-*, etc.) are never
        modified.

        This script is designed to run BEFORE Restore-GPOBackup.ps1 so that
        imported GPOs contain valid SIDs for the target domain.

    .PARAMETER BackupPath
        The root folder that contains the GUID-named GPO backup sub-folders.

    .EXAMPLE
        .\Update-GPOBackupDomainSid.ps1 -BackupPath C:\GpoBackup

        Resolves every SID in the backup.  Unresolvable SIDs are replaced
        with random SIDs from the current domain.

    .EXAMPLE
        .\Update-GPOBackupDomainSid.ps1 -BackupPath C:\GpoBackup -Verbose

        Same as above, with detailed output for every SID checked.

    .EXAMPLE
        .\Update-GPOBackupDomainSid.ps1 -BackupPath C:\GpoBackup -WhatIf

        Shows which files would be modified without making changes.

    .INPUTS
        None.  This script does not accept pipeline input.

    .OUTPUTS
        PSCustomObject with properties File, OldSid, NewSid, and Status
        for every replacement performed.

    .NOTES
        Author:  Raimund Andree
        Date:    2026-02-24
        Version: 2.0.0

        Run this script before Restore-GPOBackup.ps1 to sanitise domain
        SIDs in the backup data.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string]$BackupPath
)

Set-StrictMode -Version Latest

#region Helper functions

function Get-CurrentDomainSid {
    <#
        .SYNOPSIS
            Returns the SID of the current AD domain as a string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        # Preferred: use the logged-on user's SID to derive the domain SID
        $userSid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User
        return $userSid.AccountDomainSid.ToString()
    } catch {
        Write-Error 'Cannot determine the current domain SID. Ensure this machine is domain-joined.'
        throw
    }
}

function Test-SidResolvable {
    <#
        .SYNOPSIS
            Attempts to translate a SID string to an NTAccount.
            Returns $true if the SID resolves, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$SidString
    )

    try {
        $sid = [System.Security.Principal.SecurityIdentifier]::new($SidString)
        [void]$sid.Translate([System.Security.Principal.NTAccount])
        return $true
    } catch {
        return $false
    }
}

function New-RandomRid {
    <#
        .SYNOPSIS
            Generates a random RID in the user-definable range (1000+).
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    return Get-Random -Minimum 10000 -Maximum 2147483647
}

function Get-XmlFileEncoding {
    <#
        .SYNOPSIS
            Detects the encoding of an XML file by inspecting its BOM.
    #>
    [CmdletBinding()]
    [OutputType([System.Text.Encoding])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $bytes = [byte[]]::new(4)
    $stream = [System.IO.File]::OpenRead($FilePath)
    try {
        [void]$stream.Read($bytes, 0, 4)
    } finally {
        $stream.Close()
    }

    if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [System.Text.Encoding]::Unicode          # UTF-16 LE
    }
    if ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        return [System.Text.Encoding]::BigEndianUnicode  # UTF-16 BE
    }
    if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.Text.Encoding]::UTF8              # UTF-8 with BOM
    }

    return [System.Text.Encoding]::UTF8                  # Default to UTF-8
}

#endregion

# ── Determine the current domain SID ──────────────────────────────────────────
$currentDomainSid = Get-CurrentDomainSid
Write-Host "Current domain SID: $currentDomainSid" -ForegroundColor Cyan

# ── Collect all XML files ─────────────────────────────────────────────────────
$xmlFiles = Get-ChildItem -Path $BackupPath -Filter '*.xml' -Recurse -File |
    Select-Object -ExpandProperty FullName

if ($xmlFiles.Count -eq 0) {
    Write-Warning "No XML files found under '$BackupPath'."
    return
}

Write-Verbose "Found $($xmlFiles.Count) XML file(s) under '$BackupPath'."

# ── Phase 1: Discover all unique domain SIDs (S-1-5-21-*-RID) ────────────────
# Match only full SIDs that include a RID to avoid truncated matches from
# greedy quantifiers.
$fullSidPattern  = 'S-1-5-21-\d+-\d+-\d+-\d+'
$allUniqueSids   = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($filePath in $xmlFiles) {
    $encoding = Get-XmlFileEncoding -FilePath $filePath
    $content  = [System.IO.File]::ReadAllText($filePath, $encoding)
    $matches  = [regex]::Matches($content, $fullSidPattern)

    foreach ($m in $matches) {
        [void]$allUniqueSids.Add($m.Value)
    }
}

if ($allUniqueSids.Count -eq 0) {
    Write-Host 'No domain SIDs (S-1-5-21-*) found in any XML file.  Nothing to do.' -ForegroundColor Green
    return
}

Write-Host "Found $($allUniqueSids.Count) unique domain SID(s) to check." -ForegroundColor Cyan

# ── Phase 2: Resolve each SID and build the replacement map ───────────────────
$sidMap          = @{}   # Old full SID  → New full SID
$foreignDomains  = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$resolvedCount   = 0
$unresolvedCount = 0
$usedRids        = [System.Collections.Generic.HashSet[int]]::new()

foreach ($sid in $allUniqueSids) {
    $parts = $sid -split '-'

    if ($parts.Count -ne 8) {
        Write-Verbose "Skipping unexpected SID format: $sid"
        continue
    }

    # Extract domain portion: S-1-5-21-A-B-C
    $domainPart = ($parts[0..6]) -join '-'

    # Skip SIDs that already belong to the current domain
    if ($domainPart -eq $currentDomainSid) {
        Write-Verbose "  [Current Domain] $sid — belongs to this domain, skipping."
        $resolvedCount++
        continue
    }

    # Try to resolve the SID against AD
    $isResolvable = Test-SidResolvable -SidString $sid

    if ($isResolvable) {
        Write-Verbose "  [Resolved]   $sid"
        $resolvedCount++
        continue
    }

    # Unresolvable — generate a replacement with the current domain SID + random RID
    $unresolvedCount++

    if (-not $sidMap.ContainsKey($sid)) {
        do {
            $newRid = New-RandomRid
        } while (-not $usedRids.Add($newRid))

        $newSid = "$currentDomainSid-$newRid"
        $sidMap[$sid] = $newSid
        Write-Verbose "  [Unresolved] $sid -> $newSid"
    }

    # Track foreign domain prefixes so we can replace bare domain SIDs in
    # SDDL strings after all full-SID replacements have been applied.
    [void]$foreignDomains.Add($domainPart)
}

Write-Host ''
Write-Host "SID resolution summary:" -ForegroundColor Cyan
Write-Host "  Resolved / current domain : $resolvedCount" -ForegroundColor Green
Write-Host "  Unresolvable (to replace) : $unresolvedCount" -ForegroundColor Yellow
Write-Host "  Unique SID mappings       : $($sidMap.Count)" -ForegroundColor Yellow
Write-Host "  Foreign domain prefixes   : $($foreignDomains.Count)" -ForegroundColor Yellow
Write-Host ''

if ($sidMap.Count -eq 0) {
    Write-Host 'All SIDs resolved successfully.  No replacements needed.' -ForegroundColor Green
    return
}

# ── Phase 3: Apply replacements ──────────────────────────────────────────────
# 1) Replace full SIDs first (longest match first) so the domain prefix
#    inside a full SID is not partially replaced.
# 2) Then replace any remaining bare domain-SID prefixes that may appear
#    in SDDL strings or other contexts.
$orderedReplacements = @()

# Full SID replacements — longest first
foreach ($entry in $sidMap.GetEnumerator() | Sort-Object -Property { $_.Key.Length } -Descending) {
    $orderedReplacements += @{ Old = $entry.Key; New = $entry.Value }
}

# Bare domain-prefix replacements — derived from the foreign domains set
foreach ($domainPrefix in $foreignDomains) {
    $orderedReplacements += @{ Old = $domainPrefix; New = $currentDomainSid }
}

$totalReplacements = 0
$modifiedFiles     = 0

foreach ($filePath in $xmlFiles) {
    $encoding = Get-XmlFileEncoding -FilePath $filePath
    $content  = [System.IO.File]::ReadAllText($filePath, $encoding)
    $originalContent = $content

    $fileReplacements = 0

    foreach ($replacement in $orderedReplacements) {
        $escapedOld = [regex]::Escape($replacement.Old)
        $matchCount = ([regex]::Matches($content, $escapedOld)).Count

        if ($matchCount -gt 0) {
            $content = $content -replace $escapedOld, $replacement.New
            $fileReplacements += $matchCount
        }
    }

    if ($fileReplacements -eq 0) {
        Write-Verbose "No replacements needed in: $filePath"
        continue
    }

    $relativePath = $filePath
    if ($filePath.StartsWith($BackupPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relativePath = $filePath.Substring($BackupPath.TrimEnd('\').Length + 1)
    }

    if ($PSCmdlet.ShouldProcess($relativePath, "Replace $fileReplacements SID occurrence(s)")) {
        [System.IO.File]::WriteAllText($filePath, $content, $encoding)

        $modifiedFiles++
        $totalReplacements += $fileReplacements

        Write-Verbose "Replaced $fileReplacements occurrence(s) in: $relativePath"
    }

    # Emit per-file detail objects for each unique SID replaced in this file
    foreach ($replacement in $orderedReplacements) {
        $escapedOld = [regex]::Escape($replacement.Old)
        $hitCount   = ([regex]::Matches($originalContent, $escapedOld)).Count

        if ($hitCount -gt 0) {
            [PSCustomObject]@{
                File   = $relativePath
                OldSid = $replacement.Old
                NewSid = $replacement.New
                Count  = $hitCount
                Status = 'Replaced'
            }
        }
    }
}

Write-Host ''
Write-Host "Summary: $totalReplacements replacement(s) across $modifiedFiles file(s)." -ForegroundColor Cyan

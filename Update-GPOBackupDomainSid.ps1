<#
    .SYNOPSIS
        Resolves SIDs in GPO backup files and replaces any that cannot
        be resolved with real SIDs from the current Active Directory domain.

    .DESCRIPTION
        Scans all text-based files (XML, INF, CMTX, CSV) under the specified
        GPO backup path for domain SIDs (S-1-5-21-*-RID).  Each unique SID
        is tested against Active Directory.  SIDs that resolve successfully
        are left untouched.

        Unresolvable SIDs are handled as follows:

        - Well-known RIDs (e.g. -512 Domain Admins, -519 Enterprise Admins)
          are mapped to the same RID under the current domain SID, because
          these RIDs are identical in every AD domain.

        - Custom / non-well-known RIDs are replaced with the SID of a
          randomly selected real security principal (user, group, or
          computer) from the current domain.  A consistent mapping is
          maintained so the same source SID always maps to the same
          replacement across all files.

        Well-known SIDs without a domain prefix (S-1-5-9, S-1-5-18,
        S-1-5-32-*, etc.) are never modified.

        This script is designed to run BEFORE Restore-GPOBackup.ps1 so that
        imported GPOs contain valid, resolvable SIDs for the target domain.

    .PARAMETER BackupPath
        The root folder that contains the GUID-named GPO backup sub-folders.

    .EXAMPLE
        .\Update-GPOBackupDomainSid.ps1 -BackupPath C:\GpoBackup

        Resolves every SID in the backup.  Unresolvable SIDs are replaced
        with real SIDs from the current AD domain.

    .EXAMPLE
        .\Update-GPOBackupDomainSid.ps1 -BackupPath C:\GpoBackup -Verbose

        Same as above, with detailed output for every SID checked.

    .EXAMPLE
        .\Update-GPOBackupDomainSid.ps1 -BackupPath C:\GpoBackup -WhatIf

        Shows which files would be modified without making changes.

    .INPUTS
        None.  This script does not accept pipeline input.

    .OUTPUTS
        PSCustomObject with properties File, OldSid, NewSid, NewName,
        and Status for every replacement performed.

    .NOTES
        Author:  Raimund Andree
        Date:    2026-02-24
        Version: 3.0.0

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
            Returns the account name if resolvable, $null otherwise.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$SidString
    )

    try {
        $sid     = [System.Security.Principal.SecurityIdentifier]::new($SidString)
        $account = $sid.Translate([System.Security.Principal.NTAccount])
        return $account.Value
    } catch {
        return $null
    }
}

function Get-ADSecurityPrincipalPool {
    <#
        .SYNOPSIS
            Queries AD for real security principals and returns an array
            of objects with SID and Name properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    $searcher = [System.DirectoryServices.DirectorySearcher]::new()
    $searcher.Filter = '(objectSid=*)'
    $searcher.PropertiesToLoad.AddRange(@('objectSid', 'sAMAccountName', 'objectClass'))
    $searcher.PageSize = 1000
    $searcher.SizeLimit = 0

    Write-Verbose 'Querying Active Directory for security principals...'
    $results = $searcher.FindAll()

    $pool = foreach ($result in $results) {
        $sidBytes = $result.Properties['objectsid'][0]
        if ($sidBytes) {
            $sid = [System.Security.Principal.SecurityIdentifier]::new($sidBytes, 0)
            $sidString = $sid.ToString()

            # Only include domain SIDs (S-1-5-21-*) with a RID
            if ($sidString -match '^S-1-5-21-\d+-\d+-\d+-\d+$') {
                $name = if ($result.Properties['samaccountname'].Count -gt 0) {
                    $result.Properties['samaccountname'][0]
                } else {
                    $sidString
                }

                [PSCustomObject]@{
                    Sid  = $sidString
                    Name = $name
                }
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    Write-Verbose "Retrieved $($pool.Count) security principal(s) from AD."
    return $pool
}

function Get-XmlFileEncoding {
    <#
        .SYNOPSIS
            Detects the encoding of a file by inspecting its BOM.
    #>
    [CmdletBinding()]
    [OutputType([System.Text.Encoding])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $bytes  = [byte[]]::new(4)
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

# Well-known RIDs that exist with identical values in every AD domain.
# These are mapped deterministically: old-domain-SID-RID → current-domain-SID-RID.
$wellKnownRids = @(
    498   # Enterprise Read-Only Domain Controllers
    500   # Administrator
    501   # Guest
    502   # krbtgt
    512   # Domain Admins
    513   # Domain Users
    514   # Domain Guests
    515   # Domain Computers
    516   # Domain Controllers
    517   # Cert Publishers
    518   # Schema Admins
    519   # Enterprise Admins
    520   # Group Policy Creator Owners
    521   # Read-Only Domain Controllers
    522   # Cloneable Domain Controllers
    525   # Protected Users
    526   # Key Admins
    527   # Enterprise Key Admins
    553   # RAS and IAS Servers
    571   # Allowed RODC Password Replication Group
    572   # Denied RODC Password Replication Group
)

# ── Determine the current domain SID ──────────────────────────────────────────
$currentDomainSid = Get-CurrentDomainSid
Write-Host "Current domain SID: $currentDomainSid" -ForegroundColor Cyan

# ── Collect all text-based GPO backup files ───────────────────────────────────
# GPO backups contain SIDs in XML reports, INF security templates, CMTX
# comment files, and CSV audit maps.  Binary .pol files are excluded.
$textExtensions = @('*.xml', '*.inf', '*.cmtx', '*.csv')
$backupFiles = foreach ($ext in $textExtensions) {
    Get-ChildItem -Path $BackupPath -Filter $ext -Recurse -File
}
$backupFiles = @($backupFiles | Select-Object -ExpandProperty FullName)

if ($backupFiles.Count -eq 0) {
    Write-Warning "No text-based GPO files found under '$BackupPath'."
    return
}

Write-Verbose "Found $($backupFiles.Count) text-based file(s) under '$BackupPath'."

# ── Phase 1: Discover all unique domain SIDs (S-1-5-21-*-RID) ────────────────
$fullSidPattern = 'S-1-5-21-\d+-\d+-\d+-\d+'
$allUniqueSids  = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($filePath in $backupFiles) {
    $encoding = Get-XmlFileEncoding -FilePath $filePath
    $content  = [System.IO.File]::ReadAllText($filePath, $encoding)
    $matches  = [regex]::Matches($content, $fullSidPattern)

    foreach ($m in $matches) {
        [void]$allUniqueSids.Add($m.Value)
    }
}

if ($allUniqueSids.Count -eq 0) {
    Write-Host 'No domain SIDs (S-1-5-21-*) found in any file.  Nothing to do.' -ForegroundColor Green
    return
}

Write-Host "Found $($allUniqueSids.Count) unique domain SID(s) to check." -ForegroundColor Cyan

# ── Phase 2: Resolve each SID and build the replacement map ───────────────────
$sidMap         = @{}   # Old full SID → New full SID
$sidNameMap     = @{}   # Old full SID → Replacement account name
$foreignDomains = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$resolvedCount   = 0
$unresolvedCount = 0

# Lazily load the AD principal pool only when needed
$adPool      = $null
$adPoolIndex = 0

foreach ($sid in $allUniqueSids) {
    $parts = $sid -split '-'

    if ($parts.Count -ne 8) {
        Write-Verbose "Skipping unexpected SID format: $sid"
        continue
    }

    $domainPart = ($parts[0..6]) -join '-'
    $rid        = [int]$parts[7]

    # Try to resolve the SID against AD / local SAM
    $resolvedName = Test-SidResolvable -SidString $sid

    if ($resolvedName) {
        Write-Verbose "  [Resolved]   $sid ($resolvedName)"
        $resolvedCount++
        continue
    }

    # Unresolvable
    $unresolvedCount++

    if ($sidMap.ContainsKey($sid)) {
        continue
    }

    # Strategy 1: Well-known RID — map to same RID in current domain
    if ($rid -in $wellKnownRids) {
        $newSid     = "$currentDomainSid-$rid"
        $newName    = Test-SidResolvable -SidString $newSid
        $sidMap[$sid]     = $newSid
        $sidNameMap[$sid] = if ($newName) { $newName } else { "(well-known RID $rid)" }
        Write-Verbose "  [Well-Known] $sid -> $newSid ($($sidNameMap[$sid]))"
        [void]$foreignDomains.Add($domainPart)
        continue
    }

    # Strategy 2: Custom RID — pick a real security principal from AD
    if (-not $adPool) {
        $adPool = @(Get-ADSecurityPrincipalPool)
        # Shuffle the pool so assignments are random
        $adPool = $adPool | Get-Random -Count $adPool.Count
        $adPoolIndex = 0

        if ($adPool.Count -eq 0) {
            Write-Warning 'No security principals found in the current domain. Cannot map custom SIDs.'
            break
        }
    }

    # Pick the next principal from the shuffled pool (wrapping if needed)
    $principal = $adPool[$adPoolIndex % $adPool.Count]
    $adPoolIndex++

    $sidMap[$sid]     = $principal.Sid
    $sidNameMap[$sid] = $principal.Name
    Write-Verbose "  [Mapped]     $sid -> $($principal.Sid) ($($principal.Name))"

    [void]$foreignDomains.Add($domainPart)
}

Write-Host ''
Write-Host "SID resolution summary:" -ForegroundColor Cyan
Write-Host "  Already resolvable : $resolvedCount" -ForegroundColor Green
Write-Host "  Unresolvable       : $unresolvedCount" -ForegroundColor Yellow
Write-Host "  Unique mappings    : $($sidMap.Count)" -ForegroundColor Yellow
Write-Host "  Foreign domains    : $($foreignDomains.Count)" -ForegroundColor Yellow
Write-Host ''

if ($sidMap.Count -gt 0) {
    Write-Host 'Replacement mapping:' -ForegroundColor Cyan
    foreach ($entry in $sidMap.GetEnumerator() | Sort-Object -Property Key) {
        $name = $sidNameMap[$entry.Key]
        Write-Host "  $($entry.Key) -> $($entry.Value) ($name)"
    }
    Write-Host ''
}

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

foreach ($filePath in $backupFiles) {
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
                NewName = if ($sidNameMap.ContainsKey($replacement.Old)) { $sidNameMap[$replacement.Old] } else { '(domain prefix)' }
                Count  = $hitCount
                Status = 'Replaced'
            }
        }
    }
}

Write-Host ''
Write-Host "Summary: $totalReplacements replacement(s) across $modifiedFiles file(s)." -ForegroundColor Cyan

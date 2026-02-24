<#
.SYNOPSIS
    Adds domain-SID-bearing test data to GPO backup files for all known SID-list setting types.

.DESCRIPTION
    Enriches an existing GPO backup tree with test data that contains domain SIDs in
    every Group Policy setting type known to embed Security Identifiers.  This allows
    Update-GPOBackupDomainSid.ps1 to be validated against a comprehensive corpus.

    The function is idempotent: running it a second time will overwrite its own sentinel
    markers and produce the same result.

    Setting types covered (INF):
      - [Privilege Rights]         comma-separated *SID lists
      - [Group Membership]         __Memberof / __Members with *SID values
      - [Service General Setting]  service entries with SDDL containing domain SIDs
      - [File Security]            file ACL entries with SDDL containing domain SIDs
      - [Registry Keys]            registry ACL entries with SDDL containing domain SIDs

    Setting types covered (GPP XML):
      - Groups.xml                 groupSid, Member sid attributes
      - ScheduledTasks.xml         TaskV2 with <UserId> SID element
      - Services.xml               NTService with accountSid attribute

.PARAMETER BackupPath
    Root of the GPO backup tree (e.g. C:\GpoReport\GpoBackup).

.PARAMETER DomainSid
    The domain SID to embed in the test data.  Defaults to the current domain SID
    derived from the running user's SID.

.PARAMETER RidPool
    An array of custom RIDs to combine with DomainSid.  When omitted, the script
    queries the current Active Directory for real user and group SIDs instead.

.PARAMETER SampleCount
    How many user and group principals to retrieve from AD when RidPool is not
    supplied.  The script fetches SampleCount users and SampleCount groups.
    Defaults to 10.

.EXAMPLE
    .\Add-GPOTestSidData.ps1 -BackupPath C:\GpoReport\GpoBackup
    # Queries AD for 10 random users and 10 random groups, embeds their real SIDs.

.EXAMPLE
    .\Add-GPOTestSidData.ps1 -BackupPath C:\GpoReport\GpoBackup -SampleCount 20
    # Same but samples 20 of each.

.PARAMETER RestrictedGroupCount
    Number of restricted groups to generate in the [Group Membership] INF section
    and in GPP Groups.xml.  Each group will receive a random number of members
    between MembersPerGroupMin and MembersPerGroupMax.  Defaults to 0 (legacy
    behaviour that creates a small fixed set).

.PARAMETER MembersPerGroupMin
    Minimum number of member SIDs to add to each generated restricted group.
    Defaults to 1.

.PARAMETER MembersPerGroupMax
    Maximum number of member SIDs to add to each generated restricted group.
    Defaults to 5.

.EXAMPLE
    .\Add-GPOTestSidData.ps1 -BackupPath C:\GpoReport\GpoBackup -DomainSid 'S-1-5-21-111-222-333' -RidPool @(1103,1960)
    # Uses explicit domain SID and RID list instead of querying AD.

.EXAMPLE
    .\Add-GPOTestSidData.ps1 -BackupPath C:\GpoReport\GpoBackup -RestrictedGroupCount 50 -MembersPerGroupMin 5 -MembersPerGroupMax 50
    # Creates 50 restricted groups, each with 5-50 random member SIDs.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$BackupPath,

    [Parameter()]
    [ValidatePattern('^S-1-5-21-\d+-\d+-\d+$')]
    [string]$DomainSid,

    [Parameter()]
    [int[]]$RidPool,

    [Parameter()]
    [ValidateRange(2, 1000)]
    [int]$SampleCount = 10,

    [Parameter()]
    [ValidateRange(0, 10000)]
    [int]$RestrictedGroupCount = 0,

    [Parameter()]
    [ValidateRange(1, 1000)]
    [int]$MembersPerGroupMin = 1,

    [Parameter()]
    [ValidateRange(1, 1000)]
    [int]$MembersPerGroupMax = 5
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

#region --- Helper: Derive domain SID from current user ---
if (-not $DomainSid) {
    $currentUserSid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    $DomainSid = $currentUserSid -replace '-\d+$', ''
    Write-Verbose "Derived domain SID from current user: $DomainSid"
}
#endregion

#region --- Constants ---
$testDataBeginMarker = '; --- Begin Add-GPOTestSidData ---'
$testDataEndMarker   = '; --- End Add-GPOTestSidData ---'

# Helper to build a starred SID for INF files
function Format-InfSid {
    param([string]$Sid)
    return "*$Sid"
}

# Helper to build an SDDL ACE with a domain SID
function New-SddlAce {
    param(
        [string]$Sid,
        [string]$AccessMask = 'CCLCSWRPWPDTLOCRRC',
        [string]$AceType = 'A'
    )
    return "(${AceType};;${AccessMask};;;${Sid})"
}

#endregion

# Validate MembersPerGroupMin <= MembersPerGroupMax
if ($MembersPerGroupMin -gt $MembersPerGroupMax) {
    throw "MembersPerGroupMin ($MembersPerGroupMin) must be less than or equal to MembersPerGroupMax ($MembersPerGroupMax)."
}

#region --- Build SID pools ---
if ($RidPool) {
    # Explicit RID mode: build SIDs from DomainSid + RIDs
    Write-Verbose "Using explicit RidPool with $($RidPool.Count) RIDs"
    $userSidPool  = @()
    $groupSidPool = @()
    $userNamePool  = @()
    $groupNamePool = @()
    foreach ($rid in $RidPool) {
        $userSidPool  += "$DomainSid-$rid"
        $userNamePool += "RID_$rid"
    }
    # Use first 3 RIDs as groups too (or all if fewer than 3)
    $groupCount = [math]::Min($RidPool.Count, 3)
    for ($i = 0; $i -lt $groupCount; $i++) {
        $groupSidPool += "$DomainSid-$($RidPool[$i])"
        $groupNamePool += "RID_$($RidPool[$i])"
    }
}
else {
    # AD mode: query real users and groups from the current domain
    Write-Host "Querying Active Directory for $SampleCount users and $SampleCount groups..." -ForegroundColor Cyan

    $domainRoot = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().GetDirectoryEntry()

    # --- Retrieve users ---
    $userSearcher = [System.DirectoryServices.DirectorySearcher]::new($domainRoot)
    $userSearcher.Filter = '(&(objectCategory=person)(objectClass=user)(objectSid=*))'
    $userSearcher.PageSize = 500
    [void]$userSearcher.PropertiesToLoad.AddRange(@('objectSid', 'sAMAccountName'))
    $allUsers = $userSearcher.FindAll()
    Write-Verbose "  Found $($allUsers.Count) user objects in AD"

    # Shuffle and pick SampleCount
    $shuffledUsers = $allUsers | Get-Random -Count ([math]::Min($SampleCount, $allUsers.Count))
    $userSidPool  = @()
    $userNamePool  = @()
    foreach ($entry in $shuffledUsers) {
        $sidBytes = $entry.Properties['objectsid'][0]
        $sid = ([System.Security.Principal.SecurityIdentifier]::new($sidBytes, 0)).Value
        $name = [string]$entry.Properties['samaccountname'][0]
        $userSidPool  += $sid
        $userNamePool  += $name
    }
    $allUsers.Dispose()
    Write-Host "  Sampled $($userSidPool.Count) users" -ForegroundColor Green

    # --- Retrieve groups ---
    $groupSearcher = [System.DirectoryServices.DirectorySearcher]::new($domainRoot)
    $groupSearcher.Filter = '(&(objectCategory=group)(objectSid=*))'
    $groupSearcher.PageSize = 500
    [void]$groupSearcher.PropertiesToLoad.AddRange(@('objectSid', 'sAMAccountName'))
    $allGroups = $groupSearcher.FindAll()
    Write-Verbose "  Found $($allGroups.Count) group objects in AD"

    $shuffledGroups = $allGroups | Get-Random -Count ([math]::Min($SampleCount, $allGroups.Count))
    $groupSidPool  = @()
    $groupNamePool  = @()
    foreach ($entry in $shuffledGroups) {
        $sidBytes = $entry.Properties['objectsid'][0]
        $sid = ([System.Security.Principal.SecurityIdentifier]::new($sidBytes, 0)).Value
        $name = [string]$entry.Properties['samaccountname'][0]
        $groupSidPool  += $sid
        $groupNamePool  += $name
    }
    $allGroups.Dispose()
    Write-Host "  Sampled $($groupSidPool.Count) groups" -ForegroundColor Green

    # Derive DomainSid from the first user if not explicitly provided
    if (-not $DomainSid -and $userSidPool.Count -gt 0) {
        $DomainSid = $userSidPool[0] -replace '-\d+$', ''
        Write-Verbose "Derived domain SID from AD user: $DomainSid"
    }
}

# Sanity check
if ($userSidPool.Count -lt 2) {
    throw "Need at least 2 user SIDs but only got $($userSidPool.Count).  Check AD connectivity or supply -RidPool."
}
if ($groupSidPool.Count -lt 1) {
    throw "Need at least 1 group SID but got none.  Check AD connectivity or supply -RidPool."
}

Write-Verbose "User SID pool  ($($userSidPool.Count)): $($userSidPool -join ', ')"
Write-Verbose "Group SID pool ($($groupSidPool.Count)): $($groupSidPool -join ', ')"
#endregion

#region --- 1. Find target GPO folders ---
$infTargetGuid = $null
$gppTargetGuid = $null

$gpoFolders = Get-ChildItem -Path $BackupPath -Directory -Filter '{*}'
foreach ($folder in $gpoFolders) {
    $infFile = Get-ChildItem -Path $folder.FullName -Recurse -Filter 'GptTmpl.inf' -ErrorAction SilentlyContinue | Select-Object -First 1
    $prefsDir = Get-ChildItem -Path $folder.FullName -Recurse -Directory -Filter 'Preferences' -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($infFile -and -not $infTargetGuid) {
        # Prefer an INF that already has [Privilege Rights] so we enrich it
        $content = Get-Content -Path $infFile.FullName -Raw
        if ($content -match '\[Privilege Rights\]') {
            $infTargetGuid = $folder
            Write-Verbose "INF target: $($folder.Name)"
        }
    }
    if ($prefsDir -and -not $gppTargetGuid) {
        $gppTargetGuid = $folder
        Write-Verbose "GPP target: $($folder.Name)"
    }
}

# Fallback: use first INF file found
if (-not $infTargetGuid) {
    foreach ($folder in $gpoFolders) {
        $infFile = Get-ChildItem -Path $folder.FullName -Recurse -Filter 'GptTmpl.inf' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($infFile) {
            $infTargetGuid = $folder
            Write-Verbose "INF fallback target: $($folder.Name)"
            break
        }
    }
}

if (-not $infTargetGuid) {
    Write-Warning 'No GptTmpl.inf found in any GPO backup folder.  INF test data will not be added.'
}
if (-not $gppTargetGuid) {
    Write-Warning 'No Preferences folder found in any GPO backup folder.  GPP XML test data will not be added.'
}
#endregion

#region --- 2. Enrich GptTmpl.inf ---
if ($infTargetGuid) {
    $infFile = Get-ChildItem -Path $infTargetGuid.FullName -Recurse -Filter 'GptTmpl.inf' | Select-Object -First 1
    $infPath = $infFile.FullName
    Write-Host "Enriching INF: $infPath" -ForegroundColor Cyan

    # Read raw text to preserve encoding
    $rawBytes = [System.IO.File]::ReadAllBytes($infPath)
    $hasBom = ($rawBytes.Length -ge 2 -and $rawBytes[0] -eq 0xFF -and $rawBytes[1] -eq 0xFE)
    $encoding = if ($hasBom) { [System.Text.Encoding]::Unicode } else { [System.Text.UTF8Encoding]::new($false) }
    $infText = $encoding.GetString($rawBytes)

    # Parse into ordered sections
    $sections = [ordered]@{}
    $currentSection = '__header__'
    $sections[$currentSection] = [System.Collections.Generic.List[string]]::new()

    foreach ($line in ($infText -split '\r?\n')) {
        if ($line -match '^\[(.+)\]$') {
            $currentSection = $Matches[1]
            if (-not $sections.Contains($currentSection)) {
                $sections[$currentSection] = [System.Collections.Generic.List[string]]::new()
            }
        }
        else {
            $sections[$currentSection].Add($line)
        }
    }

    # --- Remove any prior test-data marker blocks ---
    $beginPattern = [regex]::Escape($testDataBeginMarker)
    $endPattern   = [regex]::Escape($testDataEndMarker)
    foreach ($key in @($sections.Keys)) {
        $cleaned = [System.Collections.Generic.List[string]]::new()
        $inBlock = $false
        foreach ($sectionLine in $sections[$key]) {
            if ($sectionLine -match $beginPattern) {
                $inBlock = $true
                continue
            }
            if ($sectionLine -match $endPattern) {
                $inBlock = $false
                continue
            }
            if (-not $inBlock) {
                $cleaned.Add($sectionLine)
            }
        }
        $sections[$key] = $cleaned
    }

    # --- Remove any legacy sentinel lines from prior script versions ---
    $legacySentinel = '# Added by Add-GPOTestSidData'
    foreach ($key in @($sections.Keys)) {
        $sections[$key] = [System.Collections.Generic.List[string]](
            $sections[$key] | Where-Object { $_ -notmatch [regex]::Escape($legacySentinel) }
        )
    }

    # --- 2a. [Service General Setting]: add entries with SDDL containing domain SIDs ---
    $svcSection = 'Service General Setting'
    if (-not $sections.Contains($svcSection)) {
        $sections[$svcSection] = [System.Collections.Generic.List[string]]::new()
    }
    # Remove any prior test entries (TestSvc*)
    $sections[$svcSection] = [System.Collections.Generic.List[string]]($sections[$svcSection] | Where-Object { $_ -notmatch '^"TestSvc' })

    $sddlSvc1 = "D:AR$(New-SddlAce -Sid $userSidPool[0])$(New-SddlAce -Sid $userSidPool[1] -AccessMask 'CCDCLCSWRPWPDTLOCRSDRCWDWO')"
    $svcAce2a = if ($userSidPool.Count -gt 2) { $userSidPool[2] } else { $userSidPool[0] }
    $svcAce2b = if ($userSidPool.Count -gt 3) { $userSidPool[3] } else { $userSidPool[1] }
    $sddlSvc2 = "D:AR$(New-SddlAce -Sid $svcAce2a)$(New-SddlAce -Sid $svcAce2b)"
    $sections[$svcSection].Add($testDataBeginMarker)
    $sections[$svcSection].Add("`"TestSvcAlpha`",2,`"$sddlSvc1`"")
    $sections[$svcSection].Add("`"TestSvcBravo`",3,`"$sddlSvc2`"")
    $sections[$svcSection].Add($testDataEndMarker)
    Write-Verbose "  Added [Service General Setting] with domain SIDs"

    # --- 2b. [File Security]: add entry with SDDL containing domain SIDs ---
    $fsSection = 'File Security'
    if (-not $sections.Contains($fsSection)) {
        $sections[$fsSection] = [System.Collections.Generic.List[string]]::new()
    }
    $sections[$fsSection] = [System.Collections.Generic.List[string]]($sections[$fsSection] | Where-Object { $_ -notmatch 'TestSidDir' })

    $fsAce1 = $userSidPool[0]
    $fsAce2 = if ($userSidPool.Count -gt 4) { $userSidPool[4] } else { $userSidPool[1] }
    $fsAce3 = if ($userSidPool.Count -gt 5) { $userSidPool[5] } else { $userSidPool[0] }
    $sddlFs = "D:PAR(A;OICI;FA;;;BA)(A;OICI;FA;;;SY)$(New-SddlAce -Sid $fsAce1 -AccessMask '0x1200a9')(A;OICI;0x1200a9;;;BU)$(New-SddlAce -Sid $fsAce2 -AccessMask 'FA')$(New-SddlAce -Sid $fsAce3 -AccessMask '0x1200a9')"
    $sections[$fsSection].Add($testDataBeginMarker)
    $sections[$fsSection].Add("`"%SystemDrive%\TestSidDir`",0,`"$sddlFs`"")
    $sections[$fsSection].Add($testDataEndMarker)
    Write-Verbose "  Added [File Security] with domain SIDs"

    # --- 2c. [Registry Keys]: add entry with SDDL containing domain SIDs ---
    $rkSection = 'Registry Keys'
    if (-not $sections.Contains($rkSection)) {
        $sections[$rkSection] = [System.Collections.Generic.List[string]]::new()
    }
    $sections[$rkSection] = [System.Collections.Generic.List[string]]($sections[$rkSection] | Where-Object { $_ -notmatch 'TestSidKey' })

    $rkAce1 = $userSidPool[1]
    $rkAce2 = if ($userSidPool.Count -gt 6) { $userSidPool[6] } else { $userSidPool[0] }
    $rkAce3 = if ($userSidPool.Count -gt 7) { $userSidPool[7] } else { $userSidPool[1] }
    $sddlRk = "D:PAR(A;CI;KA;;;BA)(A;CI;KA;;;SY)$(New-SddlAce -Sid $rkAce1 -AccessMask 'KA')$(New-SddlAce -Sid $rkAce2 -AccessMask 'KR')$(New-SddlAce -Sid $rkAce3 -AccessMask 'KR')"
    $sections[$rkSection].Add($testDataBeginMarker)
    $sections[$rkSection].Add("`"MACHINE\SOFTWARE\TestSidKey`",0,`"$sddlRk`"")
    $sections[$rkSection].Add($testDataEndMarker)
    Write-Verbose "  Added [Registry Keys] with domain SIDs"

    # --- 2d. [Privilege Rights]: ensure multi-SID entries with domain SIDs ---
    $prSection = 'Privilege Rights'
    if ($sections.Contains($prSection)) {
        # Remove prior test entries
        $sections[$prSection] = [System.Collections.Generic.List[string]]($sections[$prSection] | Where-Object { $_ -notmatch 'SeTestPrivilege' })
        # Use up to 4 user SIDs (or as many as available)
        $prCount = [math]::Min(4, $userSidPool.Count)
        $sidList = $userSidPool[0..($prCount - 1)] | ForEach-Object { Format-InfSid $_ }
        $sections[$prSection].Add($testDataBeginMarker)
        $sections[$prSection].Add("SeTestPrivilege = $($sidList -join ',')")
        $sections[$prSection].Add($testDataEndMarker)
        Write-Verbose "  Added [Privilege Rights] multi-SID test entry ($prCount SIDs)"
    }

    # --- 2e. [Group Membership]: ensure multi-SID membership ---
    $gmSection = 'Group Membership'
    if (-not $sections.Contains($gmSection)) {
        $sections[$gmSection] = [System.Collections.Generic.List[string]]::new()
    }
    # Capture original entry key SIDs before any test-data cleanup
    $originalGmSids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($gmLine in $sections[$gmSection]) {
        if ($gmLine -match '^\*(S[-\d]+)__') {
            [void]$originalGmSids.Add($Matches[1])
        }
    }
    # Remove prior fixed test entries by pattern (idempotent without markers)
    $sections[$gmSection] = [System.Collections.Generic.List[string]](
        $sections[$gmSection] | Where-Object { $_ -notmatch '^\*S-1-5-32-544__' }
    )
    # Use up to 3 user SIDs as members of Administrators
    $gmCount = [math]::Min(3, $userSidPool.Count)
    $memberSids = $userSidPool[0..($gmCount - 1)] | ForEach-Object { Format-InfSid $_ }
    $sections[$gmSection].Add($testDataBeginMarker)
    $sections[$gmSection].Add("*S-1-5-32-544__Members = $($memberSids -join ',')")
    # Add a __Memberof entry using builtin SID key for pattern-based cleanup
    $sections[$gmSection].Add("*S-1-5-32-544__Memberof = *$($groupSidPool[0])")
    Write-Verbose "  Added [Group Membership] multi-SID test entry ($gmCount members)"

    # --- 2f. [Group Membership]: scaled restricted-group generation ---
    if ($RestrictedGroupCount -gt 0) {
        # Combine user + group pools into a single pool for group SIDs so we
        # have the widest possible set of resolvable SIDs to cycle through.
        $allSidPool  = @($groupSidPool) + @($userSidPool) | Select-Object -Unique
        $allNamePool = @($groupNamePool) + @($userNamePool) | Select-Object -Unique

        if ($MembersPerGroupMax -gt $userSidPool.Count -or $RestrictedGroupCount -gt $allSidPool.Count) {
            Write-Warning ("SID pools are smaller than requested scale (users=$($userSidPool.Count), " +
                "groups=$($groupSidPool.Count)).  SIDs will be recycled.  Increase -SampleCount " +
                "for more unique resolvable SIDs.")
        }

        # Remove prior scaled test entries matching any SID in the current pool
        # but protect original entries that pre-existed in the GPO backup
        $poolEscaped = ($allSidPool | ForEach-Object { [regex]::Escape($_) }) -join '|'
        $sections[$gmSection] = [System.Collections.Generic.List[string]](
            $sections[$gmSection] | Where-Object {
                if ($_ -match '^\*(S[-\d]+)__Members' -and $originalGmSids.Contains($Matches[1])) {
                    return $true  # protect original entries
                }
                -not ($_ -match "^\*($poolEscaped)__Members")
            }
        )

        Write-Host "  Generating $RestrictedGroupCount restricted groups ($MembersPerGroupMin-$MembersPerGroupMax members each)..." -ForegroundColor Cyan
        for ($g = 0; $g -lt $RestrictedGroupCount; $g++) {
            # Cycle through real group/user SIDs so every SID resolves in AD
            $groupSid = $allSidPool[$g % $allSidPool.Count]

            # Random member count within the configured range
            $memberCount = Get-Random -Minimum $MembersPerGroupMin -Maximum ($MembersPerGroupMax + 1)

            # Cycle through real user SIDs for members
            $memberSidList = [System.Collections.Generic.List[string]]::new()
            # Shuffle start offset per group so member lists vary between groups
            $memberOffset = $g * 3
            for ($m = 0; $m -lt $memberCount; $m++) {
                $idx = ($memberOffset + $m) % $userSidPool.Count
                $memberSidList.Add((Format-InfSid $userSidPool[$idx]))
            }

            $sections[$gmSection].Add("*$groupSid`__Members = $($memberSidList -join ',')")
        }
        $sections[$gmSection].Add($testDataEndMarker)
        Write-Verbose "  Added $RestrictedGroupCount scaled restricted groups to [Group Membership]"
    }
    else {
        # Close the marker block when no scaled groups are added
        $sections[$gmSection].Add($testDataEndMarker)
    }

    # --- Reassemble INF ---
    $outputLines = [System.Collections.Generic.List[string]]::new()
    foreach ($key in $sections.Keys) {
        if ($key -ne '__header__') {
            $outputLines.Add("[$key]")
        }
        foreach ($line in $sections[$key]) {
            # Skip marker comment lines - Import-GPO cannot parse ; comments in INF
            if ($line -eq $testDataBeginMarker -or $line -eq $testDataEndMarker) {
                continue
            }
            $outputLines.Add($line)
        }
    }

    $newInfText = $outputLines -join "`r`n"

    if ($PSCmdlet.ShouldProcess($infPath, 'Write enriched GptTmpl.inf')) {
        [System.IO.File]::WriteAllBytes($infPath, $encoding.GetBytes($newInfText))
        Write-Host "  Written: $infPath" -ForegroundColor Green
    }
}
#endregion

#region --- 3. Enrich GPP XML files ---
if ($gppTargetGuid) {
    $prefsRoot = Get-ChildItem -Path $gppTargetGuid.FullName -Recurse -Directory -Filter 'Preferences' | Select-Object -First 1
    $machineRoot = $prefsRoot.FullName

    # --- 3a. Groups.xml: add additional Group with multiple members ---
    $groupsDir  = Join-Path $machineRoot 'Groups'
    $groupsFile = Join-Path $groupsDir 'Groups.xml'

    if (Test-Path $groupsFile) {
        Write-Host "Enriching GPP: $groupsFile" -ForegroundColor Cyan
        [xml]$groupsXml = Get-Content -Path $groupsFile -Raw

        # Remove any prior test group element
        $existingTest = $groupsXml.Groups.Group | Where-Object { $_.name -eq 'TestSidGroup' }
        if ($existingTest) {
            [void]$groupsXml.Groups.RemoveChild($existingTest)
        }

        # Create new Group element with multiple domain-SID members
        $newGroup = $groupsXml.CreateElement('Group')
        $newGroup.SetAttribute('clsid', '{6D4A79E4-529C-4481-ABD0-F5BD7EA93BA7}')
        $newGroup.SetAttribute('name', 'TestSidGroup')
        $newGroup.SetAttribute('image', '2')
        $newGroup.SetAttribute('changed', (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        $newGroup.SetAttribute('uid', '{A1B2C3D4-E5F6-7890-ABCD-EF0123456789}')

        $props = $groupsXml.CreateElement('Properties')
        $props.SetAttribute('action', 'U')
        $props.SetAttribute('newName', '')
        $props.SetAttribute('description', 'Test group for SID-list coverage')
        $props.SetAttribute('deleteAllUsers', '0')
        $props.SetAttribute('deleteAllGroups', '0')
        $props.SetAttribute('removeAccounts', '0')
        $props.SetAttribute('groupSid', $groupSidPool[0])
        $props.SetAttribute('groupName', 'TestSidGroup')

        $members = $groupsXml.CreateElement('Members')
        # Add up to 5 user SIDs as members (or all available)
        $grpMemberCount = [math]::Min(5, $userSidPool.Count)
        for ($i = 0; $i -lt $grpMemberCount; $i++) {
            $member = $groupsXml.CreateElement('Member')
            $member.SetAttribute('name', $userNamePool[$i])
            $member.SetAttribute('action', 'ADD')
            $member.SetAttribute('sid', $userSidPool[$i])
            [void]$members.AppendChild($member)
        }
        [void]$props.AppendChild($members)
        [void]$newGroup.AppendChild($props)
        [void]$groupsXml.Groups.AppendChild($newGroup)

        # --- Scaled GPP restricted groups ---
        if ($RestrictedGroupCount -gt 0) {
            Write-Host "  Generating $RestrictedGroupCount GPP restricted groups ($MembersPerGroupMin-$MembersPerGroupMax members each)..." -ForegroundColor Cyan
            # Remove any prior scaled test groups (TestSidGroupNNN)
            $existingScaled = $groupsXml.Groups.Group | Where-Object { $_.name -match '^TestSidGroup\d+$' }
            foreach ($node in $existingScaled) {
                [void]$groupsXml.Groups.RemoveChild($node)
            }

            # Combine pools for group SIDs
            $allSidPool  = @($groupSidPool) + @($userSidPool) | Select-Object -Unique
            $allNamePool = @($groupNamePool) + @($userNamePool) | Select-Object -Unique

            for ($g = 0; $g -lt $RestrictedGroupCount; $g++) {
                # Cycle through real SIDs so every SID resolves in AD
                $gppGroupSid  = $allSidPool[$g % $allSidPool.Count]
                $gppGroupName = "TestSidGroup$g"
                $gppUid = [guid]::NewGuid().ToString('B').ToUpperInvariant()

                $scaledGroup = $groupsXml.CreateElement('Group')
                $scaledGroup.SetAttribute('clsid', '{6D4A79E4-529C-4481-ABD0-F5BD7EA93BA7}')
                $scaledGroup.SetAttribute('name', $gppGroupName)
                $scaledGroup.SetAttribute('image', '2')
                $scaledGroup.SetAttribute('changed', (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
                $scaledGroup.SetAttribute('uid', $gppUid)

                $scaledProps = $groupsXml.CreateElement('Properties')
                $scaledProps.SetAttribute('action', 'U')
                $scaledProps.SetAttribute('newName', '')
                $scaledProps.SetAttribute('description', "Scaled test group $g")
                $scaledProps.SetAttribute('deleteAllUsers', '0')
                $scaledProps.SetAttribute('deleteAllGroups', '0')
                $scaledProps.SetAttribute('removeAccounts', '0')
                $scaledProps.SetAttribute('groupSid', $gppGroupSid)
                $scaledProps.SetAttribute('groupName', $gppGroupName)

                $scaledMembers = $groupsXml.CreateElement('Members')
                $scaledMemberCount = Get-Random -Minimum $MembersPerGroupMin -Maximum ($MembersPerGroupMax + 1)

                # Shuffle start offset per group so member lists vary
                $memberOffset = $g * 3
                for ($m = 0; $m -lt $scaledMemberCount; $m++) {
                    $idx = ($memberOffset + $m) % $userSidPool.Count
                    $scaledMember = $groupsXml.CreateElement('Member')
                    $scaledMember.SetAttribute('name', $userNamePool[$idx])
                    $scaledMember.SetAttribute('sid', $userSidPool[$idx])
                    $scaledMember.SetAttribute('action', 'ADD')
                    [void]$scaledMembers.AppendChild($scaledMember)
                }

                [void]$scaledProps.AppendChild($scaledMembers)
                [void]$scaledGroup.AppendChild($scaledProps)
                [void]$groupsXml.Groups.AppendChild($scaledGroup)
            }
            Write-Verbose "  Added $RestrictedGroupCount scaled groups to Groups.xml"
        }

        if ($PSCmdlet.ShouldProcess($groupsFile, 'Write enriched Groups.xml')) {
            $groupsXml.Save($groupsFile)
            Write-Host "  Written: $groupsFile" -ForegroundColor Green
        }
    }

    # --- 3b. ScheduledTasks.xml: replace with TaskV2 containing <UserId> SID ---
    $stDir  = Join-Path $machineRoot 'ScheduledTasks'
    $stFile = Join-Path $stDir 'ScheduledTasks.xml'

    if (Test-Path $stFile) {
        Write-Host "Enriching GPP: $stFile" -ForegroundColor Cyan

        # Load existing XML
        [xml]$stXml = Get-Content -Path $stFile -Raw

        # Remove any prior TaskV2 test element
        $existingTaskV2 = $stXml.SelectNodes('//TaskV2[@name="TestSidTask"]')
        foreach ($node in $existingTaskV2) {
            [void]$node.ParentNode.RemoveChild($node)
        }

        # Build TaskV2 element manually (GPP ScheduledTasks uses a specific schema)
        $taskUserSid = $userSidPool[0]
        $taskV2Fragment = @"
<TaskV2 clsid="{D76C28E1-2FBE-4a2f-9247-6FC2F94132BE}" name="TestSidTask" image="2" changed="$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" uid="{B2C3D4E5-F6A7-8901-BCDE-F01234567890}">
  <Properties action="U" name="TestSidTask" runAs="$taskUserSid" logonType="Password">
    <Task version="1.2">
      <Principals>
        <Principal id="Author">
          <UserId>$taskUserSid</UserId>
          <LogonType>Password</LogonType>
          <RunLevel>HighestAvailable</RunLevel>
        </Principal>
      </Principals>
      <Actions>
        <Exec>
          <Command>C:\Tools\test.exe</Command>
        </Exec>
      </Actions>
    </Task>
  </Properties>
</TaskV2>
"@
        $taskV2Node = $stXml.ImportNode(([xml]"<root>$taskV2Fragment</root>").DocumentElement.FirstChild, $true)
        [void]$stXml.ScheduledTasks.AppendChild($taskV2Node)

        if ($PSCmdlet.ShouldProcess($stFile, 'Write enriched ScheduledTasks.xml')) {
            $stXml.Save($stFile)
            Write-Host "  Written: $stFile" -ForegroundColor Green
        }
    }

    # --- 3c. Services.xml: add NTService with accountSid ---
    $svcDir  = Join-Path $machineRoot 'Services'
    $svcFile = Join-Path $svcDir 'Services.xml'

    if (Test-Path $svcFile) {
        Write-Host "Enriching GPP: $svcFile" -ForegroundColor Cyan
        [xml]$svcXml = Get-Content -Path $svcFile -Raw

        # Remove any prior test service
        $existingSvc = $svcXml.SelectNodes('//NTService[@name="TestSidSvc"]')
        foreach ($node in $existingSvc) {
            [void]$node.ParentNode.RemoveChild($node)
        }

        $svcUserSid  = if ($userSidPool.Count -gt 8) { $userSidPool[8] } else { $userSidPool[0] }
        $svcUserName = if ($userNamePool.Count -gt 8) { $userNamePool[8] } else { $userNamePool[0] }
        $svcFragment = @"
<NTService clsid="{AB6F0B67-341F-4e51-92F9-005FBFBA1A43}" name="TestSidSvc" image="3" changed="$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" uid="{C3D4E5F6-A7B8-9012-CDEF-012345678901}">
  <Properties startupType="AUTOMATIC" serviceName="TestSidSvc" timeout="30" accountName="$svcUserName" accountSid="$svcUserSid"/>
</NTService>
"@
        $svcNode = $svcXml.ImportNode(([xml]"<root>$svcFragment</root>").DocumentElement.FirstChild, $true)
        [void]$svcXml.NTServices.AppendChild($svcNode)

        if ($PSCmdlet.ShouldProcess($svcFile, 'Write enriched Services.xml')) {
            $svcXml.Save($svcFile)
            Write-Host "  Written: $svcFile" -ForegroundColor Green
        }
    }
}
#endregion

#region --- 4. Summary ---
Write-Host ''
Write-Host 'Test SID data enrichment complete.' -ForegroundColor Green
Write-Host "Domain SID: $DomainSid" -ForegroundColor Gray
Write-Host "Source:     $(if ($RidPool) { 'Explicit RidPool' } else { 'Active Directory query' })" -ForegroundColor Gray
if ($RestrictedGroupCount -gt 0) {
    Write-Host "Restricted groups: $RestrictedGroupCount ($MembersPerGroupMin-$MembersPerGroupMax members each)" -ForegroundColor Gray
}
Write-Host ''
Write-Host "User SIDs embedded ($($userSidPool.Count)):" -ForegroundColor Cyan
for ($i = 0; $i -lt $userSidPool.Count; $i++) {
    Write-Host "  $($userSidPool[$i])  ($($userNamePool[$i]))" -ForegroundColor Gray
}
Write-Host "Group SIDs embedded ($($groupSidPool.Count)):" -ForegroundColor Cyan
for ($i = 0; $i -lt $groupSidPool.Count; $i++) {
    Write-Host "  $($groupSidPool[$i])  ($($groupNamePool[$i]))" -ForegroundColor Gray
}
Write-Host ''
Write-Host 'Setting types covered:' -ForegroundColor Cyan
Write-Host '  INF  [Privilege Rights]         - multi-SID comma-separated list'
Write-Host '  INF  [Group Membership]          - __Members / __Memberof with domain SIDs'
Write-Host '  INF  [Service General Setting]   - SDDL with domain SID ACEs'
Write-Host '  INF  [File Security]             - SDDL with domain SID ACEs'
Write-Host '  INF  [Registry Keys]             - SDDL with domain SID ACEs'
Write-Host '  XML  Groups.xml                  - groupSid + multiple Member sids'
Write-Host '  XML  ScheduledTasks.xml          - TaskV2 with UserId SID'
Write-Host '  XML  Services.xml                - NTService with accountSid'
#endregion

<#
    .SYNOPSIS
        Imports Group Policy Objects from a backup folder.

    .DESCRIPTION
        Reads all GPO backup folders from the specified path, extracts the
        DisplayName from each Backup.xml, creates the GPO if it does not
        already exist, and then imports the settings using Import-GPO.

        By default the two built-in default policies ('Default Domain Policy'
        and 'Default Domain Controllers Policy') are skipped. Use the
        -IncludeDefaultPolicies switch to include them.

    .PARAMETER BackupPath
        The root folder that contains the GUID-named GPO backup sub-folders.
        Each sub-folder must contain a Backup.xml file.

    .PARAMETER ExcludeName
        One or more GPO display names to skip during import.

    .PARAMETER IncludeDefaultPolicies
        When specified, the default domain policies are included in the
        import instead of being skipped.

    .EXAMPLE
        .\Restore-GPOBackup.ps1 -BackupPath C:\GpoBackup

        Imports all GPO backups except the two default policies.

    .EXAMPLE
        .\Restore-GPOBackup.ps1 -BackupPath C:\GpoBackup -IncludeDefaultPolicies

        Imports all GPO backups including the default policies.

    .EXAMPLE
        .\Restore-GPOBackup.ps1 -BackupPath C:\GpoBackup -ExcludeName 'Printer', 'Settings1'

        Imports all non-default GPO backups, additionally skipping
        'Printer' and 'Settings1'.

    .INPUTS
        None. This script does not accept pipeline input.

    .OUTPUTS
        PSCustomObject with properties GpoName, BackupId, and Status for
        every backup folder processed.

    .NOTES
        Author:  Raimund Andree
        Date:    2026-02-24
        Version: 1.0.0

        Requires the GroupPolicy module (available on domain controllers
        or machines with RSAT installed).
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string]$BackupPath,

    [Parameter()]
    [string[]]$ExcludeName,

    [Parameter()]
    [switch]$IncludeDefaultPolicies
)

#Requires -Modules GroupPolicy

Set-StrictMode -Version Latest

$defaultPolicies = @(
    'Default Domain Policy'
    'Default Domain Controllers Policy'
)

$backupFolders = Get-ChildItem -Path $BackupPath -Directory

if ($backupFolders.Count -eq 0) {
    Write-Warning "No backup folders found in '$BackupPath'."
    return
}

Write-Verbose "Found $($backupFolders.Count) backup folder(s) in '$BackupPath'."

foreach ($folder in $backupFolders) {
    $backupXmlPath = Join-Path -Path $folder.FullName -ChildPath 'Backup.xml'

    if (-not (Test-Path -Path $backupXmlPath)) {
        Write-Warning "No Backup.xml found in '$($folder.FullName)', skipping."
        continue
    }

    # Parse the Backup.xml to extract the DisplayName
    [xml]$backupXml = Get-Content -Path $backupXmlPath -Raw
    $namespaceManager = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList $backupXml.NameTable
    $namespaceManager.AddNamespace('gpo', 'http://www.microsoft.com/GroupPolicy/GPOOperations')

    $xpathDisplayName = '//gpo:GroupPolicyBackupScheme/gpo:GroupPolicyObject/gpo:GroupPolicyCoreSettings/gpo:DisplayName'
    $displayNameNode = $backupXml.SelectSingleNode($xpathDisplayName, $namespaceManager)

    if (-not $displayNameNode) {
        Write-Warning "Could not find DisplayName in '$backupXmlPath', skipping."
        continue
    }

    $gpoName = $displayNameNode.InnerText
    $backupId = $folder.Name.Trim('{}')

    # Check exclusions
    if (-not $IncludeDefaultPolicies -and $gpoName -in $defaultPolicies) {
        Write-Verbose "Skipping default policy: $gpoName"
        [PSCustomObject]@{
            GpoName  = $gpoName
            BackupId = $backupId
            Status   = 'Skipped (Default Policy)'
        }
        continue
    }

    if ($ExcludeName -and $gpoName -in $ExcludeName) {
        Write-Verbose "Skipping excluded GPO: $gpoName"
        [PSCustomObject]@{
            GpoName  = $gpoName
            BackupId = $backupId
            Status   = 'Skipped (Excluded)'
        }
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($gpoName, 'Create and import GPO from backup')) {
        continue
    }

    $status = 'Imported'

    try {
        $existingGpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue

        if ($existingGpo) {
            Write-Verbose "GPO '$gpoName' already exists, importing settings."
            $status = 'Updated (already existed)'
        } else {
            New-GPO -Name $gpoName -ErrorAction Stop | Out-Null
            Write-Verbose "Created GPO: $gpoName"
            $status = 'Created and imported'
        }

        $importSplat = @{
            BackupId    = $backupId
            Path        = $BackupPath
            TargetName  = $gpoName
            ErrorAction = 'Stop'
        }
        Import-GPO @importSplat | Out-Null

        Write-Verbose "Imported settings for: $gpoName"
    } catch {
        Write-Error "Failed to process GPO '$gpoName': $_"
        $status = "Failed: $_"
    }

    [PSCustomObject]@{
        GpoName  = $gpoName
        BackupId = $backupId
        Status   = $status
    }
}

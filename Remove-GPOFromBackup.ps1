<#
    .SYNOPSIS
        Removes Group Policy Objects from the current domain that have a
        corresponding backup in the specified folder.

    .DESCRIPTION
        Reads all GPO backup folders from the specified path, extracts the
        DisplayName from each Backup.xml, and removes the matching GPO from
        Active Directory if it exists.

        This is the inverse of Restore-GPOBackup.ps1 and is useful for
        cleaning up GPOs before a fresh import.

        By default the two built-in default policies ('Default Domain Policy'
        and 'Default Domain Controllers Policy') are never removed.  Use the
        -IncludeDefaultPolicies switch to include them.

    .PARAMETER BackupPath
        The root folder that contains the GUID-named GPO backup sub-folders.
        Each sub-folder must contain a Backup.xml file.

    .PARAMETER ExcludeName
        One or more GPO display names to skip during removal.

    .PARAMETER IncludeDefaultPolicies
        When specified, the default domain policies are included in the
        removal instead of being skipped.

    .EXAMPLE
        .\Remove-GPOFromBackup.ps1 -BackupPath C:\GpoBackup

        Removes all GPOs whose names match a backup, except the two
        default policies.

    .EXAMPLE
        .\Remove-GPOFromBackup.ps1 -BackupPath C:\GpoBackup -WhatIf

        Shows which GPOs would be removed without making changes.

    .EXAMPLE
        .\Remove-GPOFromBackup.ps1 -BackupPath C:\GpoBackup -ExcludeName 'Printer'

        Removes all matching GPOs except the default policies and 'Printer'.

    .INPUTS
        None.  This script does not accept pipeline input.

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

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
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

    $gpoName  = $displayNameNode.InnerText
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

    # Check whether the GPO exists in the domain
    $existingGpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue

    if (-not $existingGpo) {
        Write-Verbose "GPO '$gpoName' does not exist in the domain, nothing to remove."
        [PSCustomObject]@{
            GpoName  = $gpoName
            BackupId = $backupId
            Status   = 'Not found'
        }
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($gpoName, 'Remove GPO from domain')) {
        continue
    }

    $status = 'Removed'

    try {
        Remove-GPO -Name $gpoName -ErrorAction Stop
        Write-Verbose "Removed GPO: $gpoName"
    } catch {
        Write-Error "Failed to remove GPO '$gpoName': $_"
        $status = "Failed: $_"
    }

    [PSCustomObject]@{
        GpoName  = $gpoName
        BackupId = $backupId
        Status   = $status
    }
}

#Enhanced PowerShell Script for Shared Folder Inventory with Last Modified Date
<#
.SYNOPSIS
    Gathers comprehensive shared folder information including last modified dates for SharePoint Online migration.
.DESCRIPTION
    This enhanced script collects shared folder details including:
    - Folder paths and owners
    - Security group permissions (read/write)
    - Last accessed dates
    - Last modified dates
    - Folder sizes
    - File/folder counts
.NOTES
    Version: 2.0
    Author: Your Name
    Requires: Administrative privileges on file servers
#>

# Import required module
Import-Module NTFSSecurity -ErrorAction SilentlyContinue
if (-not (Get-Module -Name NTFSSecurity)) {
    Write-Warning "NTFSSecurity module not found. Installing..."
    Install-Module -Name NTFSSecurity -Force -Scope CurrentUser
    Import-Module NTFSSecurity
}

# Configuration
$OutputFile = "SharedFolderInventory_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
$FileServers = @("Server1", "Server2") # Replace with your file server names
$ExcludedShares = @("NETLOGON", "SYSVOL", "print$") # Shares to exclude
$SharePaths = @()

# Function to get folder size and statistics
function Get-FolderStats {
    param (
        [string]$folder,
        [switch]$IncludeSubfolders = $true
    )
    
    $items = if ($IncludeSubfolders) {
        Get-ChildItem $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Get-ChildItem $folder -Force -ErrorAction SilentlyContinue
    }
    
    $stats = @{
        SizeGB       = [math]::Round(($items | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
        LastAccess   = ($items | Sort-Object LastAccessTime -Descending | Select-Object -First 1).LastAccessTime
        LastModified = ($items | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
        FileCount    = ($items | Where-Object { -not $_.PSIsContainer }).Count
        FolderCount  = ($items | Where-Object { $_.PSIsContainer }).Count
    }
    
    return $stats
}

# Get all shared folders from specified servers
foreach ($server in $FileServers) {
    try {
        $shares = Get-SmbShare -CimSession $server -ErrorAction Stop | 
        Where-Object { $_.Path -and $_.ShareType -eq "FileSystemDirectory" -and $_.Name -notin $ExcludedShares }
        
        $SharePaths += $shares | ForEach-Object { 
            [PSCustomObject]@{
                UNC       = Join-Path "\\$server" $_.Name
                LocalPath = $_.Path
            }
        }
    }
    catch {
        Write-Warning "Failed to get shares from $server : $_"
    }
}

# Process each shared folder
$results = [System.Collections.Generic.List[PSObject]]::new()
$totalShares = $SharePaths.Count
$currentShare = 0

foreach ($share in $SharePaths) {
    $currentShare++
    $percentComplete = ($currentShare / $totalShares) * 100
    Write-Progress -Activity "Processing shares" -Status "$currentShare/$totalShares - $($share.UNC)" -PercentComplete $percentComplete
    
    try {
        # Get basic info
        $folderInfo = Get-Item $share.LocalPath -ErrorAction Stop
        $owner = (Get-Acl $share.LocalPath).Owner
        
        # Get permissions
        $permissions = Get-NTFSAccess -Path $share.LocalPath -ErrorAction Stop | 
        Where-Object { $_.AccountType -eq "Group" -and $_.IsInherited -eq $false }
        
        $readGroups = ($permissions | Where-Object { $_.AccessRights -match "Read" -and $_.AccessControlType -eq "Allow" }).AccountName -join ", "
        $writeGroups = ($permissions | Where-Object { ($_.AccessRights -match "Modify|FullControl|Write") -and $_.AccessControlType -eq "Allow" }).AccountName -join ", "
        
        # Get folder statistics
        $stats = Get-FolderStats -folder $share.LocalPath
        
        # Create output object
        $result = [PSCustomObject]@{
            "FolderPath"      = $share.UNC
            "LocalPath"       = $share.LocalPath
            "Owner"           = $owner
            "ReadGroups"      = $readGroups
            "WriteGroups"     = $writeGroups
            "LastAccessed"    = $stats.LastAccess
            "LastModified"    = $stats.LastModified
            "SizeGB"          = $stats.SizeGB
            "FileCount"       = $stats.FileCount
            "FolderCount"     = $stats.FolderCount
            "DaysSinceMod"    = if ($stats.LastModified) { [math]::Floor((Get-Date) - $stats.LastModified).TotalDays } else { $null }
            "DaysSinceAccess" = if ($stats.LastAccess) { [math]::Floor((Get-Date) - $stats.LastAccess).TotalDays } else { $null }
        }
        
        $results.Add($result)
    }
    catch {
        Write-Warning "Error processing $($share.UNC) : $_"
        # Add record with error information
        $results.Add([PSCustomObject]@{
                "FolderPath"      = $share.UNC
                "LocalPath"       = $share.LocalPath
                "Owner"           = "ERROR"
                "ReadGroups"      = "ERROR"
                "WriteGroups"     = "ERROR"
                "LastAccessed"    = $null
                "LastModified"    = $null
                "SizeGB"          = $null
                "FileCount"       = $null
                "FolderCount"     = $null
                "DaysSinceMod"    = $null
                "DaysSinceAccess" = $null
                "Error"           = $_.Exception.Message
            })
    }
}

# Export results
$results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
Write-Host "Inventory completed. Results saved to $OutputFile" -ForegroundColor Green

# Generate summary report
$summary = @"
Shared Folder Inventory Report
=============================

Generated on: $(Get-Date)
Total shares scanned: $totalShares
Successfully processed: $($results | Where-Object { -not $_.Error }).Count
Failed to process: $($results | Where-Object { $_.Error }).Count

Size Statistics:
Total Size: $([math]::Round(($results | Measure-Object -Property SizeGB -Sum).Sum, 2)) GB
Average Size: $([math]::Round(($results | Measure-Object -Property SizeGB -Average).Average, 2)) GB
Largest Share: $($results | Sort-Object SizeGB -Descending | Select-Object -First 1 | ForEach-Object { "$($_.FolderPath) ($($_.SizeGB) GB)" })

Activity Statistics:
Most recently modified: $($results | Sort-Object LastModified -Descending | Select-Object -First 1 | ForEach-Object { "$($_.FolderPath) ($($_.LastModified))" })
Oldest modification: $($results | Where-Object { $_.LastModified } | Sort-Object LastModified | Select-Object -First 1 | ForEach-Object { "$($_.FolderPath) ($($_.LastModified))" })
"@

$summary | Out-File -FilePath "ShareInventory_Summary_$(Get-Date -Format 'yyyyMMdd').txt"
Write-Host "Summary report generated." -ForegroundColor Cyan

# Display top 10 largest shares
$results | Sort-Object SizeGB -Descending | Select-Object -First 10 | 
Format-Table FolderPath, SizeGB, LastModified, DaysSinceMod -AutoSize

# Display shares not modified in over 1 year
$oldShares = $results | Where-Object { $_.DaysSinceMod -gt 365 } | Sort-Object DaysSinceMod -Descending
if ($oldShares) {
    Write-Host "`nShares not modified in over 1 year:" -ForegroundColor Yellow
    $oldShares | Format-Table FolderPath, LastModified, DaysSinceMod, SizeGB -AutoSize
}
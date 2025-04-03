<#
.SYNOPSIS
    Gathers shared folder information for SharePoint Online migration planning.
.DESCRIPTION
    This script collects shared folder details including permissions, owners, last access times, and sizes.
    Output is saved to CSV for analysis and migration planning.
.NOTES
    Version: 1.0
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
$OutputFile = "SharedFolderInventory_$(Get-Date -Format 'yyyyMMdd').csv"
$FileServers = @("Server1", "Server2") # Replace with your file server names
$SharePaths = @() # Will be populated with all shared folders

# Function to get folder size
function Get-FolderSize {
    param ([string]$folder)
    $size = (Get-ChildItem $folder -Recurse -Force -ErrorAction SilentlyContinue | 
        Measure-Object -Property Length -Sum).Sum
    return [math]::Round($size / 1GB, 2)
}

# Function to get last access time
function Get-LastAccessTime {
    param ([string]$folder)
    $lastAccess = (Get-ChildItem $folder -Recurse -Force -ErrorAction SilentlyContinue | 
        Sort-Object LastAccessTime -Descending | 
        Select-Object -First 1).LastAccessTime
    return $lastAccess
}

# Get all shared folders from specified servers
foreach ($server in $FileServers) {
    try {
        $shares = Get-SmbShare -CimSession $server -ErrorAction Stop | Where-Object { $_.Path -and $_.ShareType -eq "FileSystemDirectory" }
        $SharePaths += $shares | ForEach-Object { Join-Path "\\$server" $_.Name }
    }
    catch {
        Write-Warning "Failed to get shares from $server : $_"
    }
}

# Process each shared folder
$results = @()
foreach ($share in $SharePaths) {
    try {
        Write-Progress -Activity "Processing shares" -Status $share -PercentComplete (($SharePaths.IndexOf($share) / $SharePaths.Count * 100)
        
            # Get basic info
            $folderInfo = Get-Item $share -ErrorAction Stop
            $owner = (Get-Acl $share).Owner
        
            # Get permissions
            $permissions = Get-NTFSAccess -Path $share -ErrorAction Stop | 
            Where-Object { $_.AccountType -eq "Group" -and $_.IsInherited -eq $false }
        
            $readGroups = ($permissions | Where-Object { $_.AccessRights -match "Read" -and $_.AccessControlType -eq "Allow" }).AccountName -join ", "
            $writeGroups = ($permissions | Where-Object { ($_.AccessRights -match "Modify|FullControl|Write") -and $_.AccessControlType -eq "Allow" }).AccountName -join ", "
        
            # Get last access and size
            $lastAccess = Get-LastAccessTime -folder $share
            $sizeGB = Get-FolderSize -folder $share
        
            # Create output object
            $result = [PSCustomObject]@{
                "FolderPath"   = $share
                "Owner"        = $owner
                "ReadGroups"   = $readGroups
                "WriteGroups"  = $writeGroups
                "LastAccessed" = $lastAccess
                "SizeGB"       = $sizeGB
                "ItemCount"    = (Get-ChildItem $share -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object).Count
            }
        
            $results += $result
        }
        catch {
            Write-Warning "Error processing $share : $_"
        }
    }

    # Export results
    $results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
    Write-Host "Inventory completed. Results saved to $OutputFile" -ForegroundColor Green

    # Optional: Display summary
    $results | Format-Table -AutoSize
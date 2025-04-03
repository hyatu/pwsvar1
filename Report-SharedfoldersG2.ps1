<#
.SYNOPSIS
Generates a CSV report of shared folders, indicating if they have been accessed
in the last 5 years, along with security group access (Read/Write),
last modified date, last access date, and owners.

.DESCRIPTION
This script will iterate through the specified shared folders on a local or
remote server and gather information about their NTFS permissions, last
modified date, last access date, and owners. It will also determine if the
folder has been accessed in the last 5 years. The output will be a CSV file
containing this information.

.PARAMETER ServerName
The name of the server hosting the shared folders. Defaults to the local machine.

.PARAMETER SharedFolderPaths
An array of the full paths to the shared folders you want to report on.

.PARAMETER OutputCSVPath
The full path to the CSV file where the report will be saved.

.NOTES
- This script requires administrator privileges to access security information.
- The "Last Access Time" may not be reliably tracked depending on the server's configuration.
- The owner information is retrieved from the file system object.
- Security group names are resolved using Active Directory (if the server is domain-joined).
- The 5-year inactivity period is calculated based on the current date when the script runs.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ServerName = '.',

    [Parameter(Mandatory = $true)]
    [string[]]$SharedFolderPaths,

    [Parameter(Mandatory = $true)]
    [string]$OutputCSVPath
)

# Define the inactivity threshold (5 years ago)
$InactivityThreshold = (Get-Date).AddYears(-5)

# Function to get NTFS security information for a given folder
function Get-NTFSAccess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )
    $ACL = Get-Acl -Path $FolderPath
    $AccessRules = $ACL.Access | Where-Object { $_.IdentityReference -like "*\\*" } # Filter for domain/local users/groups

    $ReadGroups = @()
    $WriteGroups = @()

    foreach ($Rule in $AccessRules) {
        $Identity = $Rule.IdentityReference.ToString()

        # Check for Read access
        if (($Rule.FileSystemRights -contains "Read") -or ($Rule.FileSystemRights -contains "ReadAndExecute") -or ($Rule.FileSystemRights -contains "ListDirectory")) {
            if ($Rule.AccessControlType -eq "Allow") {
                $ReadGroups += $Identity
            }
        }

        # Check for Write access
        if (($Rule.FileSystemRights -contains "Write") -or ($Rule.FileSystemRights -contains "Modify") -or ($Rule.FileSystemRights -contains "FullControl")) {
            if ($Rule.AccessControlType -eq "Allow") {
                $WriteGroups += $Identity
            }
        }
    }

    return @{
        ReadAccessGroups  = ($ReadGroups | Sort-Object -Unique) -join ";"
        WriteAccessGroups = ($WriteGroups | Sort-Object -Unique) -join ";"
    }
}

# Array to store the report data
$ReportData = @()

# Iterate through each specified shared folder path
foreach ($Path in $SharedFolderPaths) {
    try {
        # Ensure the path exists
        if (-not (Test-Path -Path $Path -PathType Container)) {
            Write-Warning "Shared folder '$Path' not found."
            continue
        }

        # Get basic file system information
        $FolderInfo = Get-Item -Path $Path

        # Get NTFS access information
        $NTFSAccess = Get-NTFSAccess -FolderPath $Path

        # Get owner information
        $Owner = $FolderInfo.GetAccessControl().Owner

        # Determine if the folder has been accessed in the last 5 years
        $LastAccess = $FolderInfo.LastAccessTime
        $IsActive = ($LastAccess -gt $InactivityThreshold)

        # Create a custom object for the report
        $ReportObject = [PSCustomObject]@{
            "Shared Folder Path"     = $Path
            "Active in Last 5 Years" = $IsActive
            "Read Access Groups"     = $NTFSAccess.ReadAccessGroups
            "Write Access Groups"    = $NTFSAccess.WriteAccessGroups
            "Last Modified Date"     = $FolderInfo.LastWriteTime
            "Last Access Date"       = $LastAccess
            "Owner"                  = $Owner
        }

        # Add the object to the report data array
        $ReportData += $ReportObject

    }
    catch {
        Write-Error "Error processing shared folder '$Path': $($_.Exception.Message)"
    }
}

# Export the report data to a CSV file
if ($ReportData.Count -gt 0) {
    $ReportData | Export-Csv -Path $OutputCSVPath -NoTypeInformation
    Write-Host "Report generated successfully at '$OutputCSVPath'"
}
else {
    Write-Host "No shared folders were processed or found. No report generated."
}
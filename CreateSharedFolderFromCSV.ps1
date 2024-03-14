<#
Make sure to create a CSV file named folder_info.csv with the following headers:
FolderPath, GroupName, Permission, and GroupManager, and populate it with the necessary folder information.
 Adjust the column headers if necessary.
This script will iterate through each row in the CSV file, create the shared folder, set permissions for the specified security group,
disable inheritance from the parent folder, and add the designated manager to the security group.

#>


# Read folder information from CSV file
$folders = Import-Csv -Path "folder_info.csv"

foreach ($folderInfo in $folders) {
    # Extract folder information from CSV
    $folderPath = $folderInfo.FolderPath
    $groupName = $folderInfo.GroupName
    $permission = $folderInfo.Permission
    $groupManager = $folderInfo.GroupManager

    # Create the folder if it doesn't exist
    if (!(Test-Path -Path $folderPath)) {
        New-Item -Path $folderPath -ItemType Directory
    }

    # Define Access Control List (ACL) for the group
    $acl = Get-Acl -Path $folderPath
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($groupName, $permission, "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($accessRule)

    # Set the ACL to the folder
    Set-Acl -Path $folderPath -AclObject $acl

    # Disable inheritance from the parent folder
    $acl.SetAccessRuleProtection($true, $false)

    # Apply the modified ACL to the folder
    Set-Acl -Path $folderPath -AclObject $acl

    # Add manager to the group
    Add-ADGroupMember -Identity $groupName -Members $groupManager

    Write-Host "Shared folder $($folderInfo.FolderName) created with appropriate permissions."
}

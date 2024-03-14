<#
This script will generate a CSV file containing the folder name, group, and permissions for each folder listed in the input CSV file. 
Make sure to replace "C:\path\to\output\folder_permissions_report.csv" with the desired output file path.
#>

# Define the path to the CSV file containing folder names
$csvFilePath = "C:\path\to\your\csvfile.csv"

# Define the path to the output CSV file
$outputCsvFilePath = "C:\path\to\output\folder_permissions_report.csv"

# Read the CSV file
$folders = Import-Csv -Path $csvFilePath

# Initialize an array to store results
$results = @()

# Loop through each folder in the CSV
foreach ($folder in $folders) {
    # Get the ACL (Access Control List) of the folder
    $acl = Get-Acl -Path $folder.FolderPath

    # Get the Access rules for the folder
    $accessRules = $acl.Access

    # Loop through each access rule
    foreach ($rule in $accessRules) {
        # Check if the rule applies to a group
        if ($rule.IdentityReference -like "BUILTIN\*" -or $rule.IdentityReference -like "NT AUTHORITY\*") {
            # Create an object to store folder name, group, and permissions
            $result = [PSCustomObject]@{
                FolderName = $folder.FolderName
                Group = $rule.IdentityReference
                Permissions = $rule.FileSystemRights
            }

            # Add the result object to the results array
            $results += $result
        }
    }
}

# Export results to CSV file
$results | Export-Csv -Path $outputCsvFilePath -NoTypeInformation

Write-Host "Folder permissions report exported to: $outputCsvFilePath"

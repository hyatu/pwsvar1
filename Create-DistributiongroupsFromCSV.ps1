# Import Exchange PowerShell module
Import-Module Exchange

# Path to the CSV file
$csvFilePath = "C:\path\to\your\csv\file.csv"

# Database name for the distribution group
$database = "YourDatabaseName"

# Import CSV file
$groupsData = Import-Csv $csvFilePath

# Loop through each row in the CSV file
foreach ($group in $groupsData) {
    # Extracting data from CSV
    $name = $group.Name
    $alias = $group.Alias
    $manageBy = $group.ManageBy
    $organizationalUnit = $group.OrganizationUnit
    $displayName = $group.DisplayName
    $description = $group.Description

    # Create the new distribution group with universal scope
    New-DistributionGroup -Name $name -Alias $alias -ManagedBy $manageBy -OrganizationalUnit $organizationalUnit -DisplayName $displayName -Type "Distribution" -Description $description -Database $database -Scope "Universal"
}

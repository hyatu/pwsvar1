# Path to the text file containing the list of groups (each group name on a new line)
$groupsFilePath = "C:\Path\to\groups.txt"

# Output CSV file path
$outputCsvFilePath = "C:\Path\to\output.csv"

# Read the list of groups from the text file
$groups = Get-Content -Path $groupsFilePath

# Create an empty array to store group information
$groupInfoArray = @()

foreach ($group in $groups) {
    $groupInfo = Get-ADGroup -Identity $group -Properties Description, ManagedBy, Members, DistinguishedName, GroupCategory, GroupScope, ObjectGUID, WhenCreated
    $description = $groupInfo.Description
    $managedBy = $groupInfo.ManagedBy
    $directMembers = Get-ADGroupMember -Identity $group | Select-Object -ExpandProperty Name
    $distinguishedName = $groupInfo.DistinguishedName
    $groupCategory = $groupInfo.GroupCategory
    $groupScope = $groupInfo.GroupScope
    $objectGUID = $groupInfo.ObjectGUID
    $whenCreated = $groupInfo.WhenCreated
    $numberOfMembers = ($groupInfo.Members).Count
    
    # Create a custom object to store group information
    $groupObject = [PSCustomObject]@{
        Group = $group
        Description = $description
        ManagedBy = $managedBy
        DirectMembers = $directMembers -join ', '
        DistinguishedName = $distinguishedName
        GroupCategory = $groupCategory
        GroupScope = $groupScope
        ObjectGUID = $objectGUID
        WhenCreated = $whenCreated
        NumberOfMembers = $numberOfMembers
    }

    # Add the custom object to the array
    $groupInfoArray += $groupObject
}

# Export the group information to a CSV file
$groupInfoArray | Export-Csv -Path $outputCsvFilePath -NoTypeInformation

# Function to create shared mailbox from CSV file
function Create-SharedMailboxFromCSV {
    param (
        [string]$CSVFilePath
    )

    # Read CSV file
    $sharedMailboxes = Import-Csv $CSVFilePath

    foreach ($mailbox in $sharedMailboxes) {
        $MailboxName = $mailbox.Name
        $MailboxAlias = $MailboxName
        $SecurityGroupName = "$MailboxName Security Group"
        $Database = "MailboxDatabaseName" # Replace with actual database name
        $EmailAddress = "$MailboxName@example.com"
        $GroupDisplayName = "$MailboxName Access Group"

        # Create shared mailbox
        New-Mailbox -Shared -Name $MailboxName -Alias $MailboxAlias -Database $Database -EmailAddress $EmailAddress

        # Create security group
        New-DistributionGroup -Name $SecurityGroupName -Type Security

        # Add permissions to the security group for the shared mailbox
        Add-MailboxPermission -Identity $MailboxName -User $SecurityGroupName -AccessRights FullAccess

        # Optionally, add members to the security group for accessing the shared mailbox
        # Add-DistributionGroupMember -Identity $SecurityGroupName -Member "user1", "user2", "user3"

        # Set the group display name for the security group
        Set-DistributionGroup -Identity $SecurityGroupName -DisplayName $GroupDisplayName
    }
}

# Usage example
$CSVFilePath = "C:\path\to\your\csvfile.csv"
Create-SharedMailboxFromCSV -CSVFilePath $CSVFilePath

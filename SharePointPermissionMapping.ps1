# Add after export
# SharePoint Permission Mapping
$SPOMapping = $results | Select-Object FolderPath, Owner, ReadGroups, WriteGroups,
@{Name = "SPOSite"; Expression = { 
        if ($_.FolderPath -match "Finance") { "https://tenant.sharepoint.com/sites/finance" }
        elseif ($_.FolderPath -match "HR") { "https://tenant.sharepoint.com/sites/hr" }
        else { "https://tenant.sharepoint.com/sites/general" }
    }
}
$SPOMapping | Export-Csv -Path "SPO_Permission_Mapping.csv" -NoTypeInformation
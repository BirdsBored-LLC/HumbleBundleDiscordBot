# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host 'PowerShell timer is running late!'
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

Import-Module Az.Storage
Import-Module Az.Resources
import-module AzTable 

$storageAccountName = 'birdsboredstorageaccount'
$storagekey = $env:storagekey

$webHooksTable=Get-AzStorageTable -Name 'webhookRegistration' -Context (New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storagekey)
$sentMessagesTable=Get-AzStorageTable -Name 'sentMessagesTable' -Context (New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storagekey)
$humbleBundleTable=Get-AzStorageTable -Name 'humbleBundles' -Context (New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storagekey)

$cloudwebhooksTable = $webHooksTable.CloudTable
$cloudsentMessagesTable = $sentMessagesTable.CloudTable
$cloudhumbleBundleTable = $humbleBundleTable.CloudTable

$bundles = Get-AzTableRow -table $cloudhumbleBundleTable

$enc = [System.Text.Encoding]::UTF8

foreach($bundle in $bundles){
    $bundleRowKey = $enc.GetChars($bundle.rowkey.split(" ")) -join ''
    $hookstosend = @()
    Get-AzTableRow -table $cloudwebhooksTable -customfilter "PartitionKey eq '$($bundle.PartitionKey)' and shouldUpdate eq true" | ForEach-Object {
        $hookstosend+=$enc.GetChars($_.webhook.split(" ")) -join ''
    }
    $payload = @"
{
    "content" : "$("New $($bundle.PartitionKey.toString().ToLower()) Bundle! Ends " + (get-date $bundle.end_date).ToShortDateString() + " " + (get-date $bundle.end_date).ToShortTimeString() )",
    "embeds" : [{
        "title" : "$($bundle.marketing_blurb -replace '<[^>]+>','')",
        "url" : "$($enc.GetChars($bundle.url.split(" ")) -join '')",
        "description" : "$($bundle.detailed_marketing_blurb -replace '<[^>]+>','')",
        "image" : {
            "url" : "$($bundle.tile_image)"
        },
        "author" : {
            "name" : "Humble Bundle",
            "url" : "https://humblebundle.com?partner=birdsbored"
        },
        "footer" : {
            "text" : "Powered By https://BirdsBored.com and Azure Functions",
            "icon_url" : "https://birdsbored.com/assets/img/favicon.ico"
        }
    }],
    "timestamp" : "$((get-date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))"
}
"@

    foreach($hook in $hookstosend){
        $sentRowKey = $enc.GetBytes($bundleRowKey.tostring() + $hook.tostring()) -join ' '
        if(!(Get-AzTableRow -table $cloudsentMessagesTable -PartitionKey $bundle.PartitionKey -RowKey $sentRowKey)){
            $discordmessage = Invoke-RestMethod -Uri $($hook+"?wait=true") -Method Post -ContentType "application/json" -Body $payload
            Push-OutputBinding -Name outSentMessagesTable -Value @{
                PartitionKey=$bundle.PartitionKey
                RowKey=$sentRowKey
                webhook=$hook
                messageid=$discordmessage.id
                bundleRowKey=$bundleRowKey
            }
            Write-Verbose "$($hookurl) added to senttable"
    
        }
        else{
            Write-Verbose "$($hookurl) already exists"
        }    
    }
}
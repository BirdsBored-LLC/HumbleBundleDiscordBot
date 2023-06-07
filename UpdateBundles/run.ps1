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

$url = 'https://www.humblebundle.com/bundles'

$html = Invoke-WebRequest -Uri $url -UseBasicParsing

$html |ForEach-Object { $_ -match '<script id="landingPage-json-data" type="application\/json">\n(?<content>.*)\n<\/script>' }
$results =$matches[0].remove(0,60).replace('</script>','')|ConvertFrom-Json

# Find the bundle elements using XPath
$Gameurls = $results.data.games.mosaic.products| select-object product_url,'start_date|datetime','end_date|datetime',marketing_blurb,detailed_marketing_blurb,tile_image
$Softwareurls = $results.data.software.mosaic.products| select-object product_url,'start_date|datetime','end_date|datetime',marketing_blurb,detailed_marketing_blurb,tile_image
$booksURL = $results.data.books.mosaic.products| select-object product_url,'start_date|datetime','end_date|datetime',marketing_blurb,detailed_marketing_blurb,tile_image

$storageAccountName = 'birdsboredstorageaccount'
$storagekey = $env:storagekey

$humbleBundleTable=Get-AzStorageTable -Name 'humbleBundles' -Context (New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storagekey)
$cloudTable = $humbleBundleTable.CloudTable


foreach($end in $Gameurls){
    $enc = [System.Text.Encoding]::UTF8
    $encodedurl= $enc.GetBytes('https://humblebundle.com'+$end.product_url.toString()+'?partner=birdsbored') -join ' '
    $rowkey = $enc.GetBytes($end.product_url) -join ' '
    if(!(Get-AzTableRow -table $cloudTable -PartitionKey 'GAMES' -RowKey $rowkey)){
        Push-OutputBinding -Name outhumbleBundleTable -Value @{
            PartitionKey='GAMES'
            RowKey=$rowkey
            start_date=(get-date $end.'start_date|datetime' -Format "yyyy-MM-ddTHH:mm:ss")
            end_date=(get-date $end.'end_date|datetime' -Format "yyyy-MM-ddTHH:mm:ss")
            url=$encodedurl
            marketing_blurb=$end.marketing_blurb
            detailed_marketing_blurb=$end.detailed_marketing_blurb
            tile_image=$end.tile_image    
        }

    }
    else{
        Write-Verbose "$($end.product_url.toString()) already exists"
    }
}
foreach($end in $Softwareurls){
    $enc = [System.Text.Encoding]::UTF8
    $encodedurl= $enc.GetBytes('https://humblebundle.com'+$end.product_url.toString()+'?partner=birdsbored')  -join ' '
    $rowkey = $enc.GetBytes($end.product_url) -join ' '

    if(!(Get-AzTableRow -table $cloudTable -PartitionKey 'SOFTWARE' -RowKey $rowkey)){
        Push-OutputBinding -Name outhumbleBundleTable -Value @{
            PartitionKey='SOFTWARE'
            RowKey=$rowkey
            start_date=(get-date $end.'start_date|datetime' -Format "yyyy-MM-ddTHH:mm:ss")
            end_date=(get-date $end.'end_date|datetime' -Format "yyyy-MM-ddTHH:mm:ss")
            url=$encodedurl
            marketing_blurb=$end.marketing_blurb
            detailed_marketing_blurb=$end.detailed_marketing_blurb
            tile_image=$end.tile_image    
        }


    }
    else{
        Write-Verbose "$($end.product_url.toString()) already exists"
    }
}
foreach($end in $booksURL){
    $enc = [System.Text.Encoding]::UTF8
    $encodedurl= $enc.GetBytes('https://humblebundle.com'+$end.product_url.toString()+'?partner=birdsbored') -join ' '
    $rowkey = $enc.GetBytes($end.product_url) -join ' '
    if(!(Get-AzTableRow -table $cloudTable -PartitionKey 'BOOKS' -RowKey $rowkey)){
        Push-OutputBinding -Name outhumbleBundleTable -Value @{
            PartitionKey='BOOKS'
            RowKey=$rowkey
            start_date=(get-date $end.'start_date|datetime' -Format "yyyy-MM-ddTHH:mm:ss")
            end_date=(get-date $end.'end_date|datetime' -Format "yyyy-MM-ddTHH:mm:ss")
            url=$encodedurl
            marketing_blurb=$end.marketing_blurb
            detailed_marketing_blurb=$end.detailed_marketing_blurb
            tile_image=$end.tile_image    
        }
    }
    else{
        Write-Verbose "$($end.product_url.toString()) already exists"
    }
}

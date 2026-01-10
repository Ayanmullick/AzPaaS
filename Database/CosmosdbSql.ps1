New-AzQuota in the Az.Quota module doesn't work for Cosmos. PFB PowerShell workaround using Az.Support module.

New-AzCosmosDBAccount doesn't work for 'Serverless' accounts. PFB workaround using Az.Resource module.




$resourceGroupName = "myResourceGroup"
$accountName = "mycosmosaccount"
$apiKind = "Sql"
$consistencyLevel = "BoundedStaleness"
$maxStalenessInterval = 300
$maxStalenessPrefix = 100000
$locations = @()
$locations += New-AzCosmosDBLocationObject -LocationName "East US" -FailoverPriority 0 -IsZoneRedundant 0
$locations += New-AzCosmosDBLocationObject -LocationName "West US" -FailoverPriority 1 -IsZoneRedundant 0

New-AzCosmosDBAccount `
    -ResourceGroupName cosmos `
    -LocationObject $locations `
    -Name $accountName `
    -ApiKind $apiKind `
    -EnableAutomaticFailover:$true `
    -DefaultConsistencyLevel $consistencyLevel `
    -MaxStalenessIntervalInSeconds $maxStalenessInterval `
    -MaxStalenessPrefix $maxStalenessPrefix


New-AzCosmosDBAccount -Location SouthCentralUS -ResourceGroupName cosmos -Name Ztechlower -ApiKind Sql -EnableAutomaticFailover  -DefaultConsistencyLevel Session -MaxStalenessIntervalInSeconds 5 -MaxStalenessPrefix 100 -Verbose

#Serverless deployment mode not exposed thru API
New-AzCosmosDBAccount -Location SouthCentralUS -ResourceGroupName cosmos -Name ztechlower -ApiKind Sql -DefaultConsistencyLevel Session -MaxStalenessIntervalInSeconds 5 -MaxStalenessPrefix 100 -Verbose

$resourceGroupName = "myResourceGroup"
$accountName = "mycosmosaccount"
$databaseName = "myDatabase"

New-AzCosmosDBSqlDatabase -ResourceGroupName cosmos -AccountName ztechlower -Name ztechlower1 -Throughput 


#Properties for a default deployment
"properties": {
                "publicNetworkAccess": "Enabled",
                "enableAutomaticFailover": false,
                "enableMultipleWriteLocations": false,
                "isVirtualNetworkFilterEnabled": false,
                "virtualNetworkRules": [],
                "disableKeyBasedMetadataWriteAccess": false,
                "enableFreeTier": false,
                "enableAnalyticalStorage": false,
                "createMode": "Default",
                "databaseAccountOfferType": "Standard",
                "consistencyPolicy": {
                    "defaultConsistencyLevel": "Session",
                    "maxIntervalInSeconds": 5,
                    "maxStalenessPrefix": 100
                }

Get-CosmosDbOffer -Context $cosmosDbContext

#region Still thick provisions. EnableServerless doesn't work 

New-AzCosmosDBAccount -ResourceGroupName cosmos -Location EastUS -Name ayan -Capabilities {EnableServerless} -EnableFreeTier $true `
    -ApiKind GlobalDocumentDB -DefaultConsistencyLevel Session -EnableAutomaticFailover:$true -PublicNetworkAccess Enabled -MinimalTlsVersion Tls12
    
$Params =    @{ResourceGroupName  = 'cosmos'; Location = 'EastUS'}


#endregion    


#Az.Cosmosdb module blocked by:  https://github.com/Azure/azure-powershell/issues/20836
#region -Failed in NorthCentralUS. Worked in EastUS

$Params =    @{ResourceGroupName  = 'cosmos'; Location = 'EastUS'}
$AccountResource = @{ResourceType= 'Microsoft.DocumentDB/databaseAccounts'; ApiVersion= '2025-05-01-preview'; Kind= 'GlobalDocumentDB'}

$cosmosProps = @{databaseAccountOfferType = 'Standard'; enableFreeTier = $true ; capacityMode = 'Serverless' 
    locations = @( @{locationName= 'EastUS'; failoverPriority= 0; isZoneRedundant= $false } )
    consistencyPolicy = @{defaultConsistencyLevel = 'Session'; maxIntervalInSeconds = 5 ; maxStalenessPrefix = 100  }
    publicNetworkAccess = 'Enabled'
}

New-AzResource -Name ayan @Params -PropertyObject $cosmosProps @AccountResource -Force 
     
New-AzCosmosDBSqlDatabase  -ResourceGroupName cosmos -AccountName ayan -Name ayan
New-AzCosmosDBSqlContainer -ResourceGroupName cosmos -AccountName ayan -DatabaseName ayan -Name 'items' -PartitionKeyPath '/pk' -PartitionKeyKind 'Hash'

$rgName,$accountName, $dbName, $containerId = 'cosmos','ayan','ayan', 'items'
Remove-AzCosmosDBSqlContainer -ResourceGroupName $rgName -AccountName $accountName -DatabaseName $dbName -Name $containerId

#endregion


#region
$Params =    @{ResourceGroupName  = 'cosmos'; Location = 'EastUS'}
$AccountResource = @{ResourceType= 'Microsoft.DocumentDB/databaseAccounts'; ApiVersion= '2025-10-15'; Kind= 'GlobalDocumentDB'}

$cosmosProps = @{databaseAccountOfferType = 'Standard'; enableFreeTier = $true; capacityMode = 'Serverless'
    enableAutomaticFailover = $true; minimalTlsVersion = 'Tls12'; publicNetworkAccess = 'Enabled'
    locations = @(  @{locationName = 'EastUS'; failoverPriority = 0; isZoneRedundant = $false }  )
    consistencyPolicy = @{defaultConsistencyLevel = 'Session'; maxIntervalInSeconds = 5; maxStalenessPrefix = 100}
               }

New-AzResource -Name ayan @Params -PropertyObject $cosmosProps @AccountResource -Force 

#endregion


#Gets the latest API versions
Get-AzResourceProvider -ProviderNamespace Microsoft.DocumentDB |Select -ExpandProperty ResourceTypes |
  Where-Object ResourceTypeName -eq 'databaseAccounts' | Select -ExpandProperty ApiVersions -First 10






#region
Install-PSResource -Name CosmosDB #-Scope CurrentUser -Force

$rgName,$accountName, $dbName, $containerId = 'cosmos','ayan','ayan', 'items'
$cosmosDbContext = New-CosmosDbContext `
    -Account          $accountName `
    -Database         $dbName `
    -ResourceGroupName $rgName `
    -MasterKeyType    PrimaryMasterKey  # or SecondaryMasterKey if you prefer


$volcanoUrl = 'https://raw.githubusercontent.com/Azure-Samples/azure-cosmos-db-sample-data/main/SampleData/VolcanoData.json'
$tempFile   = Join-Path $env:TEMP 'volcano.json'

Invoke-WebRequest -Uri $volcanoUrl -OutFile $tempFile
$volcanoDocs = Get-Content -Raw -Path $tempFile | ConvertFrom-Json



New-AzCosmosDBSqlContainer -ResourceGroupName $rgName -AccountName $accountName -DatabaseName $dbName -Name $containerId -PartitionKeyPath  '/Country' -PartitionKeyKind  'Hash'
(Get-AzCosmosDBSqlContainer -ResourceGroupName $rgName -AccountName $accountName -DatabaseName $dbName -Name $containerId).Resource.PartitionKey.Paths # should show: /Country

$collectionId = $containerId

foreach ($doc in $volcanoDocs) {
    # Ensure we send JSON, not a PSObject
    $jsonBody = $doc | ConvertTo-Json -Depth 10

    # Use Country as the partition key value (matches /Country path)
    New-CosmosDbDocument `
        -Context      $cosmosDbContext `
        -CollectionId $collectionId `
        -DocumentBody $jsonBody `
        -PartitionKey $doc.Country
}


$query = 'SELECT VALUE COUNT(1) FROM c'

$result = Get-CosmosDbDocument `
    -Context                 $cosmosDbContext `
    -CollectionId            $collectionId `
    -Query                   $query `
    -QueryEnableCrossPartition $true

$remoteCount = $result[0]
$remoteCount


#endregion





#Script to read an Item:   https://github.com/Azure/azure-cosmos-dotnet-v3/blob/master/Microsoft.Azure.Cosmos.Samples/Usage/PowerShellRestApi/PowerShellScripts/ReadItem.ps1 #Was erroring out

#region Query an item directly from Cosmosdb using master account key|  Works|   https://stackoverflow.com/a/59449703/2748772
$acc,$db,$cont          ='ztech','Ayan','Ayanid'
$Key,$KeyType,$TokenVer ='<>','master','1.0'

# create Authorization header
$Date                   = (Get-Date).ToUniversalTime().toString('R')
$StringToSign           = "get`n" +"docs`n"+"dbs/$db/colls/$cont`n" + $Date.ToLowerInvariant() + "`n" + "" + "`n"
$hmacsha                = New-Object System.Security.Cryptography.HMACSHA256
$hmacsha.key            = [Convert]::FromBase64String($Key)
$signature              = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($StringToSign))
$signature              = [Convert]::ToBase64String($signature)
$authorization          = [System.Web.HttpUtility]::UrlEncode("type=${KeyType}&ver=${TokenVer}&sig=$signature")

$header                 = @{Authorization=$authorization;"x-ms-version"="2018-12-31";"x-ms-documentdb-isquery"="True";"x-ms-date"=$Date}   #latest version of the API

#returns all documents instead of a specific one if partitionkey is removed from the header
$header                 = @{Authorization=$authorization;"x-ms-version"="2018-12-31";"x-ms-date"=$Date;"x-ms-documentdb-partitionkey" = '["<>"]'} 

$query=@"
{"query": "SELECT * FROM c "}
"@

Invoke-RestMethod -Method GET -ContentType "application/query+json" -Uri "https://$acc.documents.azure.com//dbs/$db/colls/$cont/docs" -Headers $header -Body $query 

(Invoke-RestMethod -Method GET -ContentType "application/query+json" -Uri "https://$acc.documents.azure.com/dbs/$db/colls/$cont/docs" -Headers $header -Body $query).Documents|Format-Table
#endregion



#Adding parameters in the query or with 'where ' didn't work
$query=@"
{"query": "SELECT * FROM c WHERE c.id = "4cb67ab0-ba1a-0e8a-8dfc-d48472fd5766""}
"@

$query=@"
{  
  "query": "SELECT * FROM c",  
  "parameters": [ {  
    "name": "@id",  
    "value": "4cb67ab0-ba1a-0e8a-8dfc-d48472fd5766"  
  },  ]  
} 
"@


#Query. Works on VSC Azure Cosmos extension
SELECT c["Volcano Name"] AS VolcanoName,c.Country,c.Region,c.Elevation,c.Type,c["Last Known Eruption"] AS LastKnownEruption FROM c  #projection can't be edited

SELECT * FROM c WHERE c.id = "4cb67ab0-ba1a-0e8a-8dfc-d48472fd5766"   #the result can be edited


Get-AzCosmosDBAccount -ResourceGroupName cosmos
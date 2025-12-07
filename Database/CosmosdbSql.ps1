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
    -ResourceGroupName $resourceGroupName `
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


#Az.Cosmosdb module blocked by:  https://github.com/Azure/azure-powershell/issues/20836
#region

$Params =    @{ResourceGroupName  = 'cosmos'; Location = 'NorthCentralUS'}
$AccountResource = @{ResourceType= 'Microsoft.DocumentDB/databaseAccounts'; ApiVersion= '2025-05-01-preview'; Kind= 'GlobalDocumentDB'}

$cosmosProps = @{databaseAccountOfferType = 'Standard'; enableFreeTier = $true ; capacityMode = 'Serverless' 
    locations = @( @{locationName= 'NorthCentralUS'; failoverPriority= 0; isZoneRedundant= $false } )
    consistencyPolicy = @{defaultConsistencyLevel = 'Session'; maxIntervalInSeconds = 5 ; maxStalenessPrefix = 100  }
    publicNetworkAccess = 'Enabled'
}

New-AzResource -Name ayan @Params -PropertyObject $cosmosProps @AccountResource -Force 
     
New-AzCosmosDBSqlDatabase  -ResourceGroupName cosmos -AccountName ayan -Name ayan
New-AzCosmosDBSqlContainer -ResourceGroupName $Params.ResourceGroupName -AccountName $accountName -DatabaseName 'appdb' -Name 'items' -PartitionKeyPath '/pk' -PartitionKeyKind 'Hash'
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
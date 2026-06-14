# Variables
$rg = "rg-cosmos-table"
$location = "EastUS"
$accountName = "cosmosacct$(Get-Random -Maximum 9999)"
$tableName = "SampleTable"

# Create Resource Group (if not exists)
New-AzResourceGroup -Name $rg -Location $location


# Create Cosmos DB account with Table API
New-AzCosmosDBAccount `
    -ResourceGroupName $rg `
    -Name $accountName `
    -Location $location `
    -Kind GlobalDocumentDB `
    -Capability @("EnableTable") `
    -DefaultConsistencyLevel "Session"
$subscriptionName = "Windows Azure  MSDN - Visual Studio Premium"
$resourceGroup = "Infrastructure"
$storageAccount = "<>"
$tableName = "table01"
$partitionKey = "LondonSite"

$saContext = (Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context

New-AzStorageTable –Name $tableName –Context $saContext
$table = Get-AzStorageTable -Name $tableName -Context $saContext
$table = Get-AzStorageTableTable -resourceGroup $resourceGroup -tableName $tableName -storageAccountName $storageAccount


Add-AzStorageTableRow -table $table -partitionKey $partitionKey -rowKey ([guid]::NewGuid().tostring()) -property @{"computerName"="COMP01";"osVersion"="Windows 10";"status"="OK"}
Add-AzStorageTableRow -table $table -partitionKey $partitionKey -rowKey ([guid]::NewGuid().tostring()) -property @{"computerName"="COMP02";"osVersion"="Windows 8.1";"status"="OK"}
Add-AzStorageTableRow -table $table -partitionKey $partitionKey -rowKey ([guid]::NewGuid().tostring()) -property @{"computerName"="COMP03";"osVersion"="Windows XP";"status"="NeedsOsUpgrade"}



$computerList = '[{"computerName":"COMP04","osVersion":"Windows 7","status":"OK"},{"computerName":"COMP05","osVersion":"Windows 8","status":"OK"},{"computerName":"COMP06","osVersion":"Windows XP","status":"NeedsOsUpgrade"},{"computerName":"COMP07","osVersion":"Windows NT 4","status":"NeedsOsUpgrade"}]'
$newPartitionKey = "NewYorkSite"
foreach ($computer in ($computerList | ConvertFrom-Json) )
{
    Add-AzStorageTableRow -table $table `
        -partitionKey $newPartitionKey `
        -rowKey ([guid]::NewGuid().tostring()) `
        -property @{"computerName"=$computer.computerName;"osVersion"=$computer.osVersion;"status"=$computer.status}
}



Install-Module -Name AzStorageTable.TravisEz13 -Verbose

Get-AzStorageTableRowAll -table $table | Format-Table




Get-AzStorageTableRowByPartitionKey -table $table -partitionKey 'LondonSite' | ft


Get-AzureStorageTableRowByColumnName -table $table -columnName "computerName" -value "COMP01" -operator Equal



Get-AzStorageTableRowByColumnName -table $table -columnName identifier -guidValue 'e6c9ae32-487f-4140-b518-65a7ef4619ce' -operator Equal  #didn't work




[string]$filter1 = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition("computerName",[Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal,"COMP06")
Get-AzStorageTableRowByCustomFilter -table $table -customFilter $filter1





[string]$filter1 = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition("computerName",[Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal,"COMP03")
[string]$filter2 = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition("status",[Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal,"NeedsOsUpgrade")
[string]$finalFilter = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::CombineFilters($filter1,"and",$filter2)
Get-AzStorageTableRowByCustomFilter -table $table -customFilter $finalFilter



Get-AzStorageTableRowByCustomFilter -table $table -customFilter "(computerName eq 'COMP07') and (status eq 'NeedsOsUpgrade')"




# Creating the filter and getting original entity
[string]$filter = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition("computerName ",[Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal,"COMP03")
$computer = Get-AzureStorageTableRowByCustomFilter -table $table -customFilter $filter
# Changing values
$computer.osVersion = "Windows 10"
$computer.status = "OK"
# Updating the content
$computer | Update-AzureStorageTableRow -table $table
# Getting the entity again to check the changes
Get-AzureStorageTableRowByCustomFilter -table $table -customFilter $filter







[string]$filter1 = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition("computerName",[Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal,"COMP02")
$computerToDelete = Get-AzureStorageTableRowByCustomFilter -table $table -customFilter $filter1
$computerToDelete | Remove-AzureStorageTableRow -table $table







[string]$filter1 = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition("computerName",[Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal,"COMP06")
$computerToDelete = Get-AzureStorageTableRowByCustomFilter -table $table -customFilter $filter1
Remove-AzureStorageTableRow -table $table -entity $computerToDelete







Remove-AzureStorageTableRow -table $table -partitionKey "NewYorkSite" -rowKey "<RowKey value here>"




Get-AzureStorageTableRowAll -table $table | Remove-AzureStorageTableRow -table $table


#------------------------------------------------------------------------------------------------------------------------------------------
#write excel to Azure Tables
function Add-Entity()
{
 [CmdletBinding()]

 param
 (
 $table,
 [string] $partitionKey,
 [string] $rowKey,
 [string] $FirstName,
 [string] $LastName
 )

 $entity = New-Object -TypeName Microsoft.WindowsAzure.Storage.Table.DynamicTableEntity -ArgumentList $partitionKey, $rowKey
 $entity.Properties.Add("FirstNameirstName")
 $entity.Properties.Add("LastNameastName")

 $result = $table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Insert($entity))
}

Clear-Host
$subscriptionName = "Azure Pass"
$resourceGroupName = "mdjblogpost"
$storageAccountName = "mdjblogpost"
$location = "East US"
$containerName = "mdjblogpost"
$tableName = "MyTable"

# Log on to Azure and set the active subscription
Add-AzureRMAccount
Select-AzureRmSubscription -SubscriptionName $subscriptionName

# Get the storage key for the storage account
$storageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName).Value[0]

# Get a storage context
$ctx = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

# Get a reference to the table
$table = Get-AzureStorageTable -Name $tableName -Context $ctx

$csv = Import-CSV {path to your data}

ForEach ($line in $csv)
{
 Add-Entity -Table $table -partitionKey $line.Column1 -rowKey $line.RowKey -FirstName $line.FirstName -LastName $line.LastName
}

#region Runbook Sample Code for Azure Resource Manager based Storage
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName
    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
Import-Module AzureRmStorageTable
$resourceGroup = "resourceGroup01"
$storageAccount = "storageAccountName"
$tableName = "table01"
$partitionKey = "TableEntityDemo"
$saContext = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount).Context
$table = Get-AzureStorageTable -Name $tableName -Context $saContext
# Adding rows/entities
Add-StorageTableRow -table $table -partitionKey $partitionKey -rowKey ([guid]::NewGuid().tostring()) -property @{"firstName"="Paulo";"lastName"="Costa";"role"="presenter"}
# Getting all rows
Get-AzureStorageTableRowAll -table $table
#endregion



#Found a module for AzTables CRUD operations using PowerShell. Didn't fork since didn't test yet.
Install-Module -Name InstallModuleFromGitHub  #works
Install-ModuleFromGitHub -GitHubRepo plamber/aztablestorage -Verbose  #No errors on Windows PowerShell. However, errors on PS7.
https://www.nubo.eu/azure-table-storage-crud-operations-with-Powershell/

#region
## Initializing the module
$storage = "adsa2tdeh2hvmrwrg"
$key = "<>"
Import-Module AZTableModule.psm1 -ArgumentList $storage, $key

Import-Module -Name 'C:\Users\<>\PowerShell\Downloaded\AZTableModule.psm1' -ArgumentList $storage, $key -Verbose



#Didn't work with Cosmos db
$storage = "serverlesstable"
$key = "<>"
Import-Module -Name 'C:\Users\<>\PowerShell\Downloaded\AzCosmosTableCRUD.psm1' -ArgumentList $storage, $key -Verbose






## Creating a new table
New-AzTable "sampletable"

## Add a new entry to your table
# - Dates must be older or equal than "1901-01-01"
# - Replaces the entry if the unique key and partitionkey matches

$birthDate = (Get-date -date "1983-01-02")
$patrick = @{
    PartitionKey = 'yourPartitionName'
    RowKey = '<>'
    "birthDate@odata.type"="Edm.DateTime"
    birthDate = $birthDate.toString("yyyy-MM-ddT00:00:00.000Z")
    name = "Patrick"
    lastname = "Lamber"
}
Add-AzTableEntry -table "sampletable" -partitionKey $patrick.PartitionKey -rowKey $patrick.RowKey -entity $patrick

## Create a new entry or merge it with an existing one
$birthDate = (Get-date -date "1986-10-19")
$rene = @{
    PartitionKey = 'yourPartitionName'
    RowKey = '<>'
    "birthDate@odata.type"="Edm.DateTime"
    birthDate = $birthDate.toString("yyyy-MM-ddT00:00:00.000Z")
    name = "Rene'"
    lastname = "Lamber"
}
Merge-AzTableEntry -table "sampletable" -partitionKey $rene.PartitionKey -rowKey $rene.RowKey -entity $rene

## Return a single entry
$patrickFromTheCloud = Get-AzTableEntry -table "sampletable" -partitionKey $patrick.PartitionKey -rowKey $patrick.RowKey

## Update an individual field of an existing entry
$patrickFromTheCloud = Get-AzTableEntry -table "sampletable" -partitionKey $patrick.PartitionKey -rowKey $patrick.RowKey
$patrickFromTheCloud.name = "Patrick has been updated"
Merge-AzTableEntry -table "sampletable" -partitionKey $patrickFromTheCloud.PartitionKey -rowKey $patrickFromTheCloud.RowKey -entity $patrickFromTheCloud  #Didn't work on Cosmosdb

## Get all entries
$entries = Get-AzTableEntries -table "sampletable"

## Select individual fields from the table
$entriesWithSomeProperties = Get-AzTableEntries -table "sampletable" -select "RowKey,PartitionKey,name"   

## Filter entries
$filteredEntries = Get-AzTableEntries -table "sampletable" -filter "name eq 'Patrick'"    #Didn't work on Cosmosdb

## Delete an entry
Remove-AzTableEntry -table "sampletable" -partitionKey $rene.PartitionKey -rowKey $rene.RowKey

## Delete a table
Remove-AzTable -table "sampletable"
#endregion
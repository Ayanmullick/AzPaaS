New-AzResourceGroup -Location East US -Name 'AzSQLPoC-BackupStorage' -Verbose
New-AzStorageAccount -Location EastUS -ResourceGroupName 'AzSQLPoC-BackupStorage' -Name sqlpocbackupstorage -SkuName Standard_LRS -AccessTier Hot -Kind StorageV2 -EnableHttpsTrafficOnly 1 -Verbose

#region
$RG             = Get-AzResourceGroup -Name 'rg-github-act-d-01'
$Params       = @{Location = 'CentralUS'; ResourceGroupName  = $RG.ResourceGroupName; Verbose=$true}

$MSI = Get-AzUserAssignedIdentity -ResourceGroupName $RG.ResourceGroupName -Name GHRunnerId

#New-AzKeyVault: Invalid value found at properties.networkAcls.ipRules[0].value: 192.168.1.0/24 belongs to forbidden range 192.168.0.0-192.168.255.255 (private IP addresses)
<#New-AzKeyVault: Operation on Virtual Network could not be performed. StatusCode: 400 (BadRequest). 
Error Code: SubnetsHaveNoServiceEndpointsConfigured. 
Error Message: Subnets sn-github-act-d-01 of virtual network 
/subscriptions/9a43c581-38ba-434f-881d-e5ee80cd5448/resourceGroups/rg-github-act-d-01/providers/Microsoft.Network/virtualNetworks/vnet-github-act-d-01 
do not have ServiceEndpoints for Microsoft.KeyVault resources configured. 
Add Microsoft.KeyVault to subnet's ServiceEndpoints collection before trying to ACL Microsoft.KeyVault resources to these subnets..
#>

$Vnet = Get-AzVirtualNetwork -ResourceGroupName 'rg-github-act-d-01' -Name 'vnet-github-act-d-01'
#Service endpoint creation didn't work. Created manually from portal    .
$Vnet | Set-AzVirtualNetworkSubnetConfig -Name $Vnet.Subnets[0].Name -AddressPrefix $Vnet.Subnets[0].AddressPrefix -ServiceEndpoint Microsoft.KeyVault | Set-AzVirtualNetwork


$KvNwRuleSet = New-AzKeyVaultNetworkRuleSetObject -DefaultAction Deny -Bypass AzureServices -IpAddressRange '110.0.1.0/24','28.2.0.0/16','<>' -VirtualNetworkResourceId $Vnet.Subnets[0].Id
$KeyVault = New-AzKeyVault @Params -VaultName GHRunnerKv1 -Sku Premium -NetworkRuleSet $KvNwRuleSet -EnableRbacAuthorization -EnablePurgeProtection  
New-AzRoleAssignment -Scope $KeyVault.ResourceId -ObjectId $MSI.PrincipalId -RoleDefinitionName 'Key Vault Administrator'
New-AzRoleAssignment -Scope $KeyVault.ResourceId -SignInName ayan.mullick@<> -RoleDefinitionName 'Key Vault Administrator' 
$Key = Add-AzKeyVaultKey -VaultName $KeyVault.VaultName -Name GHRunnerKey -Destination HSM 

# Create the storage account with specified properties, including AAD DS for file shares, CMK encryption, and network restrictions # #-PublicNetworkAccess Disabled
New-AzStorageAccount @Params -Name ghrunnermetc2 -IdentityType UserAssigned -AssignIdentity -UserAssignedIdentityId $MSI.Id -EnableAzureActiveDirectoryKerberosForFile $true `
    -SkuName Standard_LRS -Kind StorageV2 -AccessTier Hot -AllowBlobPublicAccess $false -AllowSharedKeyAccess $false `
    -MinimumTlsVersion "TLS1_2" -EnableHttpsTrafficOnly $true -RoutingChoice MicrosoftRouting `
    -KeyVaultUri $keyVault.VaultUri -KeyName $Key.Name -KeyVersion $Key.Version -KeyVaultUserAssignedIdentityId $MSI.Id

#Add  -  Publish route-specific endpoints   :  Microsoft network routing
       
Add-AzStorageAccountNetworkRule -ResourceGroupName $RG.ResourceGroupName -Name ghrunnermetc2 -IPAddressOrRange '110.0.1.0/24','28.2.0.0/16','<>' 
Add-AzStorageAccountNetworkRule -ResourceGroupName $RG.ResourceGroupName -Name ghrunnermetc2 -VirtualNetworkResourceId $Vnet.Subnets[0].Id  

#Allow trusted Microsoft services to access this storage account
#Allow read access to storage logging from any network
#Allow read access to storage metrics from any network
Update-AzStorageAccountNetworkRuleSet -ResourceGroupName 'rg-github-act-d-01' -Name ghrunnermetc2 -Bypass 'AzureServices,Logging,Metrics'  -Verbose

#The rule shows up on the portal if the default action is set to Deny
#endregion




#region network-restricted Key Vault and vault key encrypted storage account. 
$Name,$Loc  = 'StorageNUS','NorthCentralUS'
$RG         = New-AzResourceGroup -Location $Location -Name ($Name+'RG') 
$Params     = @{Location = $Location; ResourceGroupName  = $RG.ResourceGroupName;  Verbose=$true }

$NWRuleset  = New-AzKeyVaultNetworkRuleSetObject -DefaultAction Deny -Bypass AzureServices -IpAddressRange "<>"   #Allow azure services
$KeyVault   = New-AzKeyvault @Params -name $Name'KV' -EnabledForDiskEncryption -Sku Premium -EnableRbacAuthorization -EnablePurgeProtection -NetworkRuleSet $NWRuleset
$UMSI       = New-AzUserAssignedIdentity @Params -Name $Name'UMSI'

New-AzRoleAssignment -Scope $KeyVault.ResourceId -SignInName '<>' -RoleDefinitionName 'Key Vault Administrator'  
$EncKey     = Add-AzKeyVaultKey -VaultName $KeyVault.VaultName -Name ($Name+'Key') -Destination HSM 
New-AzRoleAssignment -RoleDefinitionName 'Key Vault Crypto Service Encryption User' -ObjectId $UMSI.PrincipalId -Scope ($KeyVault.ResourceId+'/keys/'+$EncryptionKey.Name)

$StorageAcc = New-AzStorageAccount @Params -Name $($Name+'SA').ToLower() -Kind StorageV2 -SkuName Standard_LRS -AccessTier Cool -AllowCrossTenantReplication $false -IdentityType UserAssigned -UserAssignedIdentityId $UMSI.Id `
                 -KeyVaultUri $KeyVault.VaultUri -KeyName $EncryptionKey.Name -KeyVersion $EncryptionKey.Version -KeyVaultUserAssignedIdentityId $UMSI.Id `
                 -EnableHttpsTrafficOnly 1 -AllowBlobPublicAccess $false -MinimumTlsVersion TLS1_2  `
                 -NetworkRuleSet (@{bypass="AzureServices,Logging,Metrics";defaultAction="Deny"; ipRules=(@{IPAddressOrRange="<>";Action="allow"}, @{IPAddressOrRange="<>";Action="allow"})  } )  #Allow logging and metrics. Add AzureServices

#-PublicNetworkAccess Disabled  | Don't use if one needs access from Azure portal
#-EnableAzureActiveDirectoryDomainServicesForFile
#-AllowSharedKeyAccess   #https://docs.microsoft.com/en-us/azure/storage/common/shared-key-authorization-prevent?tabs=azure-powershell


#endregion

#Add resource instance in network ruleset




#region Blob connectivity validation
Test-NetConnection -ComputerName newtestatt.file.core.windows.net -Port 445                               #This should work too

Select-AzSubscription '<>'
$Params            =  @{ResourceGroupName  = 'newtest'; Name = 'newtestatt'}
$storageAccount    = Get-AzStorageAccount @Params

Test-NetConnection -ComputerName ([System.Uri]::new($storageAccount.Context.FileEndPoint).Host) -Port 445  #AzFiles Network connectivity validation
Get-AzStorageShare -Context $storageAccount.Context -Name azreport|Get-AzStorageFile                       #Files read validation

Test-NetConnection -ComputerName ([System.Uri]::new($storageAccount.Context.BlobEndPoint).Host) -Port 443  #Blob Network connectivity validation
Get-AzStorageBlob -Context $storageAccount.Context -Container azure-webjobs-hosts                          #Blob read validation
Get-azstoragecontainer -Context $storageAccount.Context
#endregion

#region connectivity and authentication using system-assigned MSI and user-assigned MSI
Connect-AzAccount -Identity     #Connect-AzAccount -Identity -AccountId $managedIdentity.ClientId
$storageAccount    = Get-AzStorageAccount   #Get-AzStorageAccount -ResourceGroupName NewTest5RG -Name newtest5sa   #This worked with User managed identity
Test-NetConnection -ComputerName ([System.Uri]::new($storageAccount.Context.FileEndPoint).Host) -Port 445  #$storageAccount = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount

Get-AzStorageBlob -Context $storageAccount.Context -Container azure-webjobs-hosts
Get-AzStorageBlobContent -Blob locks/newtest5fa/host -Container azure-webjobs-hosts -Context $storageAccount.Context
Get-AzStorageBlobContent -Blob locks/newtest5fa/host -Container azure-webjobs-hosts -Destination test2.txt -Context $storageAccount.Context  #copies the file locally

Get-AzStorageShare -Context $storageAccount.Context -Name newtest5fad1qhjslm|Get-AzStorageFile 
Get-AzStorageFileContent -ShareName newtest5fad1qhjslm -Path "data/Functions/secrets/Sentinels/host.json" -Context $storageAccount.Context

#Module to be used to domain-join storage account to on-prem AD so one could use Aztive directory authentication
#https://docs.microsoft.com/en-us/azure/storage/files/storage-files-identity-ad-ds-enable#option-one-recommended-use-azfileshybrid-powershell-module
#endregion






#Building a context manually
$storageAccountKey = (Get-AzStorageAccountKey @Params).Value[0]
$destContext       = New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -StorageAccountKey $storageAccountKey -Protocol Https -Verbose

#Try to connect with MSI
$UserContext= New-AzStorageContext -StorageAccountName newtestatt -Protocol Https -UseConnectedAccount -Verbose  #Didn't work






.\AzCopy.exe /source:https://nlgsusuatcmsppdocsa01.blob.core.windows.net/nlg-artifacts/ /SourceKey:<> /Dest:https://<>.file.core.windows.net/datadisk/NLG/Artifacts /DestKey:<> /S


(Get-AzureRmStorageAccount -Name ayan -ResourceGroupName ayan).Sku.Tier   #Tier of a Storage account





#Download a file from a storage account
Get-AzStorageFileContent -Context $storageAcct.Context -ShareName "myshare" -Path "myDirectory\SampleUpload.txt" -Destination "C:\Users\ContainerAdministrator\CloudDrive\SampleDownload.txt"





#region Encryption report to see if all storage accounts have encryption enabled.
(Get-AzureRmSubscription).Name|
    % {Select-AzureRmSubscription -SubscriptionName $PSItem|select -Property Subscription;Write-Output $PSItem 
       $b=Get-AzureRmStorageAccount|select -Property StorageAccountName,Encryption,Location
       $a+=$b         
       }


       $a|Export-Excel -Path c:\a.xlsx

#endregion


#region Storage account static site
#set your active subscription to subscription of the storage account that will host your static website.
$storageAccount = Get-AzStorageAccount -ResourceGroupName "<resource-group-name>" -AccountName "<storage-account-name>"
$ctx = $storageAccount.Context
##Enable static website hosting.
Enable-AzStorageStaticWebsite -Context $ctx -IndexDocument '<index-document-name>' -ErrorDocument404Path '<error-document-name>'


#Upload objects to the $web container from a source directory.
set-AzStorageblobcontent -File "<path-to-file>" -Container `$web -Blob "<blob-name>" -Context $ctx



#Find the website URL by using PowerShell
$storageAccount = Get-AzStorageAccount -ResourceGroupName "<resource-group-name>" -Name "<storage-account-name>"
Write-Output $storageAccount.PrimaryEndpoints.Web
#endregion


#region Data Protection steps
#0. Create resource lock

#1. Soft delete :https://learn.microsoft.com/en-us/azure/storage/blobs/soft-delete-blob-enable?tabs=azure-powershell
Enable-AzStorageContainerDeleteRetentionPolicy -ResourceGroupName '<resource-group>' -StorageAccountName '<storage-account>' -RetentionDays 7  #For blobs

$ctx = New-AzStorageContext -StorageAccountName '<storage-account-name>' -StorageAccountKey '<storage-account-key>'#For blobs with hierarchical namespace
Enable-AzStorageDeleteRetentionPolicy -RetentionDays 4  -Context $ctx


#2.Enable versioning.
Update-AzStorageBlobServiceProperty -ResourceGroupName $rgName -StorageAccountName $accountName -IsVersioningEnabled $true

#3. Enable change feed
Update-AzStorageBlobServiceProperty -EnableChangeFeed $true

#4. Point in time restore: https://learn.microsoft.com/en-us/azure/storage/blobs/point-in-time-restore-manage?tabs=powershell


#5. Backup to vault: https://learn.microsoft.com/en-us/azure/backup/backup-blobs-storage-account-ps
#endregion


#region In progress:  Network restricted Azure storage account
New-AzRoleAssignment -Scope $StorageAcc.Id -SignInName ayan@mullick.in -RoleDefinitionName 'Storage Blob Data Owner'  


Get-AzStorageAccountNetworkRuleSet 
#Connectivity validation

#New Container

$container  = New-AzStorageContainer -Context $StorageAcc.Context -Name $($Name+'Container').ToLower() -Permission blob



$container = New-AzStorageContainer -Name $newContainerName -Context $storageAccount.Context -Permission blob

Set-AzStorageBlobContent -File $uploadFilePath -Container $container.Name -Blob $fileName -Context $storageAccount.Context
#endregion


New-AzStorageContainerStoredAccessPolicy -Container "MyContainer" -Policy "Policy01"
Get-AzStorageContainerStoredAccessPolicy -Container "Container07"
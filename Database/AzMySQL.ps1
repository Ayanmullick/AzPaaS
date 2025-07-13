Set-AzContext -SubscriptionId '<>'
Get-AzResourceProvider -ProviderNamespace Microsoft.DBforMySQL
#Register-AzResourceProvider -ProviderNamespace Microsoft.DBforMySQL




$Name,$Location = 'MySQL','NorthCentralUS'
$RG             = New-AzResourceGroup -Location $Location -Name ($Name+'RG') 
$Params         = @{ResourceGroupName  = $RG.ResourceGroupName; Location = $Location; Verbose=$true }


$Identity       = New-AzUserAssignedIdentity @Params -Name $Name'I'  # Create a user-assigned managed identity
$KeyVault       = New-AzKeyvault @Params -name $Name'KV1' -EnabledForDiskEncryption -Sku Premium -EnableRbacAuthorization
New-AzRoleAssignment -RoleDefinitionName 'Key Vault Administrator' -SignInName 'ayan@<>' -Scope $KeyVault.ResourceId

$Key= Add-AzKeyVaultKey -VaultName $Name'KV1'  -Name $Name'nuskey' -Destination Software

New-AzRoleAssignment -RoleDefinitionName 'Key Vault Crypto User' -ObjectId $Identity.PrincipalId -Scope $KeyVault.ResourceId #This gives the identity access to all the keys in the vault
#Need to create the RBAC scope for for a key in an Azure resource id format.

$resource.Properties | Add-Member -MemberType NoteProperty -Name enablePurgeProtection -Value 'True' -Force
Set-AzResource -resourceid $resource.ResourceId -Properties $resource.Properties -Verbose



#New-AzMySqlServer @Params -Name $Name -Sku GP_Gen5_1  -AdministratorUsername '<>' -AdministratorLoginPassword $(ConvertTo-SecureString '<>' -asplaintext -force)  #-GeoRedundantBackup Enabled

New-AzMySqlServer @Params -Name $Name'nus' -Sku GP_Gen5_1 -Version 8.0.21 -AdministratorUsername <> -AdministratorLoginPassword $(ConvertTo-SecureString '<>' -asplaintext -force) `
        -BackupRetentionDay 7 -GeoRedundantBackup Disabled -MinimalTlsVersion TLS1_2 -SslEnforcement Enabled -StorageAutogrow Enabled -StorageInMb 1024 -SubscriptionId '<>' -Verbose

#Error: Version '8.0.21' is not supported.  Deployed thru portal with Usermanaged identity and Keyvault integration. Not sure how to deploy thru PowerShell with that integration.

Auto scale IOPS (preview)
Allow public access from any Azure service within Azure to this server

-IdentityType UserAssigned -IdentityID $Identity.Id


New-AzMySqlFirewallRule -Name AllowMyIP -ResourceGroupName myresourcegroup -ServerName mydemoserver -StartIPAddress 192.168.0.1 -EndIPAddress 192.168.0.1

Update-AzMySqlServer -Name mydemoserver -ResourceGroupName myresourcegroup -SslEnforcement Disabled



Get-AzMySqlServer -Name mydemoserver -ResourceGroupName myresourcegroup |  Select-Object -Property FullyQualifiedDomainName, AdministratorLogin


$password = ConvertTo-SecureString '<>' -AsPlainText
Test-AzMySqlFlexibleServerConnect -ResourceGroupName MySQLRG -Name mysqlnus -AdministratorLoginPassword $password  #Crashed Windows Terminal

#The connection testing to mysql-test.database.azure.com was successful!

$password = ConvertTo-SecureString '<>' -AsPlainText
Get-AzMySqlFlexibleServer -ResourceGroupName MySQLRG -ServerName mysqlnus | Test-AzMySqlFlexibleServerConnect -AdministratorLoginPassword $password

#The connection testing to mysql-test.database.azure.com was successful!




#Test-AzMySqlFlexibleServerConnect: Cannot process argument transformation on parameter 'AdministratorLoginPassword'. Cannot convert the "ayan@mullick.in" value of type "System.String" to type "System.Security.SecureString".



$cred= New-Object System.Management.Automation.PSCredential "ayan<>",$(ConvertTo-SecureString '<>' -asplaintext -force)

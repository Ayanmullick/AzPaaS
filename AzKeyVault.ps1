Get-AzKeyVaultSecret -VaultName RHEL84 -Name ayan -AsPlainText  #To view the value contained in the secret as plain text:

New-AzKeyVault -ResourceGroupName $RG -VaultName $($NamingPrefix+'KV') -Location EastUS2 -Sku Premium -Verbose
$KeyVault       = New-AzKeyvault @Params -name $Name'KV1' -EnabledForDiskEncryption -Sku Premium #-EnableRbacAuthorization #Create vault for AzVM disk encryption and with RBAC enabled


#region v2 network-restricted Key Vault. 
$Name,$Loc  = 'StorageNUS','NorthCentralUS'
$RG         = New-AzResourceGroup -Location $Location -Name ($Name+'RG') 
$Params     = @{Location = $Location; ResourceGroupName  = $RG.ResourceGroupName;  Verbose=$true }

$NWRuleset  = New-AzKeyVaultNetworkRuleSetObject -DefaultAction Deny -Bypass AzureServices -IpAddressRange "<>"   #Allow azure services
$KeyVault   = New-AzKeyvault @Params -name $Name'KV' -EnabledForDiskEncryption -Sku Premium -EnableRbacAuthorization -EnablePurgeProtection -NetworkRuleSet $NWRuleset
New-AzRoleAssignment -Scope $KeyVault.ResourceId -SignInName ayan@<> -RoleDefinitionName 'Key Vault Administrator'  
#endregion
New-AzRoleAssignment -Scope $KeyVault.ResourceId -ObjectId $Identity.PrincipalId -RoleDefinitionName 'Key Vault Administrator'  #For SPN of User assigned managed identity


Set-AzKeyVaultAccessPolicy -VaultName $key_vault_name -UserPrincipalName $user_name -PermissionsToSecrets $permissions
Set-AzKeyVaultAccessPolicy -VaultName $key_vault_name -ServicePrincipalName $sp_name -PermissionsToSecrets $permissions  # Add access policy for the service principal

Set-AzKeyVaultAccessPolicy -VaultName $KV.VaultName -PermissionsToSecrets get,list -Verbose -ObjectId $Identity.PrincipalId


Set-AzKeyVaultAccessPolicy -VaultName $key_vault_name -ObjectId $user_object_id -PermissionsToSecretManagement all


#region V3: Key Vault setup with service endpoints and private access
$vnet.Subnets[1].ServiceEndpoints += [Microsoft.Azure.Commands.Network.Models.PSServiceEndpoint]@{Service='Microsoft.KeyVault';Locations='centralus'}
Set-AzVirtualNetwork -VirtualNetwork $vnet -Verbose

#$vnet = Get-AzVirtualNetwork -ResourceGroupName $RG.ResourceGroupName
#$vnet.Subnets[1].ServiceEndpoints
<#ProvisioningState Service            Locations   NetworkIdentifier
----------------- -------            ---------   -----------------
Succeeded         Microsoft.Sql      {centralus} 
Succeeded         Microsoft.KeyVault {*}
#>


# Create Key Vault network rule set to allow only the subnet
$NWRuleset = New-AzKeyVaultNetworkRuleSetObject -DefaultAction Deny -Bypass AzureServices -VirtualNetworkResourceId $vnet.Subnets[1].Id

# Create Key Vault with network restrictions. '-EnableRbacAuthorization' is implicit now. No need to specify explicitly
$KeyVault = New-AzKeyVault @Params -Name ('kv-' + $NameSuffix) -EnabledForDiskEncryption -Sku Premium -EnablePurgeProtection -NetworkRuleSet $NWRuleset
New-AzRoleAssignment -Scope $KeyVault.ResourceId -SignInName 'Ayan.Mullick@<>.us' -RoleDefinitionName 'Key Vault Administrator' -Verbose 

#region Add existing AVD subnet in the KV's Network rule
$BusinessPSub = Get-AzContext -ListAvailable | Where-Object { $_.Subscription.Name -eq '<>' }
$AvdVnet = Get-AzVirtualNetwork -Name 'vnet-avd<>' -DefaultProfile $BusinessPSub
#Enable KV service endopint
$AvdVnet.Subnets[0].ServiceEndpoints += [Microsoft.Azure.Commands.Network.Models.PSServiceEndpoint]@{Service='Microsoft.KeyVault';Locations='centralus'}
Set-AzVirtualNetwork -VirtualNetwork $AvdVnet -DefaultProfile $BusinessPSub -Verbose

Add-AzKeyVaultNetworkRule -VaultName $KeyVault.VaultName -ResourceGroupName $KeyVault.ResourceGroupName -VirtualNetworkResourceId $AvdVnet.Subnets[0].Id -Verbose
#endregion

Add-AzKeyVaultNetworkRule -VaultName $KeyVault.VaultName -ResourceGroupName $KeyVault.ResourceGroupName -IpAddressRange $(iwr https://api.ipify.org/).Content -Verbose


$Secret = ConvertTo-SecureString -String '<>' -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $KeyVault.VaultName -Name '<>' -SecretValue $Secret -Verbose


$UAMI = Get-AzUserAssignedIdentity -ResourceGroupName $RG.ResourceGroupName
New-AzRoleAssignment -RoleDefinitionName 'Key Vault Secrets User' -ObjectId $UAMI.PrincipalId -Scope $KeyVault.ResourceId -Verbose

#endregion





#region Convert Vault to Premium
$vault = Get-AzResource -ResourceId (Get-AzKeyVault -VaultName '<>').ResourceId
$vault.Properties.sku.name = 'premium'
Set-AzResource -ResourceId $vault.ResourceId -Properties $vault.Properties -Verbose
(Get-AzKeyVault -VaultName '<>' -Verbose).Sku
#endregion



#region Enable soft Delete
($resource = Get-AzResource -ResourceId (Get-AzKeyVault -VaultName '<>').ResourceId).Properties | Add-Member -MemberType "NoteProperty" -Name "enableSoftDelete" -Value "true"
Set-AzResource -resourceid $resource.ResourceId -Properties $resource.Properties -Verbose
(Get-AzKeyVault -VaultName '<>' -Verbose).EnableSoftDelete
#endregion




#region create certificate
$Policy = New-AzKeyVaultCertificatePolicy -SecretContentType "application/x-pkcs12" -SubjectName "CN=wfs.com" -IssuerName "Self" -ValidityInMonths 6 -ReuseKeyOnRenewal -Verbose
Add-AzKeyVaultCertificate -VaultName "test4321" -Name "test4321AzureRunAsCertificate" -CertificatePolicy $Policy -Verbose


Get-AzKeyVaultCertificateOperation -VaultName "test4321" -Name "test4321AzureRunAsCertificate"   #check certificate creation status

Get-AzKeyVaultCertificate -VaultName "test4321" -Name "test4321AzureRunAsCertificate"   #Get certificate details

#endregion



#region export keyvault certificate
$vaultName = "<>"
$secretName = "wingtiptoysPfxCert"
$kvSecret = Get-AzureKeyVaultSecret -VaultName $vaultName -Name $secretName
$kvSecretBytes = [System.Convert]::FromBase64String($kvSecret.SecretValueText)
$certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$certCollection.Import($kvSecretBytes,$null,[System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
$password = ‘<>’
$protectedCertificateBytes = $certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $password)
$pfxExprotPath = "C:\Temp\testkvexport.pfx"
[System.IO.File]::WriteAllBytes($pfxExprotPath , $protectedCertificateBytes)
#endregion




#region Change a key vault tenant ID after a subscription move
Select-AzSubscription -SubscriptionId <>                                   # Select your Azure Subscription
$vaultResourceId = (Get-AzKeyVault -VaultName <>).ResourceId               # Get your key vault's Resource ID 
$vault = Get-AzResource –ResourceId $vaultResourceId -ExpandProperties     # Get the properties for your key vault
$vault.Properties.TenantId = (Get-AzContext).Tenant.TenantId               # Change the Tenant that your key vault resides in
$vault.Properties.AccessPolicies = @()                                     # Access policies can be updated with real
                                                                           # applications/users/rights so that it does not need to be   
# done after this whole activity. Here we are not setting any access policies. 
Set-AzResource -ResourceId $vaultResourceId -Properties $vault.Properties  # Modifies the key vault's properties.
#endregion





#region Subscription tenant migration procedure for CMK-encrypted storage account
Get-AzADServicePrincipal |Out-GridView

Get-AzADServicePrincipal |? Id -Contains '40941e16-d00e-4252-8cb4-2e6de929250a'
Set-AzStorageAccount -ResourceGroupName '<>'  -Name '<>' -AssignIdentity -Verbose
<#PrincipalId                          TenantId                            
-----------                          --------                            
40941e16-d00e-4252-8cb4-2e6de929250a <>
#>

Get-AzStorageAccount -ResourceGroupName '<>' -Name '<>'|select -Property *


(Get-AzStorageAccount -ResourceGroupName '<>' -Name '<>').Identity
<#PrincipalId                          TenantId                            
-----------                          --------                            
40941e16-d00e-4252-8cb4-2e6de929250a <>
#>

(Get-AzContext).Tenant.TenantId 

#tenant id mismatch

#ARM to remove identity
#endregion

#region This storage account has been configured to encrypt using keys from the following Key Vault. However, you don’t have permission to grant 'ayn' access to this Key Vault.
#To grant the necessary Key Vault permissions to this server, the Key Vault administrator needs to do the following: In PowerShell, sign in using the Azure subscription that the Key Vault is in. Run the following cmdlet to add the required permissions.

$resource = Get-AzResource -ResourceId (Get-AzKeyVault -VaultName ayan).ResourceId
$resource.Properties | Add-Member -MemberType NoteProperty -Name enableSoftDelete -Value 'True' -Force
$resource.Properties | Add-Member -MemberType NoteProperty -Name enablePurgeProtection -Value 'True' -Force
Set-AzResource -ResourceId $resource.ResourceId -Properties $resource.Properties
Set-AzKeyVaultAccessPolicy -VaultName <> -ObjectId 40941e16-d00e-4252-8cb4-2e6de929250a -PermissionsToKeys get,wrapkey,unwrapkey

#endregion After this is done, click the 'Save' button and we will try to connect to your Key Vault.




#PowerShell generate random password
Add-Type -AssemblyName 'System.Web'
[System.Web.Security.Membership]::GeneratePassword(8,1)  #length of password and number of non-alpha characters





#keyvault RBAC enable
($resource = Get-AzResource -ResourceId (Get-AzKeyVault -VaultName $KV.VaultName).ResourceId).Properties | Add-Member -MemberType "NoteProperty" -Name "EnableRbacAuthorization" -Value "true" -Force
Set-AzResource -resourceid $KV.ResourceId -Properties $resource.Properties -Force -Verbose




#Key Vault scope role assignment
New-AzRoleAssignment -RoleDefinitionName 'Key Vault Secrets Officer' -SignInName {i.e user@microsoft.com} -Scope /subscriptions/{subscriptionid}/resourcegroups/{resource-group-name}/providers/Microsoft.KeyVault/vaults/{key-vault-name}

#Secret scope role assignment
#Assign by User Principal Name
New-AzRoleAssignment -RoleDefinitionName 'Key Vault Secrets Officer' -SignInName {i.e user@microsoft.com} -Scope /subscriptions/{subscriptionid}/resourcegroups/{resource-group-name}/providers/Microsoft.KeyVault/vaults/{key-vault-name}/secrets/RBACSecret
#Assign by Service Principal ApplicationId
New-AzRoleAssignment -RoleDefinitionName 'Key Vault Secrets Officer' -ApplicationId {i.e 8ee5237a-816b-4a72-b605-446970e5f156} -Scope /subscriptions/{subscriptionid}/resourcegroups/{resource-group-name}/providers/Microsoft.KeyVault/vaults/{key-vault-name}/secrets/RBACSecret


#Default key creation|  Key Type: RSA | Key Size : 2048 |Recovery Level : Recoverable+Purgeable
Add-AzKeyVaultKey -VaultName $Name'KV1'  -Name $Name'nuskey' -Destination Software
New-AzRoleAssignment -RoleDefinitionName 'Key Vault Crypto User' -ObjectId $Identity.PrincipalId -Scope $KeyVault.ResourceId #This gives the identity access to all the keys in the vault
#Need to create the RBAC scope for for a key in an Azure resource id format.
#region Create a Databricks Workspace
Register-AzResourceProvider -ProviderNamespace Microsoft.Databricks -Verbose

#Currently, the New-AzDatabricksWorkspace cmdlet does not support parameters for VNet injection or disabling public IPs directly.
#V2: Worked: The tags need to be added while creating the workspace to the resource group can inherit them and not be blocked by policy.
$NameSuffix = ($Name, $Env, $Loc, $Sr = 'databricks', 'd', 'c', '01') -join '-' 
$Params     = @{Location = 'CentralUS'; Verbose=$true}
$Tags       = @{Division='Enterprise'; Environment='Dev'; AppName= 'Databricks'; Owner= 'Ayan Mullick'}
$RG         = New-AzResourceGroup @Params -Name ('rg-'+ $NameSuffix) -Tag $Tags
$Params    += @{ResourceGroupName  = $RG.ResourceGroupName }

New-AzDatabricksWorkspace @Params -Name $NameSuffix -ManagedResourceGroupName ('rg-'+$Name+'mgd-'+$Env+'-'+$Loc+'-'+$Sr) -Tag $Tags -Sku premium 
    

#endregion
<#
Add user-add user to 'admins' group in settings
#>

<#
Databricks admin console--Catalog--Default--nyctaxi--trips--Open in dashboard >--Open in PowerBI Desktop

Added Entielements from 'Identity and access' settings.

#>

#region
New-AzDatabricksVNetPeering -Name vnet-peering-t1 -WorkspaceName azps-databricks-workspace-t1 -ResourceGroupName azps_test_gp_db -RemoteVirtualNetworkId $Vnet.Id
<#
Name            ResourceGroupName
----            -----------------
vnet-peering-t1 azps_test_gp_db
#>

New-AzDatabricksAccessConnector -ResourceGroupName azps_test_gp_db -Name azps-databricks-accessconnector -Location eastus -IdentityType 'SystemAssigned'
<#
Location Name                            ResourceGroupName
-------- ----                            -----------------
eastus   azps-databricks-accessconnector azps_test_gp_db
#>
#endregion
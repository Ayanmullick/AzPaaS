#region Create Managed instance
$location = "SouthCentralUS"
$resourceGroupName= 'NLGSUSDVJAMRG'
$virtualNetwork = Get-AzVirtualNetwork -Name NLGSUSNPRDMITVNET -ResourceGroupName NLGSUSMITVNETRG
$miSubnetName= 'SN_10.191.101.224_ST'
$miSubnetAddressPrefix = '10.191.101.224/28'
$miSubnetConfig = Get-AzVirtualNetworkSubnetConfig -Name $miSubnetName -VirtualNetwork $virtualNetwork 

$networkSecurityGroupMiManagementService = New-AzNetworkSecurityGroup -Name NLGDVJAMSMINSG -ResourceGroupName $resourceGroupName -location $location
$routeTableMiManagementService = New-AzRouteTable -Name NLGDVJAMSMIRT -ResourceGroupName $resourceGroupName -location $location
Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $virtualNetwork -Name $miSubnetName -AddressPrefix $miSubnetAddressPrefix -NetworkSecurityGroup $networkSecurityGroupMiManagementService -RouteTable $routeTableMiManagementService | Set-AzVirtualNetwork

Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name "NLGDVJAMSMINSG" | 
            Add-AzNetworkSecurityRuleConfig -Priority 100 -Name "allow_management_inbound"   -Access Allow -Protocol Tcp -Direction Inbound -SourcePortRange * -SourceAddressPrefix *                      -DestinationPortRange 9000,9003,1438,1440,1452 -DestinationAddressPrefix * |
            Add-AzNetworkSecurityRuleConfig -Priority 200 -Name "allow_misubnet_inbound"     -Access Allow -Protocol *   -Direction Inbound -SourcePortRange * -SourceAddressPrefix $miSubnetAddressPrefix -DestinationPortRange *                        -DestinationAddressPrefix * |
            Add-AzNetworkSecurityRuleConfig -Priority 300 -Name "allow_health_probe_inbound" -Access Allow -Protocol *   -Direction Inbound -SourcePortRange * -SourceAddressPrefix AzureLoadBalancer      -DestinationPortRange *                        -DestinationAddressPrefix * |
            Add-AzNetworkSecurityRuleConfig -Priority 1000 -Name "allow_tds_inbound"         -Access Allow -Protocol Tcp -Direction Inbound -SourcePortRange * -SourceAddressPrefix VirtualNetwork         -DestinationPortRange 1433                     -DestinationAddressPrefix * |
            Add-AzNetworkSecurityRuleConfig -Priority 1100 -Name "allow_redirect_inbound"    -Access Allow -Protocol Tcp -Direction Inbound -SourcePortRange * -SourceAddressPrefix VirtualNetwork         -DestinationPortRange 11000-11999              -DestinationAddressPrefix * |
            Add-AzNetworkSecurityRuleConfig -Priority 4096 -Name "deny_all_inbound"          -Access Deny  -Protocol *   -Direction Inbound -SourcePortRange * -SourceAddressPrefix *                      -DestinationPortRange *                        -DestinationAddressPrefix * | 
            Add-AzNetworkSecurityRuleConfig -Priority 100 -Name "allow_management_outbound"  -Access Allow -Protocol Tcp -Direction Outbound -SourcePortRange * -SourceAddressPrefix *                     -DestinationPortRange 80,443,12000             -DestinationAddressPrefix * |
            Add-AzNetworkSecurityRuleConfig -Priority 200 -Name "allow_misubnet_outbound"    -Access Allow -Protocol *   -Direction Outbound -SourcePortRange * -SourceAddressPrefix *                     -DestinationPortRange *                        -DestinationAddressPrefix $miSubnetAddressPrefix |
            Add-AzNetworkSecurityRuleConfig -Priority 4096 -Name "deny_all_outbound"         -Access Deny  -Protocol *   -Direction Outbound -SourcePortRange * -SourceAddressPrefix *                     -DestinationPortRange *                        -DestinationAddressPrefix * |
                Set-AzNetworkSecurityGroup

Get-AzRouteTable -ResourceGroupName $resourceGroupName -Name "NLGDVJAMSMIRT"|
    Add-AzRouteConfig -Name "ToManagedInstanceManagementService" -AddressPrefix 0.0.0.0/0 -NextHopType Internet |
    Add-AzRouteConfig -Name "ToLocalClusterNode" -AddressPrefix $miSubnetAddressPrefix -NextHopType VnetLocal|
        Set-AzRouteTable

$instanceName = 'NLGDVJAMSMI'
$cred = New-Object System.Management.Automation.PSCredential "nladmin",$(ConvertTo-SecureString '<>' -asplaintext -force)
#Set the managed instance service tier, compute level, and license mode
$edition = "BusinessCritical"
$vCores = 8
$maxStorage = 32
$computeGeneration = "Gen5"
$license = "BasePrice" #"BasePrice" or LicenseIncluded if you have don't have SQL Server licence that can be used for AHB discount

#Create managed instance
New-AzSqlInstance -Name $instanceName -ResourceGroupName $resourceGroupName -Location $location -SubnetId $miSubnetConfig.Id -AdministratorCredential $cred -StorageSizeInGB $maxStorage -VCore $vCores -Edition $edition -ComputeGeneration $computeGeneration -LicenseType $license -Verbose

#endregion


#Validate connectivity
$c = New-Object System.Management.Automation.PSCredential "nladmin",$(ConvertTo-SecureString '<>' -asplaintext -force)
Connect-DbaInstance -SqlInstance nlgnprdhedsmi.0d650f8b452b.database.windows.net -SqlCredential $c -Verbose

Invoke-Sqlcmd -ServerInstance nlgnprdhedsmi.0d650f8b452b.database.windows.net -Credential $c -Query "SELECT @@VERSION;"|ft -Wrap




#region Add a login TSQL. Logged in as the SQL user
USE master
GO
CREATE LOGIN [Grp_Azr_HEDOV_Db_Ow] FROM EXTERNAL PROVIDER
GO


ALTER SERVER ROLE sysadmin ADD MEMBER [Grp_Azr_HEDOV_Db_Ow]
GO



CREATE LOGIN [svc_hedov_dev@<>] FROM EXTERNAL PROVIDER
ALTER SERVER ROLE dbcreator ADD MEMBER [svc_hedov_dev@<>]




SELECT *  
FROM sys.server_principals;  
GO

#endregion



#region  database level access

CREATE USER [Grp_Azr_JAM_Op_Co] FROM EXTERNAL PROVIDER
EXEC sp_addrolemember 'db_datawriter', 'Grp_Azr_JAM_Op_Co';
EXEC sp_addrolemember 'db_datareader', 'Grp_Azr_JAM_Op_Co';

CREATE USER [Grp_Azr_JAM_Op_Re] FROM EXTERNAL PROVIDER
EXEC sp_addrolemember 'db_datareader', 'Grp_Azr_JAM_Op_Re';
#endregion








#Didn't work. Set manually
Set-AzSqlServerActiveDirectoryAdministrator -ResourceGroupName NLGSUSDVJAMRG -ServerName nlgdvjamsmi -DisplayName Grp_Azr_SQL_Ow -Verbose
<#VERBOSE: Performing the operation "About to process resource" on target "".
Set-AzSqlServerActiveDirectoryAdministrator : ParentResourceNotFound: Can not perform requested operation on nested resource. Parent resource 'nlgdvjamsmi' not found.
At line:1 char:1
+ Set-AzSqlServerActiveDirectoryAdministrator -ResourceGroupName NLGSUS ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
+ CategoryInfo          : CloseError: (:) [Set-AzSqlServer...ryAdministrator], CloudException
+ FullyQualifiedErrorId : Microsoft.Azure.Commands.Sql.ServerActiveDirectoryAdministrator.Cmdlet.SetAzureSqlServerActiveDirectoryAdministrator
#>




#Didn't work. 
Add-SqlLogin -ServerInstance nlgdvjamsmi.43756e0c9265.database.windows.net -Credential $c -LoginName Grp_Azr_JAM_Db_Ow -LoginType ExternalUser -DefaultDatabase master -Enable -GrantConnectSql

<#Add-SqlLogin : Login type 'ExternalUser' is not suppported by this cmdlet.
At line:1 char:1
+ Add-SqlLogin -ServerInstance nlgdvjamsmi.43756e0c9265.database.window ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Add-SqlLogin], NotImplementedException
    + FullyQualifiedErrorId : System.NotImplementedException,Microsoft.SqlServer.Management.PowerShell.Security.AddSqlLogin
#>


Get-DbaUserPermission -SqlInstance nlgdvjamsmi.43756e0c9265.database.windows.net -SqlCredential $c|ft



Test-DbaMigrationConstraint -Source NLGDVJAMDBVM1 -Destination nlgdvjamsmi.43756e0c9265.database.windows.net -DestinationSqlCredential $c -Database JAMS -Verbose

#Didn't work since the backup was encrypted probably
Start-DbaMigration -Source NLGDVJAMDBVM1 -Destination nlgdvjamsmi.43756e0c9265.database.windows.net -DestinationSqlCredential $c -BackupRestore -UseLastBackup -Verbose



#How I backed up the JAMS db to local disk.   SSMS--Select files to shrink-shrink transaction log.           Backup database ---selecting ‘Copy only’-- Compress 
BACKUP DATABASE [JAMS] TO  DISK = N'E:\Backup\JAMS1' WITH  COPY_ONLY, NOFORMAT, NOINIT,  NAME = N'JAMS-Full Database Backup', SKIP, NOREWIND, NOUNLOAD, COMPRESSION,  STATS = 10
GO
#And upload to storage container


#restore from blob isn't doable thru PowerShell
USE [master]
RESTORE DATABASE [JAMS] FROM  URL = N'https://nlgsusdvmitsa.blob.core.windows.net/architecturediagrams/JAMS1.bak'
GO

#Instance level
configure TDE
configure vulnerability and assessment settings


#database level
configure backup retention

enable advanced managed security
Initiate scan







#Get last replicated time for Managed SQL failover groups
select * FROM sys.dm_geo_replication_link_status

#could be used while connecting thru SSMS to the secondary failover group endpoint
ApplicationIntent=ReadOnly



#Failover
Get-AzureRmSqlDatabaseInstanceFailoverGroup -ResourceGroupName NLGPDJAMSMIRG -Location southcentralus -Name nlgjamsmifog

Get-AzureRmSqlDatabaseInstanceFailoverGroup -ResourceGroupName NLGPDJAMSMIRG -Name nlgjamsmifog -Location southcentralus|Switch-AzureRmSqlDatabaseInstanceFailoverGroup -Verbose



#region setup backup
Get-AzSqlInstanceDatabaseGeoBackup -InstanceName NLGDVJAMSMI -ResourceGroupName NLGSUSDVJAMRG -Verbose
Get-AzSqlDeletedInstanceDatabaseBackup -ResourceGroupName NLGSUSDVJAMRG -InstanceName NLGDVJAMSMI
Get-AzSqlInstanceDatabaseBackupShortTermRetentionPolicy -ResourceGroupName NLGSUSDVJAMRG -InstanceName NLGDVJAMSMI -DatabaseName JAMS_Dev -Verbose
Set-AzSqlInstanceDatabaseBackupShortTermRetentionPolicy -ResourceGroupName NLGSUSDVJAMRG -InstanceName NLGDVJAMSMI -DatabaseName JAMS_UAT -RetentionDays 35 -Verbose
#endregion

#Get retention policies of multiple databases from multiple managed instances
Get-AzSqlInstance|Get-AzSqlInstanceDatabase|Get-AzSqlInstanceDatabaseBackupShortTermRetentionPolicy|Format-Table


#Restore a managed instance to a different point in time
Restore-AzSqlinstanceDatabase -Name "Database01" -InstanceName "managedInstance1" -ResourceGroupName "ResourceGroup01" -PointInTime UTCDateTime -TargetInstanceDatabaseName "Database01_restored"

Get-AzSqlInstanceDatabase -InstanceName wfs-lower-dev -ResourceGroupName wfs-Native-dev-ManagedSql -InstanceDatabaseName FleetAtlas_WFS_NA_Dev|Select-Object *

#region upload managed instance database backup to storage account
BACKUP DATABASE Sales
TO URL = 'https://mystorageaccount.blob.core.windows.net/myfirstcontainer/Sales_20160726.bak'
WITH STATS = 5, COPY_ONLY;


#While using Database migration assistant from Azure for WFS's database migrations there was a failure due to the checksum not being enabled on the Source SQLservers.
https://support.microsoft.com/en-us/help/2656988/how-to-enable-the-checksum-option-if-backup-utilities-do-not-expose-th
Map windows logins in the database to respective Azure active directory.Ensure they have the desired UPN. So it uses your tenants custom domain name.instead of the onmicrosoft domain name.

Copy-DbaDatabase -Source sql2014 -Destination managedinstance.cus19c972e4513d6.database.windows.net -DestinationSqlCredential $cred -AllDatabases -BackupRestore -SharedPath
Copy-DbaAgentJob
Database [including views and stored procedures SPROC]
logins
agent jobs---View object details|   Create... ....new query window
Alerts operators
Linked servers
CLR libraries---Programmability--- assemblers
Database mail also supported
FileStream not supported
SSIS-----Azure SSIS in Data Factory or Use the AzSQLMI SSIS migration
SSRS---Microsoft long term roadmap to migrate directly to PowerBI
https://techcommunity.microsoft.com/t5/azure-sql-database/automate-migration-to-sql-managed-instance-using-azure/ba-p/830801
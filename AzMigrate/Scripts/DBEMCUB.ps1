Get-Website
Get-Website | Where-Object { $_.Name -eq "OEOEntry" }
<#Name         : OEOEntry
ID           : 3
State        : Started
PhysicalPath : E:\ISEA\OEOEntry
Bindings     : Microsoft.IIs.PowerShell.Framework.ConfigurationElement
#>


Get-Website | Where-Object { $_.Name -eq "DBEMCUB" }


.\Get-SiteReadiness1.ps1 -SiteName DBEMCUB -ReadinessResultsOutputPath 'Reports\DBEMCUB.json' -ServerName '<>.local' -ServerCreds $cred -Verbose

$cred     = New-Object System.Management.Automation.PSCredential "<>\<>",$(ConvertTo-SecureString '<>' -asplaintext -force)
enter-PSSession -ComputerName '<>.local' -Credential $cred -ConfigurationName 'PowerShell.7.5.2' -Verbose


.\Get-SitePackage.ps1 -SiteName DBEMCUB -ReadinessResultsFilePath 'Reports\DBEMCUB1.json'  -OutputDirectory '\Packages' -PackageResultsFileName 'DBEMCUB.json' -MigrateSitesWithIssues -Verbose


Connect-AzAccount -UseDeviceAuthentication

#[ERROR] App Service Environment fap-<>-d-c-02 doesn't exist in Subscription <>
.\Generate-MigrationSettings -SitePackageResultsPath 'E:\temp\Packages\DBEMCUB.json' -Region CentralUS -SubscriptionId '<>' `
    -ResourceGroup 'rg-<>-d-c-02' -AppServiceEnvironment 'fap-<>-d-c-02' -MigrationSettingsFilePath "E:\temp\Migration\MyMigrationSettings.json" -Verbose

.\Generate-MigrationSettings -SitePackageResultsPath 'E:\temp\Packages\DBEMCUB.json' -Region CentralUS -SubscriptionId '<>' `
    -ResourceGroup 'rg-<>-d-c-02' -MigrationSettingsFilePath "E:\temp\Migration\DBEMCUB.json" -Verbose    

.\Invoke-SiteMigration -MigrationSettingsFilePath "TemplateMigrationSettings.json"    



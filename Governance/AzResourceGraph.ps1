Install-Module -Name Az.ResourceGraph -Scope AllUsers
Import-Module Az.ResourceGraph



Get-AzResourceGraphQuery -ResourceGroupName resource-graph-queries -SubscriptionId c2d7e81b-ed6a-4de9-a4cd-36e679ec4259



$Params = @{
  Name = 'Summarize resources by location'
  ResourceGroupName = 'resource-graph-queries'
  Location = 'NorthCentralUS'
  Description = 'This shared query summarizes resources by location for a pinnable map graphic.'
  Query = 'Resources | summarize count() by location'
}
New-AzResourceGraphQuery @Params



Search-AzGraph -Query 'Resources | summarize count() by location'


Search-AzGraph -Query (Get-AzResourceGraphQuery -SubscriptionId c2d7e81b-ed6a-4de9-a4cd-36e679ec4259 -ResourceGroupName resource-graph-queries -Name 'Tenant-wide VM list with IP').Query -Verbose|ft
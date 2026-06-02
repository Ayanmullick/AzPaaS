#Create Resource Group
New-AzResourceGroup -Name $($Name='HelloBlob';$Name) -Location $($Location='NorthCentralUS';$Location) -Verbose  #Create Resource Group 
#Create App service domain

#region Storage
$Storage=New-AzStorageAccount -ResourceGroupName $Name -AccountName $Name.ToLower() -Location $Location -SkuName Standard_LRS -Verbose #create storage account
Enable-AzStorageStaticWebsite -Context $Storage.Context -IndexDocument Index.md -ErrorDocument404Path Error.HTML -Verbose  #Enable static website hosting.
Set-AzStorageBlobContent -File $(New-Item -Name Index.md -ItemType file -Value $Name) -Container `$web -Blob Index.md -Context $Storage.Context -Properties @{"ContentType" = "text/plain"} -Verbose #Upload objects to the $web container from a source directory.
#endregion

#region CDN
New-AzCdnProfile -ResourceGroupName $Name -ProfileName $Name -Location $Location -Sku Standard_Microsoft -Verbose  #CDN. create cdn profile. create cdn endpoint
$Hostname=$([System.Uri]$($Storage.PrimaryEndpoints.Web)).Host  #Getting the storage account static site endpoints
$Endpoint= New-AzCdnEndpoint -ResourceGroupName $Name -ProfileName $Name -Location $Location -EndpointName $Name -OriginName storagesite -OriginHostName $Hostname -OriginHostHeader $Hostname `
                             -IsHttpAllowed $true -HttpPort 80 -IsHttpsAllowed $true -HttpsPort 443 -OptimizationType GeneralWebDelivery -Verbose   #http needs to be allowed
#endregion

#region enable custom endpoint for DNS reference to the endpoint cname reference
New-AzDnsRecordSet -Name $Name -RecordType CNAME -ZoneName ayn.org.uk -ResourceGroupName ayan -Ttl 3600 -DnsRecords $(New-AzDnsRecordConfig -Cname "$Name.azureedge.net") -Verbose #subdomain 1 creation
Test-AzCdnCustomDomain -CdnEndpoint $Endpoint -CustomDomainHostName "$Name.ayn.org.uk" -Verbose   #validate DNS record set
New-AzCdnCustomDomain -CustomDomainName aynorguk -HostName "$Name.ayn.org.uk" -CdnEndpoint $Endpoint -Verbose   #create custom domain on CDN Profile
Enable-AzCdnCustomDomainHttps -ResourceGroupName $Name -ProfileName $Name -EndpointName $Name -CustomDomainName aynorguk -Verbose   #Configure: Custom domain HTTPS--- for both custom domains. 
#endregion

#sometimes might need to purge profile

while($($a=(Get-AzCdnCustomDomain -CdnEndpoint $Endpoint).CustomHttpsProvisioningSubstate;$a) -ne 'CertificateDeployed') {$a;Start-Sleep 30 }  #takes time to finish provisioning

#region SSL Redirection
$RuleCondition = New-AzCdnDeliveryRuleCondition -MatchVariable RequestScheme -Operator Equal -MatchValue HTTP -Verbose #set the rule condition when the action will be performed | Updated the below command with latest details
$RuleAction = New-AzCdnDeliveryRuleAction -RedirectType Moved -DestinationProtocol Https -Verbose   #Set the action what it should to once the condition is met, here we are doing http to https redirection
$policy = New-AzCdnDeliveryPolicy -Description RedirectPolicy -Rule $(New-AzCdnDeliveryRule -Name SSLRedirect -Order 1 -Condition $RuleCondition -Action $RuleAction) -Verbose  #Set the Azuer CDN delivery policy with the rule
Set-AzCdnEndpoint -CdnEndpoint $($Endpoint.DeliveryPolicy = $policy; $Endpoint) -Verbose   #$Endpoint.DeliveryPolicy = $policy |Set-AzCdnEndpoint -Verbose    #Didn't work
#Assign the delivery policy to the CDN endpoint variable  #Now call the set CDN endpoint to save the changes on the CDN endpoint
#endregion

<#
New-AzDnsRecordSet -Name $Name -RecordType CNAME -ZoneName ayn.org.uk -ResourceGroupName ayan -Ttl 3600 -DnsRecords (New-AzDnsRecordConfig -Cname "www.$Name.azureedge.net") -Verbose #subdomain 2
create cdn custom endpoint---subdomain 1
#>
#$ep = Get-AzCdnEndpoint -ResourceGroupName $Name -ProfileName $Name  -EndpointName $Name -Verbose   #get the CDN endpoint reference
<section><!--Vertical set begin comment-->
<section data-background="https://www.scarymommy.com/wp-content/uploads/2014/10/you-your-wall-street-boyfriend-24-hours-0.jpg" data-markdown>
  
```ps
#Create subscription
New-AzResourceGroup -Name $($Name='HelloBlob';$Name) -Location $($Location='NorthCentralUS';$Location) -Verbose  #Create Resource Group 
#Create App service domain
```

<details>
  <summary>Storage</summary>
   
```ps
$Storage=New-AzStorageAccount -ResourceGroupName $Name -AccountName $Name.ToLower() -Location $Location -SkuName Standard_LRS -Verbose #Create storage account
Enable-AzStorageStaticWebsite -Context $Storage.Context -IndexDocument Index.HTML -ErrorDocument404Path Error.HTML -Verbose  #Enable static website hosting.
Set-AzStorageBlobContent -File C:\Temp\Index.HTML -Container `$web -Blob Index.HTML -Context $Storage.Context -Verbose  #Upload objects to the $web container from a source directory.
```
 </details>

<details>
  <summary>CDN</summary>

```ps
New-AzCdnProfile -ResourceGroupName $Name -ProfileName $Name -Location $Location -Sku Standard_Microsoft -Verbose  #CDN. create cdn profile. create cdn endpoint
$Hostname=$([System.Uri]$($Storage.PrimaryEndpoints.Web)).Host
New-AzCdnEndpoint -ResourceGroupName $Name -ProfileName $Name -Location $Location -EndpointName $Name -OriginName storagesite -OriginHostName $Hostname -OriginHostHeader $Hostname `
                  -IsHttpAllowed $false -IsHttpsAllowed $true -HttpsPort 443 -OptimizationType GeneralWebDelivery -Verbose
```
 </details>



## Enable Custom DNS 
#DNS dns reference to the endpoint  cname reference

New-AzDnsRecordSet -Name $Name -RecordType CNAME -ZoneName ayn.org.uk -ResourceGroupName ayan -Ttl 3600 -DnsRecords (New-AzDnsRecordConfig -Cname "$Name.azureedge.net") -Verbose #subdomain 1

create cdn custom endpoint---subdomain 1
New-AzCdnCustomDomain -ProfileName $Name -EndpointName $Name  -HostName -CustomDomainName   -ResourceGroupName  -Verbose


#Configure: Custom domain HTTPS--- for both custom domains
Enable-AzCdnCustomDomainHttps -ResourceGroupName $resourceGroupName -ProfileName $profileName -EndpointName $endpointName -CustomDomainName $customDomainName



New-AzDnsRecordSet -Name $Name -RecordType CNAME -ZoneName ayn.org.uk -ResourceGroupName ayan -Ttl 3600 -DnsRecords (New-AzDnsRecordConfig -Cname "www.$Name.azureedge.net") -Verbose #subdomain 2



create cdn custom endpoint---subdomain 1



## CDN rule for SSL redirection
#then CDN https rule engine redirector

#set the rule condition when the action will be performed | Updated the below command with latest details
$RuleCondition = New-AzCdnDeliveryRuleCondition -MatchVariable 'RequestScheme' -Operator Equal -MatchValue "HTTP"

#Set the action what it should to once the condition is met, here we are doing http to https redirection
$RuleAction = New-AzCdnDeliveryRuleAction -RedirectType Moved -DestinationProtocol Https

#Set the Rule with condition and action we just created above
$Rule = New-AzCdnDeliveryRule -Name "rule1" -Order 1 -Condition $RuleCondition -Action $RuleAction

#Set the Azuer CDN delivery policy with the rule
$policy = New-AzCdnDeliveryPolicy -Description "RedirectPolicy" -Rule $Rule

#get the CDN endpoint reference
#please replace the below parameters as per the CDN endpoint details
$ep = Get-AzCdnEndpoint -ProfileName "<CDN Profile Name>" -EndpointName "<CDN Endpoint Name>" -ResourceGroupName "<Resource Group Name>"

#Assign the delivery policy to the CDN endpoint variable
$ep.DeliveryPolicy = $policy

#Now call the set CDN endpoint to save the changes on the CDN endpoint
Set-AzCdnEndpoint -CdnEndpoint $ep

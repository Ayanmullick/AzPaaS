This is an older implementation of an Azure Static Site on an Azure storage account using the older Azure Front Door CDN profile hierarchy. Front Door hierarchy has changed since then, and the script needs to be updated. 

<details>
  <summary>Resource hierarchy</summary>

```
Azure Subscription
│
├── Resource Group: HelloBlob
│   Location: NorthCentralUS
│
│   ├── Storage Account: helloblob
│   │   Type: Microsoft.Storage/storageAccounts
│   │   SKU: Standard_LRS
│   │
│   │   └── Blob Service: default
│   │       │
│   │       └── Container: $web
│   │           Static website hosting container
│   │
│   │           └── Blob: Index.md
│   │               Content: HelloBlob
│   │               Content-Type: text/plain
│   │
│   │   Static Website Configuration
│   │   ├── Index document: Index.md
│   │   ├── Error document: Error.HTML
│   │   └── Static website endpoint:
│   │       https://helloblob.<stamp>.web.core.windows.net/
│   │
│   └── CDN Profile: HelloBlob
│       Type: Microsoft.Cdn/profiles
│       SKU: Standard_Microsoft
│
│       └── CDN Endpoint: HelloBlob
│           Type: Microsoft.Cdn/profiles/endpoints
│           Default endpoint:
│           https://HelloBlob.azureedge.net/
│
│           ├── Origin: storagesite
│           │   Origin host name:
│           │   helloblob.<stamp>.web.core.windows.net
│           │
│           │   Origin host header:
│           │   helloblob.<stamp>.web.core.windows.net
│           │
│           ├── Custom Domain: aynorguk
│           │   Host name:
│           │   HelloBlob.ayn.org.uk
│           │
│           └── Delivery Policy
│               Rule: SSLRedirect
│               Condition: RequestScheme == HTTP
│               Action: 301/302-style redirect to HTTPS
│
└── Resource Group: ayan
    Existing DNS resource group referenced by script
    │
    └── Azure DNS Zone: ayn.org.uk
        Type: Microsoft.Network/dnsZones
        │
        └── CNAME Record Set: HelloBlob
            FQDN:
            HelloBlob.ayn.org.uk
            │
            └── CNAME target:
                HelloBlob.azureedge.net

```

</details>


<details>
  <summary>Resource inventory table</summary>

```
| Layer              | Resource                 | Name in script | Parent scope        | Notes                                          |
| ------------------ | ------------------------ | -------------: | ------------------- | ---------------------------------------------- |
| Management         | Resource group           |    `HelloBlob` | Subscription        | Main deployment container                      |
| Storage            | Storage account          |    `helloblob` | `HelloBlob` RG      | Static website source                          |
| Storage data plane | Static website container |         `$web` | Storage account     | Created when static website hosting is enabled |
| Storage data plane | Blob                     |     `Index.md` | `$web` container    | Uploaded by `Set-AzStorageBlobContent`         |
| Edge/CDN           | CDN profile              |    `HelloBlob` | `HelloBlob` RG      | `Standard_Microsoft` classic CDN SKU           |
| Edge/CDN           | CDN endpoint             |    `HelloBlob` | CDN profile         | Public endpoint is `HelloBlob.azureedge.net`   |
| Edge/CDN           | Origin                   |  `storagesite` | CDN endpoint        | Points to storage static website host          |
| Edge/CDN           | Custom domain            |     `aynorguk` | CDN endpoint        | Maps `HelloBlob.ayn.org.uk`                    |
| DNS                | DNS zone                 |   `ayn.org.uk` | `ayan` RG           | Existing zone, not created by this script      |
| DNS                | CNAME record             |    `HelloBlob` | DNS zone            | Points custom host to CDN endpoint             |
| Edge/CDN config    | HTTPS cert binding       | Managed by CDN | Custom domain       | Triggered by `Enable-AzCdnCustomDomainHttps`   |
| Edge/CDN config    | Delivery rule            |  `SSLRedirect` | CDN endpoint policy | Redirects HTTP to HTTPS                        |


```

</details>


<details>
  <summary>Request flow</summary>

```
User browser
   │
   ▼
https://HelloBlob.ayn.org.uk
   │
   ▼
Azure DNS CNAME
HelloBlob.ayn.org.uk → HelloBlob.azureedge.net
   │
   ▼
Azure CDN Endpoint
HelloBlob.azureedge.net
   │
   ▼
CDN Origin: storagesite
helloblob.<stamp>.web.core.windows.net
   │
   ▼
Storage Static Website
$web container / Index.md
```

</details>



 <a href="https://www.youtube.com/watch?v=X-aWDBpmjEc" target="_blank"><img style="float: right;" src="https://res.cloudinary.com/marcomontalbano/image/upload/v1585614943/video_to_markdown/images/youtube--X-aWDBpmjEc-c05b58ac6eb4c4700831b2b3070cd403.jpg" alt="HelloBlob" width="300" height="180" border="5" /></a>

```ps
#Create subscription
New-AzResourceGroup -Name $($Name='HelloBlob';$Name) -Location $($Location='NorthCentralUS';$Location) -Verbose  #Create Resource Group 
#Create App service domain
```

<details>
  <summary>Storage</summary>
   
```ps
$Storage=New-AzStorageAccount -ResourceGroupName $Name -AccountName $Name.ToLower() -Location $Location -SkuName Standard_LRS -Verbose #create storage account
Enable-AzStorageStaticWebsite -Context $Storage.Context -IndexDocument Index.md -ErrorDocument404Path Error.HTML -Verbose  #Enable static website hosting.
Set-AzStorageBlobContent -File $(New-Item -Name Index.md -ItemType file -Value $Name) -Container `$web -Blob Index.md -Context $Storage.Context -Properties @{"ContentType" = "text/plain"} -Verbose #Upload objects to the $web container from a source directory.
```
 </details>

<details>
  <summary>CDN</summary>

```ps
New-AzCdnProfile -ResourceGroupName $Name -ProfileName $Name -Location $Location -Sku Standard_Microsoft -Verbose  #CDN. create cdn profile. create cdn endpoint
$Hostname=$([System.Uri]$($Storage.PrimaryEndpoints.Web)).Host  #Getting the storage account static site endpoints
$Endpoint= New-AzCdnEndpoint -ResourceGroupName $Name -ProfileName $Name -Location $Location -EndpointName $Name -OriginName storagesite -OriginHostName $Hostname -OriginHostHeader $Hostname `
                             -IsHttpAllowed $true -HttpPort 80 -IsHttpsAllowed $true -HttpsPort 443 -OptimizationType GeneralWebDelivery -Verbose   #http needs to be allowed
```
 </details>

<details>
  <summary>Custom endpoint for DNS reference to the endpoint cname reference</summary>

```ps
New-AzDnsRecordSet -Name $Name -RecordType CNAME -ZoneName ayn.org.uk -ResourceGroupName ayan -Ttl 3600 -DnsRecords $(New-AzDnsRecordConfig -Cname "$Name.azureedge.net") -Verbose #subdomain 1 creation
Test-AzCdnCustomDomain -CdnEndpoint $Endpoint -CustomDomainHostName "$Name.ayn.org.uk" -Verbose   #validate DNS record set
New-AzCdnCustomDomain -CustomDomainName aynorguk -HostName "$Name.ayn.org.uk" -CdnEndpoint $Endpoint -Verbose   #create custom domain on CDN Profile
Enable-AzCdnCustomDomainHttps -ResourceGroupName $Name -ProfileName $Name -EndpointName $Name -CustomDomainName aynorguk -Verbose   #Configure: Custom domain HTTPS--- for both custom domains. 
```
 </details>

```ps
#sometimes might need to purge profile
while($($a=(Get-AzCdnCustomDomain -CdnEndpoint $Endpoint).CustomHttpsProvisioningSubstate;$a) -ne 'CertificateDeployed') {$a;Start-Sleep 30 }  #takes time to finish provisioning
```

<details>
  <summary>SSL Redirection</summary>

```ps
$RuleCondition = New-AzCdnDeliveryRuleCondition -MatchVariable RequestScheme -Operator Equal -MatchValue HTTP -Verbose #set the rule condition when the action will be performed | Updated the below command with latest details
$RuleAction = New-AzCdnDeliveryRuleAction -RedirectType Moved -DestinationProtocol Https -Verbose   #Set the action what it should to once the condition is met, here we are doing http to https redirection
$policy = New-AzCdnDeliveryPolicy -Description RedirectPolicy -Rule $(New-AzCdnDeliveryRule -Name SSLRedirect -Order 1 -Condition $RuleCondition -Action $RuleAction) -Verbose  #Set the Azuer CDN delivery policy with the rule
Set-AzCdnEndpoint -CdnEndpoint $($Endpoint.DeliveryPolicy = $policy; $Endpoint) -Verbose   #$Endpoint.DeliveryPolicy = $policy |Set-AzCdnEndpoint -Verbose    #Didn't work
#Assign the delivery policy to the CDN endpoint variable  #Now call the set CDN endpoint to save the changes on the CDN endpoint
```
 </details>


 <details>
  <summary>New  Azure Front Door Standard/Premium hierarchy</summary>

```
Front Door Profile
└── Endpoint
    ├── Route
    ├── Origin Group
    │   └── Origin: Storage static website endpoint
    ├── Custom Domain
    └── Rule Set
```

 </details>
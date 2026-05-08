<#This is the application gateway deployment for the re-platforming test with public domain WAF setup and Azure public certificate as well. 
The public domain and it was public DNS zone were created from the portal. There isn't a Powershell cmd to do that and there are many backend 3rd party automation. Eg. the domain is created with Wild West Domains.
Invoke-AzRequest can get cumbersome. PFB domain details.

Domain:  '<>AzTest.org' 
Org:     '<>-Information-Services'
Address: <>
Owner:   Ayan.Mullick@<>


It's the same with the App service certificate which is issued by Digicert.


These two app service related SPN's needed to be given appropriate RBAC on the Key Vault.
Microsoft.Azure.CertificateRegistration  
Microsoft Azure App Service  ed2abea2-979e-409c-9403-346522482234
#>

$NameSuffix = ($Name, $Env, $Loc, $Sr = 'migrate', 'd', 'c', '01') -join '-'

$RG     = Get-AzResourceGroup 'rg-cicdpoc-d-c-01'
$Params = @{ Location = 'CentralUS'; ResourceGroupName = $RG.ResourceGroupName }
$Vnet   = Get-AzVirtualNetwork -Name 'vnet-test-cicd-poc' -ResourceGroupName $RG.ResourceGroupName

$Pip = New-AzPublicIpAddress -Name ('pip-' + $NameSuffix) @Params -Sku Standard -AllocationMethod Static


$HostName     = '<>aztest.org'              # listener hostname (SNI)

$Uami = New-AzUserAssignedIdentity -Name ('uami-' + $NameSuffix) @Params
# Attach identity on create
$appGwIdentity = New-AzApplicationGatewayIdentity -UserAssignedIdentity $Uami.Id  # :contentReference[oaicite:1]{index=1}

$kv = Get-AzKeyVault -VaultName 'kv-test-d-c-01'
New-AzRoleAssignment -ObjectId $Uami.PrincipalId -RoleDefinitionName 'Key Vault Secrets User' -Scope $kv.ResourceId


# Versionless secret ID => auto-rotation
$secret   = Get-AzKeyVaultSecret -VaultName $kv.VaultName -Name '<>aztestcert22d59113-2f8e-438d-b93b-3666cfdb3f98'
$secretId = $secret.Id.Replace($secret.Version, "")                     # :contentReference[oaicite:2]{index=2}

# --- AppGW building blocks (HTTPS-only, no port 80 anywhere) ---
#$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $Vnet -Name $SubnetName
$gip    = New-AzApplicationGatewayIPConfiguration    -Name ('agw-ip-'   + $NameSuffix) -Subnet $Vnet.Subnets[1]
$fip    = New-AzApplicationGatewayFrontendIPConfig   -Name ('agw-feip-' + $NameSuffix) -PublicIPAddress $Pip
$fp443  = New-AzApplicationGatewayFrontendPort       -Name ('fe-https-' + $NameSuffix) -Port 443
$cert   = New-AzApplicationGatewaySslCertificate     -Name ('cert-'     + $NameSuffix) -KeyVaultSecretId $secretId  # v2 + KV cert for listener :contentReference[oaicite:3]{index=3}
$bhs    = New-AzApplicationGatewayBackendHttpSetting -Name ('bhs-https-'+ $NameSuffix) -Port 443 -Protocol Https -CookieBasedAffinity Disabled -RequestTimeout 30
$pool   = New-AzApplicationGatewayBackendAddressPool -Name ('pool-'     + $NameSuffix)  # used by the rule; add backends later

$lis443 = New-AzApplicationGatewayHttpListener -Name ('lis-https-' + $NameSuffix) -Protocol Https -FrontendIpConfiguration $fip -FrontendPort $fp443 `
           -SslCertificate $cert -HostName $HostName -RequireServerNameIndication $true  # :contentReference[oaicite:4]{index=4}

$rule   = New-AzApplicationGatewayRequestRoutingRule -Name ('rule-https-' + $NameSuffix) -RuleType Basic -Priority 100 -HttpListener $lis443 -BackendAddressPool $pool -BackendHttpSettings $bhs

#Add custom health probe

$sku    = New-AzApplicationGatewaySku -Name Standard_v2 -Tier Standard_v2 -Capacity 1 

# --- Create HTTPS-only gateway (no HTTP listener, no port 80) ---
New-AzApplicationGateway -Name ('agw-' + $NameSuffix) @Params -Identity $appGwIdentity -SslCertificates $cert  -RequestRoutingRules $rule -Sku $sku -EnableHttp2 `
  -GatewayIpConfigurations $gip -FrontendIpConfigurations $fip -FrontendPorts $fp443 -HttpListeners $lis443 -BackendAddressPools $pool -BackendHttpSettingsCollection $bhs

  
#region upgrade to WAFv2
# Policy settings: enable + Prevention mode
$polSettings  = New-AzApplicationGatewayFirewallPolicySetting -State Enabled -Mode Prevention   # blocks, not just logs

# Choose ONE managed ruleset. Recommended: Microsoft Default Rule Set (DRS) 2.1
$managedSet   = New-AzApplicationGatewayFirewallPolicyManagedRuleSet -RuleSetType "Microsoft_DefaultRuleSet" -RuleSetVersion "2.1"

$managedRules = New-AzApplicationGatewayFirewallPolicyManagedRule -ManagedRuleSet $managedSet

$WafPolicy    = New-AzApplicationGatewayFirewallPolicy -Name ('wafpol-' + $NameSuffix) @Params -PolicySetting $polSettings -ManagedRule $managedRules
# DRS 2.1 is the current recommended managed ruleset for App Gateway WAF; OWASP 3.2 is also supported on WAF_v2. :contentReference[oaicite:1]{index=1}


#Parameter set limitations do not allow the usage of the identity parameter along with the WAF policy parameter during the app gateway creation. So one needs to upgrade afterwards. 
$gw = Get-AzApplicationGateway  -ResourceGroupName $RG.ResourceGroupName
$gw.Sku = New-AzApplicationGatewaySku -Name WAF_v2 -Tier WAF_v2 -Capacity 1
$gw.FirewallPolicy = $WafPolicy        # <-- attach policy here
Set-AzApplicationGateway -ApplicationGateway $gw
#endregion


$gw = Get-AzApplicationGateway  -ResourceGroupName 'rg-cicdpoc-d-c-01'
Stop-AzApplicationGateway -ApplicationGateway $gw
Start-AzApplicationGateway -ApplicationGateway $gw






#region Add another certificate
# Get the secret ID from Key Vault
$secret = Get-AzKeyVaultSecret -VaultName 'kv-test-d-c-01' -Name 'cert-mcub-d-c-01d1d2a6eb-3257-435f-84e2-59bf2250fdf6'
$secretId = $secret.Id.Replace($secret.Version, "") # Remove the secret version so Application Gateway uses the latest version in future syncs
# Specify the secret ID from Key Vault 
Add-AzApplicationGatewaySslCertificate -KeyVaultSecretId $secretId -ApplicationGateway $gw -Name $secret.Name
# Commit the changes to the Application Gateway
Set-AzApplicationGateway -ApplicationGateway $gw 
#endregion


<#DNS record changed Cname pointing to .azurewebsites.net to A record pointing to App gw pip
Changed backend pool to webapp public ip instead of app service

#>


#TLS protocol version check
Get-AzApplicationGateway -ResourceGroupName <> -Name <> | Get-AzApplicationGatewaySslPolicy|fl *

#region Create a self-signed certificate locally that can be uploaded the AppGw
New-SelfSignedCertificate -certstorelocation cert:\localmachine\my -dnsname www.contoso.com
$Pswd = ConvertTo-SecureString -String "<>" -Force -AsPlainText
Export-PfxCertificate -cert cert:\localMachine\my\83677C1365568FF4A1D10CA9E82CA770A5BDCA1C -FilePath c:\temp\appgwcert.pfx -Password $Pswd  #Use Thumbprint from the previous command

# If you need it as a CER file
#$cert = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq '83677C1365568FF4A1D10CA9E82CA770A5BDCA1C' }
#Export-Certificate -Cert $cert -FilePath 'c:\temp\appgwcert.cer'
#endregion

Register-AzProviderFeature -FeatureName AllowApplicationGatewayBasicSku -ProviderNamespace Microsoft.Network -Verbose
Get-AzProviderFeature -FeatureName AllowApplicationGatewayBasicSku -ProviderNamespace Microsoft.Network
#region AppGw Creation with SSL termination and backend authentication
$Name           = 'Redr'
$Params         = @{Location = 'CentralUS'; Verbose=$true}
$RG             = New-AzResourceGroup @Params -Name ($Name+'RG') -Tag @{Division='Enterprise'; Environment='Dev'; AppName= 'Network'; Owner= 'Ayan Mullick';}
$Params        += @{ResourceGroupName  = $RG.ResourceGroupName }

$MSI            = New-AzUserAssignedIdentity -Name ($Name+'MSI') @Params

# Create key vault with RBAC enabled and with user assigned identity
$KeyVault       = New-AzKeyVault -VaultName ($Name+'KV') @Params -Sku Premium -EnableRbacAuthorization #-EnableSoftDelete -EnablePurgeProtection 
New-AzRoleAssignment -Scope $KeyVault.ResourceId -ObjectId $MSI.PrincipalId -RoleDefinitionName 'Key Vault Administrator'
New-AzRoleAssignment -Scope $KeyVault.ResourceId -SignInName ayan.mullick@<> -RoleDefinitionName 'Key Vault Administrator'  
# Generate a new certificate in the Key Vault
$CertPolicy     = New-AzKeyVaultCertificatePolicy -SubjectName "CN=www.contoso.com" -IssuerName Self -ValidityInMonths 12 -RenewAtNumberOfDaysBeforeExpiry 30
Add-AzKeyVaultCertificate -VaultName $KeyVault.VaultName -Name ($Name+'Cert') -CertificatePolicy $CertPolicy


#Create network resources
$SubnetConfigs  = @{Backend = '10.0.1.0/24'; AGSubnet = '10.0.2.0/24'}.GetEnumerator() | ForEach-Object {New-AzVirtualNetworkSubnetConfig -Name $_.Key -AddressPrefix $_.Value}
$Vnet           = New-AzVirtualNetwork -Name ($Name+'VN') @Params -AddressPrefix 10.0.0.0/16 -Subnet $SubnetConfigs 
$Pip            = New-AzPublicIpAddress -Name ($Name+'Pip') @Params -AllocationMethod Static -Sku Standard 

#Create the IP configurations and frontend port
$Gipconfig      = New-AzApplicationGatewayIPConfiguration -Name AGIPConfig -Subnet $Vnet.Subnets[0]
$Fipconfig      = New-AzApplicationGatewayFrontendIPConfig -Name AGFrontendIPConfig -PublicIPAddress $pip
$FrontendPort   = New-AzApplicationGatewayFrontendPort -Name FrontendPort -Port 443
#Create the backend pool and backend HTTP settings
$DefaultPool    = New-AzApplicationGatewayBackendAddressPool -Name BackendPool 
$PoolSettings   = New-AzApplicationGatewayBackendHttpSettings -Name PoolSettings -Port 80 -Protocol Http -CookieBasedAffinity Enabled -RequestTimeout 120


# Retrieve Certificate as Secret |SSL Certificate for SSL termination(Reference Key Vault Secret)
$keyVaultSecret = Get-AzKeyVaultSecret -VaultName $KeyVault.VaultName -Name ($Name+'Cert')
$Cert           = New-AzApplicationGatewaySslCertificate -Name ($Name+'Cert') -KeyVaultSecretId $keyVaultSecret.Id
#$cert           = New-AzApplicationGatewaySslCertificate -Name appgwcert -CertificateFile "c:\temp\appgwcert.pfx" -Password $Pswd  #If using local certificate

# Trusted root certificate for backend authentication
#https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-end-to-end-ssl-powershell#create-an-application-gateway-configuration-object
#The certificate provided in the previous step should be the public key of the .pfx certificate present on the back end.
#$trustedRootCert = New-AzApplicationGatewayTrustedRootCertificate -Name "TrustedRootCert" -CertificateFile "c:\temp\redrcert.cer" #-Password "<>" #Needs a CER file.

$Certificate    = Get-AzKeyVaultCertificate -VaultName $KeyVault.VaultName -Name ($Name+'Cert') 
#[System.IO.File]::WriteAllBytes("C:\\temp\\CertificateD.cer", $certificate.Certificate.RawData) 

$TempPath       = [System.IO.Path]::Combine($env:TEMP, "Certificate.cer")
[System.IO.File]::WriteAllBytes($tempPath, $certificate.Certificate.RawData)
$TrustedRootCert= New-AzApplicationGatewayTrustedRootCertificate -Name "TrustedRootCert" -CertificateFile $TempPath

#Create the HTTP listener and request routing rule
$DefaultListener= New-AzApplicationGatewayHttpListener -Name HttpsListener -Protocol Https -FrontendIPConfiguration $fipconfig -FrontendPort $frontendPort -SslCertificate $cert
$FrontendRule   = New-AzApplicationGatewayRequestRoutingRule -Name Rule1 -RuleType Basic -HttpListener $defaultListener -BackendAddressPool $defaultPool -BackendHttpSettings $poolSettings -Priority 100

#TLS policy to be used
$SSLPolicy      = New-AzApplicationGatewaySSLPolicy -MinProtocolVersion TLSv1_2 -CipherSuite "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256", "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384", "TLS_RSA_WITH_AES_128_GCM_SHA256" -PolicyType Custom

#Create the application gateway
$AGwIdentity    = New-AzApplicationGatewayIdentity -UserAssignedIdentity $MSI.Id
$Sku            = New-AzApplicationGatewaySku -Name Basic -Tier Basic -Capacity 1

$AppGw          = New-AzApplicationGateway -Name ($Name+'AGw') @Params -Identity $AGwIdentity -BackendAddressPools $DefaultPool -BackendHttpSettingsCollection $PoolSettings -FrontendIpConfigurations $Fipconfig `
                    -GatewayIpConfigurations $Gipconfig -FrontendPorts $FrontendPort -HttpListeners $DefaultListener -RequestRoutingRules $FrontendRule -Sku $Sku -SslCertificates $cert -SSLPolicy $SSLPolicy `
                    -TrustedRootCertificate $TrustedRootCert -EnableHttp2
#endregion

#region Add the HTTP port and Listener
#$AppGw = Get-AzApplicationGateway -Name RedrAGw -ResourceGroupName <>
Add-AzApplicationGatewayFrontendPort -Name HttpPort -Port 80 -ApplicationGateway $AppGw
$fp             = Get-AzApplicationGatewayFrontendPort -Name HttpPort -ApplicationGateway $AppGw
Add-AzApplicationGatewayHttpListener -Name HTTPListener -Protocol Http -FrontendPort $fp -FrontendIPConfiguration $Fipconfig -ApplicationGateway $AppGw

#Add the REDIRECT configuration
Add-AzApplicationGatewayRedirectConfiguration -Name HttpToHttps -RedirectType Permanent -TargetListener $defaultListener -IncludePath $true -IncludeQueryString $true -ApplicationGateway $appgw

#Add the request routing rule
$HTTPListener   = Get-AzApplicationGatewayHttpListener -Name HTTPListener -ApplicationGateway $appgw
$RedirectConfig = Get-AzApplicationGatewayRedirectConfiguration -Name HttpToHttps -ApplicationGateway $AppGw
Add-AzApplicationGatewayRequestRoutingRule -Name Rule2 -RuleType Basic -HttpListener $HTTPListener -RedirectConfiguration $RedirectConfig -ApplicationGateway $AppGw -Priority 200
Set-AzApplicationGateway -ApplicationGateway $AppGw
#endregion
#This does a hello world static web app deployment using only PowerShell without any CICD, directly from a local folder. 
#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources, Az.Websites

#region Configuration
$ErrorActionPreference = 'Stop'

$Name, $Location = 'HelloSwa', 'CentralUS'
$ResourceGroupName, $StaticWebAppName = $Name, $Name.ToLower()
$SkuName, $ContentApiVersion = 'Free', 'v1'

$ScriptRoot = $PSScriptRoot ? $PSScriptRoot : (Get-Location).Path
$ZipPath = Join-Path $ScriptRoot "$StaticWebAppName-app-$(Get-Date -Format 'yyyyMMddHHmmss').zip"   #'C:\temp\'
#endregion Configuration

#region Content Request
function Invoke-SwaContentRequest {
    param([Parameter(Mandatory)] [string] $Path, [object] $Body)

    $Uri = "https://$ContentHost$Path`?apiVersion=$ContentApiVersion&deploymentCorrelationId=$DeploymentCorrelationId"
    $Headers = @{ Authorization = "token $DeploymentToken"; 'User-Agent' = 'staticsites-custom-powershell-client' }
    $Json = ($null -eq $Body) ? '' : ($Body | ConvertTo-Json -Depth 20)
    $Envelope = Invoke-RestMethod -Method POST -Uri $Uri -Headers $Headers -ContentType 'application/json' -Body $Json

    if ($Envelope.StatusCode -ne 200) {
        throw "Static Web Apps content service rejected '$Path'. StatusCode: $($Envelope.StatusCode). Reason: $($Envelope.ErrorMessage)"
    }

    $Envelope.Response
}
#endregion Content Request

#region Azure Resources
$Context = (Get-AzContext) ?? (throw 'Run Connect-AzAccount before running this script.')

$Params = @{ ResourceGroupName = $ResourceGroupName; Location = $Location }
$StaticSiteParams = @{ Name = $StaticWebAppName; SkuName = $SkuName; StagingEnvironmentPolicy = 'Enabled'; AllowConfigFileUpdate = $true }

New-AzResourceGroup @Params
$StaticSite = New-AzStaticWebApp @Params @StaticSiteParams   #Get-AzStaticWebApp -ResourceGroupName HelloSwa
#endregion Azure Resources

#region Site Package
$IndexFile = New-Item -Path (Join-Path $ScriptRoot 'index.html') -ItemType File -Force -Value '<h1>hello SWA8</h1>'
Compress-Archive -Path $IndexFile.FullName -DestinationPath $ZipPath -Force
#endregion Site Package

#region Direct Deployment
#region Deployment Token
$Secret = Get-AzStaticWebAppSecret -ResourceGroupName $ResourceGroupName -Name $StaticWebAppName
$DeploymentToken = $Secret.Property['apiKey']

if ([string]::IsNullOrWhiteSpace($DeploymentToken)) {throw 'Could not read Static Web App deployment token from Get-AzStaticWebAppSecret output.'}
#endregion Deployment Token

#region Content Endpoint
$Prefix, $Suffix = $DeploymentToken.Split('-', 2)
$Slice = ($Prefix.Length -gt 64) ? ([int] $Prefix.Substring(64)) : 0
$RegionId = [Convert]::ToInt32($Suffix.Substring(36, 3), 16)

if ($RegionId -ne 16)              {throw "Expected a CentralUS Static Web App deployment token with region id 16. Actual region id: $RegionId."}
if ($Slice -lt 0 -or $Slice -gt 7) {throw "Could not map CentralUS Static Web App deployment token to a content distribution endpoint. Slice: $Slice."}

$ContentHost = ($Slice -eq 0) ? 'content-dm1.infrastructure.azurestaticapps.net' : "content-dm1.infrastructure.$Slice.azurestaticapps.net"
$DeploymentCorrelationId = [guid]::NewGuid().ToString()
#endregion Content Endpoint

#region Upload Metadata
$EventInfo = @{
    RepoUrl = ''; IsPullRequest = $false; IsNamedEnvironment = $false; PullRequestId = ''; PullRequestTitle = ''
    HeadBranch = 'main'; BaseBranch = 'main'; EnvironmentName = ''; TenantId = $Context.Tenant.Id
    DefaultHostname = $StaticSite.DefaultHostname; Slice = $Slice
}
$Validation = Invoke-SwaContentRequest -Path '/api/upload/validateapitoken' -Body $EventInfo
$DefaultHostname = $Validation.SiteUrl ? $Validation.SiteUrl : $StaticSite.DefaultHostname

$UploadInfo = @{
    TotalAppSizeInBytes = $IndexFile.Length; MaxSingleFileSizeInBytes = $IndexFile.Length; AppFileCount = 1
    ApiSizeInBytes = 0; HasFunctions = $false; HasDataApiFiles = $false; HasDataApiConfigFile = $false
    DatabaseType = ''; HasRoutes = $false; Status = 'RequestingUpload'; ConfiguredRoles = @(); DefaultFileType = 'index.html'
    ServerRenderFramework = 'StaticWebApp'; DeploymentProvider = 'Custom'; BackendStartupCommandType = 0
    ShouldDeployToWebApp = $false; TenantId = $Context.Tenant.Id; DefaultHostname = $DefaultHostname; Slice = $Slice
}
#endregion Upload Metadata

#region Upload Request
$UploadRequest = Invoke-SwaContentRequest -Path '/api/upload/request' -Body @{ EventInfo = $EventInfo; UploadInfo = $UploadInfo; PollingInfo = $null }

if (-not $UploadRequest.PackageUris.App) {throw 'Static Web Apps content service did not return an app package upload URI.'}

$PollingInfo = $UploadRequest.PollingInfo
Add-Member -InputObject $PollingInfo -NotePropertyName Slice -NotePropertyValue ($PollingInfo.Slice ?? $Slice) -Force

$StatusBody = @{ EventInfo = $EventInfo; UploadInfo = $UploadInfo; PollingInfo = $PollingInfo }
#endregion Upload Request

#region Package Upload
$ZipFile = Get-Item -Path $ZipPath
Write-Verbose "Uploading app package '$($ZipFile.Name)' ($('{0:N2}' -f ($ZipFile.Length / 1KB)) KB)." -Verbose

$UploadResponse = Invoke-WebRequest -Method PUT -Uri $UploadRequest.PackageUris.App -InFile $ZipPath -Headers @{ 'x-ms-blob-type' = 'BlockBlob' } -ContentType 'application/zip'
$UploadInfo['Status'] = 'Succeeded'
Write-Verbose "Package upload completed. HTTP status: $($UploadResponse.StatusCode)." -Verbose

Write-Verbose 'Notifying Static Web Apps that package upload succeeded.' -Verbose
Invoke-SwaContentRequest -Path '/api/upload/updatestatus' -Body $StatusBody
Write-Verbose 'Static Web Apps accepted the package upload status.' -Verbose
#endregion Package Upload

#region Deployment Status
$DeploymentDeadline = (Get-Date).AddMinutes(10)
do {
    $Deployment = Invoke-SwaContentRequest -Path '/api/upload/checkstatus' -Body $PollingInfo
    if ($Deployment.DeploymentStatus -ne 'InProgress') { break }
    Start-Sleep -Seconds 15
} while ((Get-Date) -lt $DeploymentDeadline)

if ($Deployment.DeploymentStatus -eq 'Failed')     {throw "Static Web App deployment failed. $($Deployment.ErrorDetails)"}
if ($Deployment.DeploymentStatus -eq 'InProgress') {throw 'Static Web App deployment did not finish within 10 minutes.'}
#endregion Deployment Status
#endregion Direct Deployment

#region Output
$SiteUrl = $Deployment.SiteUrl ? $Deployment.SiteUrl : (($DefaultHostname -match '^https?://') ? $DefaultHostname : "https://$DefaultHostname")
$SiteUrl
#endregion Output

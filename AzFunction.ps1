New-AzAppServicePlan -Name test15678 -Location eastus -ResourceGroupName test -Tier Y1 -Verbose
New-AzFunctionAppPlan -Location $Location -ResourceGroupName $RG.ResourceGroupName -Name Mx-ASP-Personalizer-Dev-002 -Sku EP1 -WorkerType Windows -Verbose

#Creates Consumption tier app
New-AzFunctionApp -OSType Windows -Runtime PowerShell -ResourceGroupName test -Name test15678 -StorageAccountName test5678 -PlanName test15678 -SubscriptionId c2d7e81b-ed6a-4de9-a4cd-36e679ec4259 -DisableApplicationInsights
#One is unable to create a consumption tier Functionappplan using powershell to adhere to a naming  convention for the App service

#region Function app had to be created manually
New-AzAppServicePlan -Location $Location -Name ASP-Ztech-$Env-001 -ResourceGroupName $RG.ResourceGroupName -Tier Y1 -Verbose

New-AzFunctionAppPlan -Location $Location -ResourceGroupName $RG.ResourceGroupName -Name ASP-Ztech-$Env-001 -Sku EP1 -WorkerType Windows -Verbose

#Didn't work
New-AzFunctionApp -ResourceGroupName $RG.ResourceGroupName -Name Func-Ztech-$Env-001 -PlanName ASP-Ztech-$Env-001 -OSType Windows -Runtime PowerShell -StorageAccountName $SA.StorageAccountName -DisableApplicationInsights -Verbose

New-AzFunctionApp -SubscriptionId <> -ResourceGroupName $RG.ResourceGroupName -StorageAccountName $SA.StorageAccountName -PlanName ASP-Ztech-$Env-001 -Name Func-Ztech-$Env-001 -OSType Windows `
            -Runtime PowerShell -RuntimeVersion 7.0 -DisableApplicationInsights -FunctionsVersion 3  #didn't work
#endregion

#Function app cannot be deployed to a free or a shared tier app service plan. And a consumption tier plan does not work properly with added dependencies like Azure or Graph modules .
#To do graph or azure operations inside a function the lowest tier was the basic one tier . 
#Only the graph permission assignment to a user managed identity needed to be done using Powershell graph application module . 

#region V2: create consumption tier function application with user managed identity and CI CD configured with a GitHub repository . 
$Name,$Env,$Location = 'New','Test5','NorthCentralUS'
$RG                  = New-AzResourceGroup -Location $Location -Name ($Name+$Env+'RG')
$Params              = @{ResourceGroupName  = $RG.ResourceGroupName; Location = $Location; Verbose=$true } 

$SA                  = New-AzStorageAccount @Params -Name $($Name+$Env+'SA').ToLower() -SkuName Standard_LRS -AccessTier Hot -Kind StorageV2 -EnableHttpsTrafficOnly 1
$Identity            = New-AzUserAssignedIdentity @Params -Name ($Name+$Env+'I')

New-AzAppServicePlan @Params -Name ($Name+$Env+'ASP') -Tier Y1   #Works if you  don't specify the plan name while creating the Function app
New-AzFunctionApp @Params -Name ($Name+$Env+'FA') -StorageAccount $SA.StorageAccountName -SubscriptionId <> -OSType Windows -Runtime PowerShell -FunctionsVersion 3 -RuntimeVersion 7.0 `
                -IdentityType UserAssigned -IdentityID $Identity.Id -DisableApplicationInsights -AppSetting @{PSWorkerInProcConcurrencyUpperBound = 10; FUNCTIONS_WORKER_PROCESS_COUNT = 10}


#Then created a new project in the AzFunctions VSC extension. And push the project from VSC to GitHub. And then configure Deployment center on the Azure portal for the Function App
#Then Sync the repo on VSC and the GitHub Actions workflow yml shows up

#https://github.com/marketplace/actions/azure-functions-action#end-to-end-workflow| 'uses: Azure/functions-action@v1'   version. Specifying the main version is enough to use the latest version
#https://github.com/actions/checkout|  'actions/checkout@v2' version

#Enable HTTPS for AzFunctions
$app = Get-AzWebApp -ResourceGroupName $RG.ResourceGroupName
#$app.SiteConfig.AlwaysOn = $true
$app.SiteConfig.Use32BitWorkerProcess = $false
$app.HttpsOnly= $true
$app.SiteConfig.Http20Enabled= $true
$app | Set-AzWebApp

#endregion



#region V3: create consumption tier function application with user managed identity
function Get-Suffix {
    $ast        = ([System.Management.Automation.Language.Parser]::ParseInput($MyInvocation.Line, [ref]$null, [ref]$null)).EndBlock.Statements[0]
    $pipeline   = $ast.left ? $ast.right.PipelineElements : $ast.PipelineElements
    $commandName= $pipeline[0].commandElements[0].Value
    $command    = $ExecutionContext.InvokeCommand.GetCommand($commandName, 'All') ?? {throw "Command not found: $commandName"}
    
    $command.Noun.TrimStart('A') -creplace '[^A-Z]'
                    }
#$AzParams = @{Location = 'NorthCentralUS'; $Name = { "Func" + (Get-Suffix) }; Verbose= $true}  #The function needs to be invoked during the cmdlet execution. This approach didn't work.  
#$NameScriptBlock = { "Func" + (Get-Suffix) }; $RG = New-AzResourceGroup @AzParams -Name (& $NameScriptBlock)
$AzParams       = @{Location = 'NorthCentralUS'; Verbose=$true}
$RG             = New-AzResourceGroup @AzParams -Name ('Func' + (Get-Suffix))
$AzParams      += @{ResourceGroupName  = $RG.ResourceGroupName }

$Identity       = New-AzUserAssignedIdentity @AzParams -Name ('Func' + (Get-Suffix))
New-AzAppServicePlan @AzParams -Name ('Func' + (Get-Suffix)) -Tier Y1

$FuncParams     = @{FunctionsVersion = '4'; OSType = 'Windows'; Runtime = 'PowerShell'; RuntimeVersion = '7.4'}
$AppSetting     = @{AppSetting = @{PSWorkerInProcConcurrencyUpperBound = 10; FUNCTIONS_WORKER_PROCESS_COUNT = 10} }
$Identity       = @{IdentityType = 'UserAssigned'; IdentityID = $Identity.Id}
$Storage        = @{StorageAccount = '<>'; ApplicationInsightsName = '<>'; ApplicationInsightsKey= '<>'}
New-AzFunctionApp @AzParams -Name Ayan  @FuncParams @AppSetting @Identity @Storage

$properties     = @{httpsOnly = $true; minTlsVersion= '1.2'
    siteConfig  = @{http20Enabled = $true; use32BitWorkerProcess = $false; webSocketsEnabled = $false; alwaysOn = $false;   
                    cors = @{allowedOrigins = @("https://portal.azure.com"); supportCredentials = $false}
                  }
                }
Set-AzResource -PropertyObject $properties -ResourceGroupName $RG.ResourceGroupName -ResourceType Microsoft.Web/sites -ResourceName Ayan -Force -Verbose # Update the Function App with the additional configurations

#User managed identity federation for GitHub CICD setup
#https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust-user-assigned-managed-identity?pivots=identity-wif-mi-methods-powershell
#endregion


#region Check settings
$Func = Get-AzWebApp -ResourceGroupName FuncRG
$Func.SiteConfig
$Func.SiteConfig.AppSettings
$Func.SiteConfig.Cors
$Func.SiteConfig.Http20Enabled


$Func = Get-AzFunctionApp -ResourceGroupName FuncRG
$Func.ApplicationSettings
$Func.SiteConfig

Get-AzFunctionAppSetting -Name Ayan -ResourceGroupName FuncRG
Update-AzFunctionAppSetting -Name Ayan -ResourceGroupName FuncRG -AppSetting @{PSWorkerInProcConcurrencyUpperBound = '3'; FUNCTIONS_WORKER_PROCESS_COUNT = '3'} -Verbose #still didn't work

Remove-AzFunctionAppSetting -ResourceGroupName FuncRG -Name Ayan -AppSettingName FUNCTIONS_WORKER_PROCESS_COUNT -Verbose
Restart-AzFunctionApp -ResourceGroupName FuncRG -Name Ayan -Force -Verbose
#endregion




#region CICD setup
<#Created a GitHub repo
Connected Function to repo from Function Deployment center in the Azure portal
Deployment failed-- Unable to find: Made repo public
Deployment failed-- Login failed: Added Function public settings to repo secret, AZURE_FUNCTIONAPP_PUBLISH_PROFILE
Deployment failed-- Login failed: User managed identity federated credential subject mismatch. Updated subject
        issuer - https://token.actions.githubusercontent.com
        subject claim - repo:Ayanmullick/AzFunction:ref:refs/heads/main
Deployment succeeded
Made repo private. Deployment fails : Unable to find.
Had to create a finegrained PAT with 'Content' and 'MetaData' read\write access and reference it in the Actions YML.

#>
New-AzFederatedIdentityCredentials -ResourceGroupName FuncRG -IdentityName FuncUAI -Name FuncUaiGaFc -Issuer 'https://token.actions.githubusercontent.com' -Subject 'repo:Ayanmullick/AzFunction:ref:refs/heads/main'

#GitHub Action much more optimized now. It just uses the Publish settings. No PAT needed for private repo too.

#endregion


#region I had to run below cmds to ensure the modules were installed. Just configuring the requirements.psd didn't work on the consumption tier.
Install-Module Az -Verbose
Install-Module Microsoft.Graph -Verbose  #run sequentially

$env:PSModulePath -split ';'

Get-Module -ListAvailable
#endregion


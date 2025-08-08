Get-AzureRmConsumptionUsageDetail

$inv=Get-AzureRmBillingInvoice -Latest
Invoke-WebRequest -Uri $inv.downloadurl -outfile ('c:\billing\' + $inv.name + '.pdf')



#Create Subscription
Install-Module Az.Billing -Verbose
Install-Module Az.Subscription -AllowPrerelease -Verbose

Get-AzEnrollmentAccount  #One needs to be added in the Accounts tab in the EA portal

https://azure.microsoft.com/en-in/offers/ms-azr-0003p/
purchase payG

#sign up for  an enterprise subscription.  This creates your Azure profile in the back end

New-AzSubscription -OfferType MS-AZR-0017P -Name "Dev Team Subscription" -EnrollmentAccountObjectId <enrollmentAccountObjectId> -OwnerObjectId <userObjectId1>,<servicePrincipalObjectId>


New-AzSubscription -OfferType MS-AZR-0017P -Name AzSQL_PoC -EnrollmentAccountObjectId '<>' -OwnerObjectId '<>' -Verbose

#region create budget for resource group
#Part 1 – create an action group with the email recipient who will receive the budget notifications / emails. (This section only works on an EA subscription)

$email1 = New-AzActionGroupReceiver ` -EmailAddress username@doman.com -Name AppCosts01
$ActionGroupId = (Set-AzActionGroup -ResourceGroupName resourcegroupname01 ` -Name AppCosts01 -ShortName AppCosts01 -Receiver $email1).Id

#Part 2 – create the budget on the resource group
new-AzConsumptionBudget -ResourceGroupName resourcegroupname01 -Amount 100 ` -Name AppCosts01 ` -Category Cost ` -TimeGrain Monthly ` -StartDate 2022-11-01 `
    -EndDate 2030-05-31 ` -ContactEmail username@doman.com -NotificationKey Key1 ` -NotificationThreshold 10 -NotificationEnabled -ContactGroup $ActionGroupId



#region: v2
# Define variables
$resourceGroupName   = (Get-AzResourceGroup -Name '<>').ResourceGroupName
$budgetName, $amount = "AdoOrgMonthlyBudget", 100

$Day1 = Get-Date -Day 1
$BudgetPeriodParams  = @{StartDate = $Day1.ToString("yyyy-MM-dd"); EndDate= $Day1.AddYears(1).ToString("yyyy-MM-dd"); TimeGrain = "Monthly"}

$NotificationParams  = @{NotificationKey = "ForecastedCost"; NotificationThreshold= 80; NotificationEnabled= $true; ContactEmail= '<>'}

New-AzConsumptionBudget -ResourceGroupName $resourceGroupName -Name $budgetName -Amount $amount -Category Cost @BudgetPeriodParams @NotificationParams -Verbose

#endregion


#region: v3  | #Start date should be the first date of the month |# Budget is valid for 1 year
$Day1   = Get-Date -Day 1
$Budget = @{ TimeGrain = "Monthly"; Category = "Cost"; StartDate = $Day1.ToString("yyyy-MM-dd"); EndDate = $Day1.AddYears(1).ToString("yyyy-MM-dd")}
$Notify = @{ NotificationKey = "ForecastedCost"; NotificationThreshold = 80; NotificationEnabled = $true; ContactEmail = "<>"; Verbose = $true }
New-AzConsumptionBudget -ResourceGroupName $RG.ResourceGroupName -Name ('MonthBudget-' + $NameSuffix) -Amount 300 @Budget @Notify
#endregion

#endregion


#region Get cost by resource group
Get-AzConsumptionUsageDetail -ResourceGroup TemplateTest -StartDate 2023-07-01 -EndDate 2023-07-31  #Details each resource cose for each day for one month
Get-AzConsumptionUsageDetail -ResourceGroup TemplateTest -StartDate 2023-07-01 -EndDate 2023-07-31| Measure-Object PretaxCost -Sum #Resource group total
#By resource group. Worked
Get-AzResourceGroup|select -First 50 -Property ResourceGroupName,
@{n='Cost';e={[Math]::Round((Get-AzConsumptionUsageDetail -ResourceGroup $PSItem.ResourceGroupName -StartDate 2023-07-01 -EndDate 2023-07-31| Measure-Object PretaxCost -Sum).Sum,0)}}|
        FT -AutoSize
#endregion

#Cost for one VM 
Get-AzConsumptionUsageDetail -ResourceGroup TemplateTest -BillingPeriodName 20230901 -InstanceName centos| Measure-Object PretaxCost -Sum #BillingPeriodName corresponds to the month. Sept. 2023


Get-AzSupportTicket
Get-AzSupportService|select * -First 5|ft
Get-AzSupportProblemClassification -ServiceId "/providers/Microsoft.Support/services/484e2236-bc6d-b1bb-76d2-7d09278cf9ea"

Get-AzSupportTicketCommunication -SupportTicketName 2105130040000956|fl



#region submit support ticket for Cosmos quota
$subId   = (Get-AzContext).Subscription.Id

#https://learn.microsoft.com/en-us/azure/cosmos-db/create-support-request-quota-increase
# 2) Find the Cosmos DB service (ServiceId used in the ticket)
# Tip: Run Get-AzSupportService to list all services and pick the one whose DisplayName includes 'Cosmos'
$cosmosService = Get-AzSupportService |
                 Where-Object { $_.DisplayName -like "*Cosmos*" } |
                 Select-Object -First 1

if (-not $cosmosService) { throw "Azure Cosmos DB service not found via Get-AzSupportService." }

#Get-AzSupportService|? DisplayName -Match 'cosmos'

# 3) List problem classifications for Cosmos and pick a 'quota' classification
# Look for something like: "Service and subscription limits (quotas)" or "Quota increase"
$pcs = Get-AzSupportProblemClassification -ServiceName $cosmosService.Name
$cosmosQuotaPC = $pcs | Where-Object { $_.DisplayName -match "(quota|limits)" } | Select-Object -First 1

#Get-AzSupportProblemClassification -ServiceName 'd9516a10-74b5-45f4-943d-a5281d7cf1bb'|? DisplayName -Match 'quota'

if (-not $cosmosQuotaPC) {
  Write-Warning "Couldn't auto-detect a quota problem classification. Review the list below and set $cosmosQuotaPC manually."
  $pcs | Select DisplayName, Name
  # Example: $cosmosQuotaPC = $pcs | Where-Object { $_.DisplayName -eq "Service and subscription limits (quotas)" }
}

# 4) Create the support ticket (Cosmos DB quota increase)
# Fill these with your details:
$title       = "Cosmos DB quota increase request"
$description = @"
Requesting a quota increase for Azure Cosmos DB.
Subscription: $subId
Account(s): <your-account-names>
Region(s):  <your-target-region(s)>
Requested change: <describe the quota you need—e.g., higher max RU/s per database/container, enable new region, temporary logical partition size increase, etc.>
Business impact: <brief impact statement>
"@

# Contact details (required)
$firstName   = "<FirstName>"
$lastName    = "<LastName>"
$country     = "USA"
$primaryEmail= "<you@contoso.com>"
$phone       = "<+1-xxx-xxx-xxxx>"
$language    = "en-US"           # preferred support language
$timeZone    = "Central Standard Time"  # or your preferred TZ

# Severity: minimal | moderate | critical (adjust to your situation)
$severity    = "moderate"

# Create the ticket. Important: Use ServiceId and ProblemClassificationId obtained above.
$ticketName = "cosmos-quota-" + ([System.Guid]::NewGuid().ToString("N")).Substring(0,8)

New-AzSupportTicket `
  -Name                          $ticketName `
  -SubscriptionId                $subId `
  -Title                         $title `
  -Description                   $description `
  -ServiceId                     $cosmosService.Id `
  -ProblemClassificationId       $cosmosQuotaPC.Id `
  -Severity                      $severity `
  -ContactDetailFirstName        $firstName `
  -ContactDetailLastName         $lastName `
  -ContactDetailCountry          $country `
  -ContactDetailPrimaryEmailAddress $primaryEmail `
  -ContactDetailPhoneNumber      $phone `
  -ContactDetailPreferredSupportLanguage $language `
  -ContactDetailPreferredTimeZone $timeZone `
  -ContactDetailPreferredContactMethod "email"


#endregion

<#
After putting the firewall in prevention mode, there was some content being blocked. 
We had to enable diagnostics for the application gateway and then query the logs that were being blocked in prevention mode to identify a pattern. 
For our pattern, it ended up that we should create a custom rule instead of an exclusion. 
Exclusions are more preferable but they can only be created for headers and cookies, etc. In this case, we had to create a custom rule for the URI path. 
#>


<# KQL queries
AGWFirewallLogs
|summarize count() by RuleId,DetailedData,RequestUri


AGWFirewallLogs
|summarize count() by RuleId,DetailedData,RequestUri,TransactionId
#>


# --- Inputs you can tweak ---  #Untested
$rg          = "rg-cicdpoc-d-c-01"
$policyName  = "wafpol-migrate-d-c-01"     # your existing WAF policy name
$ruleName    = "AllowAxd"                  # matches your screenshot
$priority    = 100

# 1) Build the match variable: RequestUri
$var = New-AzApplicationGatewayFirewallMatchVariable -VariableName RequestUri

# 2) Build the condition: RequestUri contains ".axd" (no negation, no transform)
$cond = New-AzApplicationGatewayFirewallCondition -MatchVariable $var -Operator Contains -MatchValue ".axd" -NegationCondition:$false    # "is" (not "is not")

# 3) Build the custom rule: MatchRule + Allow
$rule = New-AzApplicationGatewayFirewallCustomRule -Name $ruleName -Priority $priority -RuleType MatchRule -MatchCondition $cond-Action Allow

# 4) Attach to existing WAF policy and save
$pol = Get-AzApplicationGatewayFirewallPolicy -Name $policyName -ResourceGroupName $rg
$pol.CustomRules += $rule
Set-AzApplicationGatewayFirewallPolicy -InputObject $pol

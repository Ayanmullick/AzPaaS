Get-AzConfig | Format-Table Key,Value
<#
Key                           Value
---                           -----
CheckForUpgrade                True
DefaultSubscriptionForLogin
DisableInstanceDiscovery      False
DisplayBreakingChangeWarning   True
DisplayRegionIdentified        True
DisplaySecretsWarning          True
DisplaySurveyMessage           True
EnableDataCollection           True
EnableErrorRecordsPersistence False
EnableLoginByWam               True
LoginExperienceV2                On
#>

#Ran to remove old contexts
Get-AzContext -ListAvailable|? Name -match 'national'|Remove-AzContext -Verbose
Get-AzContext -ListAvailable|? Name -match 'wfs'|Remove-AzContext -Verbose
Get-AzContext -ListAvailable|? Name -match 'microsoft'|Remove-AzContext -Verbose
Get-AzContext -ListAvailable|? Name -match 'hot'|Remove-AzContext -Verbose
Get-AzContext -ListAvailable|? Account -match 'metc'|Remove-AzContext -Verbose

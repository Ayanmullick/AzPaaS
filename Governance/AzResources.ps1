Get-AzureRmLocation | sort Location | Select Location




New-AzureRmRoleAssignment -SignInName '<>@<>.com' -RoleDefinitionName 'Billing Reader' -ResourceGroupName '<RG>'   #RBAc script--

Set-AzResourceLock -LockLevel CanNotDelete -LockName 'InfraReportingDontDelete' -Scope '/subscriptions/<>/resourceGroups/<>' -LockNotes 'Infra Report RG. Dont delete' -Verbose



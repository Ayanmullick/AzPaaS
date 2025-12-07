$verbosePreference = "Continue"
Register-AzResourceProvider -ProviderNamespace 'Microsoft.Quota'

$subId = (Get-AzContext).Subscription.Id
$scope = "subscriptions/$subId/providers/Microsoft.Network/locations/northcentralus"
Get-AzQuota -Scope $scope
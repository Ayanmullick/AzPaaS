# Get the Web Apps solution in the Migrate project
$Solution = Get-AzMigrateSolution -MigrateProjectName "<migrate-project-name>" -ResourceGroupName "<rg-name>"

<#
Get-AzMigrateSolution -ResourceGroupName 'rg-migrate-p-c-01' -Name '<>Webapps' -MigrateProjectName '<>Webapps'
Error: Get-AzMigrateSolution_Get: Solution name '<>Webapps' cannot be found.
#>

# Filter to Web Apps solution
$WebAppSolution = $Solution | Where-Object { $_.Detail.SolutionType -like "*WebApp*" }

# Get the assessment resource ID
$AssessmentId = $WebAppSolution.Detail.extendedDetails.assessmentResourceId

# Pull details via generic resource cmdlet
Get-AzResource -ResourceId $AssessmentId -ExpandProperties

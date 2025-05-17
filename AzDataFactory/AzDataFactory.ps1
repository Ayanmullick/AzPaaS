New-AzResourceGroup -Location SouthCentralUS -Name ADFtest -Verbose


Set-AzDataFactoryV2 -Location SouthCentralUS -ResourceGroupName ADFtest -Name GblADFtest -Verbose
 

 
Get-AzDataFactoryV2 -ResourceGroupName rg-adftest-d-c-01 | fl *
Get-AzDataFactoryV2IntegrationRuntime -ResourceGroupName rg-adftest-d-c-01 -DataFactoryName df-adftest-d-c-01 -Name AzureintegrationRuntime2| fl
Get-AzDataFactoryV2LinkedService -ResourceGroupName rg-adftest-d-c-01 -DataFactoryName df-adftest-d-c-01
Get-AzDataFactoryV2Dataset -ResourceGroupName rg-adftest-d-c-01 -DataFactoryName df-adftest-d-c-01


Get-AzDataFactoryV2DataFlow -ResourceGroupName rg-adftest-d-c-01 -DataFactoryName df-adftest-d-c-01 -Name Blob2BlobCsv|fl


#Didn't work
Invoke-AzDataFactoryV2Pipeline -ResourceGroupName rg-adftest-d-c-01 -DataFactoryName df-adftest-d-c-01 -PipelineName Invoke-AzDataFactoryV2Pipeline -Verbose


#Didn't work
Get-AzDataFactoryV2PipelineRun -ResourceGroupName rg-adftest-d-c-01 -DataFactoryName df-adftest-d-c-01 -PipelineRunId 'd73c4d4d-9979-4789-aa69-d480d0a3705d'  
Get-AzDataFactoryV2TriggerRun -ResourceGroupName rg-adftest-d-c-01 -DataFactoryName df-adftest-d-c-01 -TriggerName Blob2BlobCsvPipeline -TriggerRunStartedAfter "2017-09-01" -TriggerRunStartedBefore "2025-09-30"
Get-AzDataFactoryV2ActivityRun -ResourceGroupName rg-adftest-d-c-01 -DataFactoryName df-adftest-d-c-01 -RunStartedAfter '2025-02-19' -RunStartedBefore '2025-02-21' -PipelineRunId e272ebd0-8d3d-4076-85da-0d3753ee48d1


#No cmdlet for Managed private endpoints
[CmdletBinding(DefaultParameterSetName = "Local")]
param(
    [Parameter(Mandatory, ParameterSetName = "Remote")]
    [string]$ServerName,

    [Parameter(Mandatory, ParameterSetName = "Remote")]
    [PSCredential]$ServerCreds,

    [Parameter()]
    [string]$ReadinessResultsOutputPath,

    [Parameter()]
    [switch]$OverwriteReadinessResults,

    [Parameter()]
    [string]$SiteName
)

Import-Module (Join-Path $PSScriptRoot "MigrationHelperFunctions.psm1")

$ScriptConfig = Get-ScriptConfig
$ReadinessResultsPath = $ScriptConfig.DefaultReadinessResultsFilePath
$AssessedSites = New-Object System.Collections.ArrayList 

Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Started script" -EventType "action" -ErrorAction SilentlyContinue

if ($ReadinessResultsOutputPath) {
    $ReadinessResultsPath = $ReadinessResultsOutputPath
}

if ((Test-Path $ReadinessResultsPath) -and !$OverwriteReadinessResults) {
    Write-HostError -Message  "$ReadinessResultsPath already exists. Use -OverwriteReadinessResults to overwrite $ReadinessResultsPath"
    exit 1
}  

$SiteList = New-Object System.Collections.ArrayList

try {   
    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
    $CheckResxFile = (Join-Path $PSScriptRoot "WebAppCheckResources.resx")
    $CheckResourceSet = New-Object -TypeName 'System.Resources.ResXResourceSet' -ArgumentList $CheckResxFile
} catch {
    $ExceptionData = Get-ExceptionData -Exception $_.Exception
    Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Exception getting ResXResourceSet" -ExceptionData $ExceptionData -EventType "error" -ErrorAction SilentlyContinue
    Write-HostError -Message "Error in getting check description strings : $($_.Exception.Message)"    
}

try {  
    Write-HostInfo -Message "Scanning for site readiness/compatibility..."      
    $discoveryScript = Join-Path $PSScriptRoot "IISDiscovery.ps1"
    if($ServerName) {
        Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Discovery type" -EventMessage "Remote" -EventType "info" -ErrorAction SilentlyContinue
        try {       
            $dataString = Invoke-Command -FilePath $discoveryScript -ArgumentList $true -ComputerName $ServerName -Credential $ServerCreds -ErrorVariable invokeError -ErrorAction SilentlyContinue                         
            if($invokeError) {
                Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Error getting remote readiness results" -EventMessage "invoke" -EventType "error" -ErrorAction SilentlyContinue
                Write-HostError -Message "Error getting remote readiness data: $($invokeError[0])" 
                exit 1
            }
        } catch {
            $ExceptionData = Get-ExceptionData -Exception $_.Exception   
            Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Error getting remote readiness results" -EventMessage "exception" -ExceptionData $ExceptionData -EventType "error" -ErrorAction SilentlyContinue
            Write-HostError -Message "Error getting remote readiness data: $($_.Exception.Message)"
            exit 1
        }
    } else {    
        Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Discovery type" -EventMessage "Local" -EventType "info" -ErrorAction SilentlyContinue      
        $dataString = &($discoveryScript) -aggressiveBlocking $true
    }

    try {
        $discoveryAndAssessmentData = $dataString | ConvertFrom-Json
        if($discoveryAndAssessmentData.error) {
            Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Discovery Error" -EventMessage $discoveryAndAssessmentData.error.errorId -EventType "error" -ErrorAction SilentlyContinue
            Write-HostError -Message "Error occurred retrieving IIS server data, issue was: $($discoveryAndAssessmentData.error.errorId): $($discoveryAndAssessmentData.error.detailedMessage)"
            exit 1
        }
    } catch {
        Write-HostError -Message "Error with reading readiness data. Data was in unexpected format. $($_.Exception.Message)"
        exit 1
    }

    $targetSites = if ($SiteName) {
        $discoveryAndAssessmentData.readinessData.IISSites | Where-Object { $_.webAppName -ieq $SiteName }
    } else {
        $discoveryAndAssessmentData.readinessData.IISSites
    }

    if (-not $targetSites) {
        Write-HostError -Message "No matching site found with name: $SiteName"
        exit 1
    }

    Write-HostInfo -Message "Assessing site(s): $($targetSites.webAppName -join ', ')"

    foreach ($Report in $targetSites) {
        $WarningChecks = New-Object System.Collections.ArrayList
        $FailedChecks = New-Object System.Collections.ArrayList
        $FatalErrorFound = $false

        Write-HostInfo -Message "Report generated for $($Report.webAppName)" 

        foreach ($Check in $Report.checks) {            
            $detailsString = ""; 
            if($Check.PSObject.Properties.Name -contains "Details") {
                if($Check.Details.Count -gt 0) { 
                    $detailsString = $Check.Details[0]; 
                }
                $Check.PSObject.Properties.Remove('Details');
            }                           
            if(-not($Check.PSObject.Properties.Name -contains "detailsString")) {                                   
                Add-Member -InputObject $Check -MemberType NoteProperty -Name detailsString -Value $detailsString                               
            }

            $Check | Add-Member -MemberType NoteProperty -Name Status -Value $Check.result
            $Check.PSObject.Properties.Remove('result')

            if ($CheckResourceSet) {         
                $Check | Add-Member -MemberType NoteProperty -Name Description -Value $CheckResourceSet.GetString("$($Check.IssueId)Title")
                $formattedDetailsMessage = $CheckResourceSet.GetString("$($Check.IssueId)Description") -f $detailsString
                $Check | Add-Member -MemberType NoteProperty -Name Details -Value $formattedDetailsMessage 
                $Check | Add-Member -MemberType NoteProperty -Name Recommendation -Value $CheckResourceSet.GetString("$($Check.IssueId)Recommendation")
                $Check | Add-Member -MemberType NoteProperty -Name MoreInfoLink -Value $CheckResourceSet.GetString("$($Check.IssueId)MoreInformationLink")
            }

            if ($Check.Status -eq "Warn") {
                [void]$WarningChecks.Add($Check)
                Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Warning Check" -EventType "info" -EventMessage "$($Check.IssueId)" -ErrorAction SilentlyContinue
            }
            else {
                [void]$FailedChecks.Add($Check)
                Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Failed Check" -EventType "info" -EventMessage "$($Check.IssueId)" -ErrorAction SilentlyContinue
            }
        }

        if ($WarningChecks) {
            Write-HostWarn -Message "Warnings for $($Report.webAppName): $($WarningChecks.IssueId -join  ',')"
        }    
        if ($FailedChecks.Count -eq 0) {
            Write-HostInfo -Message "$($Report.webAppName): No Blocking issues found and the site is ready for migration to Azure!"
            if ($WarningChecks) { 
                Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Overall Status" -EventMessage "ConditionallyReady" -EventType "info" -ErrorAction SilentlyContinue
            } else {
                Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Overall Status" -EventMessage "Ready" -EventType "info" -ErrorAction SilentlyContinue
            }
        }
        else {
            $FailedFatalChecksString = ""
            $FatalChecks = $ScriptConfig.FatalChecks

            foreach ($FailedCheck in $FailedChecks) {
                if ($FatalChecks.Contains($FailedCheck.IssueId)) {
                    $FailedFatalChecksString += $FailedCheck.IssueId + ", "
                    $FatalErrorFound = $true                    
                }
            }

            Write-HostWarn -Message "Failed Checks for $($Report.webAppName) : $($FailedChecks.IssueId -join  ',')"
            
            if ($FatalErrorFound) {
                $FailedFatalChecksString = $FailedFatalChecksString.TrimEnd(',')
                Write-HostWarn -Message "FATAL errors detected in $($Report.webAppName) : $FailedFatalChecksString"
                Write-HostWarn -Message "These failures prevent migration using this tooling. You will not be able to migrate this site until the checks resulting in fatal errors are fixed"   
                Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Overall Status" -EventMessage "Blocked" -EventType "info" -ErrorAction SilentlyContinue
            } else {
                Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Overall Status" -EventMessage "NotReady" -EventType "info" -ErrorAction SilentlyContinue
            }
        }           

        $discoveryData = $discoveryAndAssessmentData.discoveryData.IISSites | Where-Object {$_.webAppName -eq $Report.webAppName} | Select-Object -First 1
        $appPoolInfo = $discoveryData.applications | Where-Object {$_.path -eq "/"} | Select-Object -First 1

        $Site = New-Object PSObject
        Add-Member -InputObject $Site -MemberType NoteProperty -Name SiteName -Value $Report.webAppName
        Add-Member -InputObject $Site -MemberType NoteProperty -Name FatalErrorFound -Value $FatalErrorFound
        Add-Member -InputObject $Site -MemberType NoteProperty -Name FailedChecks -Value $FailedChecks
        Add-Member -InputObject $Site -MemberType NoteProperty -Name WarningChecks -Value $WarningChecks
        Add-Member -InputObject $Site -MemberType NoteProperty -Name ManagedPipelineMode -Value $appPoolInfo.managedPipelineMode
        Add-Member -InputObject $Site -MemberType NoteProperty -Name Is32Bit -Value $appPoolInfo.enable32BitAppOnWin64
        Add-Member -InputObject $Site -MemberType NoteProperty -Name NetFrameworkVersion -Value $appPoolInfo.managedRuntimeVersion
        Add-Member -InputObject $Site -MemberType NoteProperty -Name VirtualApplications -Value $discoveryData.virtualApplications

        [void]$AssessedSites.Add($Site)

        Write-Host ""
    }

    try {
        $AssessedSites | ConvertTo-Json -Depth 10 | Out-File (New-Item -Path $ReadinessResultsPath -ItemType "file" -ErrorAction Stop -Force)
    } catch {
        Write-HostError -Message "Error outputting readiness results files: $($_.Exception.Message)" 
        Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Error in creating readiness results file" -EventType "error" -ErrorAction SilentlyContinue
        exit 1
    }

    Write-HostInfo -Message "Readiness checks complete. Readiness results outputted to $ReadinessResultsPath"
    return $ReadinessResultsPath  

} catch {
    $ExceptionData = Get-ExceptionData -Exception $_.Exception
    Write-HostError -Message "Error in generating Readiness results : $($_.Exception.Message)"
    Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Error in generating Readiness results" -ExceptionData $ExceptionData -EventType "error" -ErrorAction SilentlyContinue
}

Send-TelemetryEventIfEnabled -TelemetryTitle "Get-SiteReadiness.ps1" -EventName "Script end" -EventType "action" -ErrorAction SilentlyContinue

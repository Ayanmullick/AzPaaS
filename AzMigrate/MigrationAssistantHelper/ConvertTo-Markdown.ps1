$json = Get-Content .\OEOEntry.json -Raw | ConvertFrom-Json

function Escape-Markdown {
    param ([string]$Text)
    return ($Text -replace '\|', '&#124;') -replace '\r?\n', ' '
}

function Convert-ToMarkdown {
    param ([array]$Checks)

    $table = @(
        "| IssueId | Status | Description | Details | Recommendation | MoreInfoLink |",
        "|---------|--------|-------------|---------|----------------|---------------|"
    )

    foreach ($check in $Checks) {
        $issue = Escape-Markdown $check.IssueId
        $status = Escape-Markdown $check.Status
        $desc = Escape-Markdown $check.Description
        $details = Escape-Markdown $check.Details
        $recommendation = Escape-Markdown $check.Recommendation
        $link = Escape-Markdown $check.MoreInfoLink

        $table += "| $issue | $status | $desc | $details | $recommendation | $link |"
    }

    return $table -join "`n"
}

# Summary Section
$summary = @"
# Readiness Assessment: $($json.SiteName)

- **Framework**: $($json.NetFrameworkVersion)
- **32-bit Enabled**: $($json.Is32Bit)
- **Managed Pipeline Mode**: $($json.ManagedPipelineMode)
- **Fatal Errors Found**: $($json.FatalErrorFound)
"@

# Combine All
$failed = Convert-ToMarkdown $json.FailedChecks
$warning = Convert-ToMarkdown $json.WarningChecks

$markdown = "$summary`n## ❌ Failed Checks`n$failed`n`n## ⚠️ Warning Checks`n$warning"

# Write to Markdown file
$markdown | Out-File .\OEOEntry.md -Encoding utf8

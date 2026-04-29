# Readiness Assessment: OEOEntry

- **Framework**: v4.0
- **32-bit Enabled**: True
- **Managed Pipeline Mode**: Integrated
- **Fatal Errors Found**: False
## ❌ Failed Checks
| IssueId | Status | Description | Details | Recommendation | MoreInfoLink |
|---------|--------|-------------|---------|----------------|---------------|
| AppPoolIdentityCheck | Fail | Azure App Service does not support using the LocalSystem or SpecificUser application pool identity types. | The site's application pool is running as an unsupported user identity type: SpecificUser (OEODBEService) | Set the Application pool to run as ApplicationPoolIdentity. | https://go.microsoft.com/fwlink/?linkid=2154702 |

## ⚠️ Warning Checks
| IssueId | Status | Description | Details | Recommendation | MoreInfoLink |
|---------|--------|-------------|---------|----------------|---------------|
| ConfigConnectionStringsCheck | Warn | Web configuration files may contain connection string secrets | The following connectionStrings were found in web configuration files: DefaultConnection (/OEOEntry), DBEConn (/OEOEntry), UnfinalizedPayments (/OEOEntry), Payments (/OEOEntry), DBEInstanceTable (/OEOEntry), dbeinstance_pay (/OEOEntry), Reporting_OEODBE (/OEOEntry), OEO_DBEConnectionString (/OEOEntry), Reporting_Oracle (/OEOEntry), Reporting_PSFin (/OEOEntry), OEOData.Properties.Settings.OEO_DBEConnectionString (/OEOEntry), OEOData.Properties.Settings.DBE_CONNECTION (/OEOEntry), OEOData.Properties.Settings.ConnectionString (/OEOEntry) | Avoid storing application secrets such as database credentials in configuration files and consider updating to use Azure app setting environment variables or integration with Key Vault. | https://go.microsoft.com/fwlink/?linkid=2247759 |

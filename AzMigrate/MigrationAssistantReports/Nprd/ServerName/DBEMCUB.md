# Readiness Assessment: DBEMCUB

- **Framework**: v4.0
- **32-bit Enabled**: True
- **Managed Pipeline Mode**: Integrated
- **Fatal Errors Found**: False
## ❌ Failed Checks
| IssueId | Status | Description | Details | Recommendation | MoreInfoLink |
|---------|--------|-------------|---------|----------------|---------------|
| LocationTagCheck | Fail | Migration method does not support moving location path configuration in applicationHost.config. | The following location paths were found in the applicationHost.config file: DBEMCUB | The noted applicationHost.config location tag configuration may not be persisted during migration. Move the location path configuration to either the site's root web.config file, or to a web.config file associated with the specific application to which they apply. | https://go.microsoft.com/fwlink/?linkid=2154707 |

## ⚠️ Warning Checks
| IssueId | Status | Description | Details | Recommendation | MoreInfoLink |
|---------|--------|-------------|---------|----------------|---------------|
| ConfigConnectionStringsCheck | Warn | Web configuration files may contain connection string secrets | The following connectionStrings were found in web configuration files: ConnectionString2 (/DBEMCUB), DBE_Connection (/DBEMCUB) | Avoid storing application secrets such as database credentials in configuration files and consider updating to use Azure app setting environment variables or integration with Key Vault. | https://go.microsoft.com/fwlink/?linkid=2247759 |

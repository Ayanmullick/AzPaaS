#region Create the database and populate a table in AzPostgreSQL
CREATE DATABASE tutorialdb;


-- Drop the table if it already exists
DROP TABLE IF EXISTS customers;
-- Create a new table called 'customers'
CREATE TABLE customers(
    customer_id SERIAL PRIMARY KEY,
    name VARCHAR (50) NOT NULL,
    location VARCHAR (50) NOT NULL,
    email VARCHAR (50) NOT NULL
);

-- Insert rows into table 'customers'
INSERT INTO customers
    (customer_id, name, location, email)
 VALUES
   ( 1, 'Orlando', 'Australia', ''),
   ( 2, 'Keith', 'India', 'keith0@adventure-works.com'),
   ( 3, 'Donna', 'Germany', 'donna0@adventure-works.com'),
   ( 4, 'Janet', 'United States','janet1@adventure-works.com');


-- Select rows from table 'customers'
SELECT * FROM customers;
#endregion


ipmo PostgreSQLCmdlets


Connect-PostgreSQL  -User '<>' -Password '<>' -Database tutorialdb -Server postgresqlatt.postgres.database.azure.com -Port 5432 -Verbose



Connect-PostgreSQL -AuthScheme Password -User ayan -Password '<>' -Server postgresqlatt.postgres.database.azure.com -Port 5432 -Database tutorialdb -Logfile 'C:/Temp/AzPosgreSQL-error.log' -Verbosity '3' -Verbose


$postgresql = Connect-PostgreSQL  -User "$User" -Password "$Password" -Database "$Database" -Server "$Server" -Port "$Port"
$shipcountry = "USA"
$orders = Select-PostgreSQL -Connection $postgresql -Table "Orders" -Where "ShipCountry = `'$ShipCountry`'"
$orders

#Worked. need to add -UseSSL
$postgresql= Connect-PostgreSQL  -User '<>' -Password '<>' -Database tutorialdb -Server postgresqlatt.postgres.database.azure.com -Port 5432 -RTK '<>' -Verbose -UseSSL
Select-PostgreSQL -Connection $postgresql -Table customers



New-AzADServicePrincipal -ApplicationId '5657e26c-cc92-45d9-bc47-9da6cfdb4ed9' -Verbose #Per private preview documentation. https://github.com/kabharati/AAD-Flex/blob/main/Private%20Preview%20Prerequisites%20and%20Limitations
<#VERBOSE: Performing the operation "New-AzADServicePrincipal_CreateExpanded" on target "Call remote 'ServicePrincipalsServicePrincipalCreateServicePrincipal' operation".

DisplayName                                                  Id                                   AppId
-----------                                                  --                                   -----
Azure OSSRDBMS PostgreSQL Flexible Server AAD Authentication 7c3f14ac-3fe9-4f03-bcc3-77602356b5c6 5657e26c-cc92-45d9-b…
#>


Connect-PostgreSQL -AuthScheme AzureAD -AzureTenant '<>'  -User 'ayan@<>' -Password '<>' -Database tutorialdb -Server postgresqlnus.postgres.database.azure.com -Port 5432 -RTK '<>' -Verbose -UseSSL

Connect-PostgreSQL -AuthScheme AzureAD -AzureTenant '<>'  -User 'ayan@<>' -Database tutorialdb -Server postgresqlnus.postgres.database.azure.com -Port 5432 -RTK '<>' -Verbose -UseSSL -OAuthAccessToken $(Get-AzAccessToken -ResourceUrl https://ossrdbms-aad.database.windows.net).token
#Error: Connect-PostgreSQL: [500] Server error [SQL state: 28P01]: password authentication failed for user "ayan@<>@postgresqlnus". Connection was forcibly closed

Connect-PostgreSQL -AuthScheme 'AzureAD' -UseSSL -AzureTenant '<>' -Server postgresqlnus.postgres.database.azure.com -User 'ayan@<>' -Database tutorialdb -InitiateOAuth 'GETANDREFRESH' -CallbackURL 'http://localhost:33333' -Port 5432 -RTK '<>' -Verbose
#Error: Connect-PostgreSQL: [500] Server error [SQL state: 28P01]: password authentication failed for user "ayan@<>@postgresqlnus". Connection was forcibly closed



Connect-PostgreSQL -AuthScheme AzurePassword -UseSSL -Server postgresqlnus.postgres.database.azure.com -User '<>' -Database tutorialdb -InitiateOAuth 'GETANDREFRESH' -Password '<>' -RTK '<>' -Verbose
#Error: Connect-PostgreSQL: [500] Server error [SQL state: 28P01]: password authentication failed for user "<>@postgresqlnus". Connection was forcibly closed


Connect-PostgreSQL -AuthScheme 'AzureAD' -UseSSL -Server postgresqlnus.postgres.database.azure.com -User 'ayan@<>' -Database tutorialdb -InitiateOAuth 'GETANDREFRESH' -CallbackURL 'http://localhost:33333' -RTK '<>' -Verbose

Connect-PostgreSQL -AuthScheme AzurePassword -UseSSL -Server postgresqlnus.postgres.database.azure.com -User '<>' -Database tutorialdb -InitiateOAuth GETANDREFRESH -Password '<>' -RTK '<>' -Logfile C:/Temp/AzPosgreSQL-error.log -Verbosity 5 -Verbose

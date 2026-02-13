#region Create with Entra Kerberos auth for SMB
$verbosePreference = 'Continue'
$Name,$Location = 'EntraAzFiles','NorthCentralUS'
$RG             = New-AzResourceGroup -Name ($Name + 'RG') -Location $Location
$Params         = @{ Location = $Location; ResourceGroupName = $RG.ResourceGroupName }

#'FileStorage' kind creates premium performance account only. One needs to use general storage account for standard performance.
$FilesParams    = @{ Name = ($Name.ToLower()+'1'); SkuName = 'Premium_LRS'; Kind = 'FileStorage' }                           #The storage account named entraazfiles is already taken. (Parameter 'Name')
$FilesSecurity  = @{ EnableHttpsTrafficOnly = $true; PublicNetworkAccess = 'Enabled'; MinimumTlsVersion = 'TLS1_2'; AllowSharedKeyAccess = $false }
$FilesConfig    = @{ EnableAzureActiveDirectoryKerberosForFile = $true; EnableLargeFileShare = $true; IdentityType = 'SystemAssigned' ; ErrorAction = 'Stop' }
$storageAccount = New-AzStorageAccount @Params @FilesParams @FilesSecurity @FilesConfig

#Create and configure share
$ctx            = New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -UseConnectedAccount -ErrorAction Stop
$share          = New-AzStorageShare -Name ($Name.ToLower()+'share') -Context $ctx -ErrorAction Stop
Set-AzStorageShareQuota -ShareName $share.Name -Context $ctx -Quota 100


#region IAM setup for the Storage account and the Share

# This enables 'Default share-level permissions' that is needed to mount the fileshare in an Entra-joined Win11 AzVM using network mapping
Set-AzStorageAccount -ResourceGroupName $RG.ResourceGroupName -AccountName $storageAccount.StorageAccountName -DefaultSharePermission 'StorageFileDataSmbShareElevatedContributor' 
(Get-AzStorageAccount -ResourceGroupName $RG.ResourceGroupName -Name $storageAccount.StorageAccountName).AzureFilesIdentityBasedAuth   # Verify


#$roleTarget     = @{ SignInName = ((Get-AzContext).Account).Id; RoleDefinitionName = 'Storage File Data SMB Share Contributor' }
$roleTarget     = @{ SignInName = ((Get-AzContext).Account).Id; RoleDefinitionName = 'Storage File Data Privileged Contributor' }     #This is needed for OAuth transfer
$roleScope      = @{ Scope = "$($storageAccount.Id)/fileServices/default/fileshares/$($share.Name)"; ErrorAction = 'Stop' }
New-AzRoleAssignment @roleTarget @roleScope
#endregion





#Network connection validation
Test-NetConnection -ComputerName "$StorageAccountName.file.core.windows.net" -Port 445
Test-NetConnection -ComputerName ([System.Uri]::new($share.Context.FileEndPoint).Host) -Port 445 -Verbose


#File transfer validation with OAuth
$FileName  = 'File ' +(Get-Date -Format 'MMddyy HHms') + (-join((GTz).Id -split' '|%{$_[0]})).ToLower()+'.txt'                         # 'File 021326 171028cst.txt'
Set-Content -Path $FileName -Value "This is a dummy text file."                                                               # Generate a unique file name and set dummy content

#$ctx  = New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -UseConnectedAccount -Endpoint $share.Context.FileEndPoint -EnableFileBackupRequestIntent -ErrorAction Stop
$ctx  = New-AzStorageContext -StorageAccountName entraazfiles1 -UseConnectedAccount -EnableFileBackupRequestIntent -ErrorAction Stop  #The context needs backup intent for OAuth transfer
#Set-AzStorageFileContent -ShareName 'entraazfilesshare' -Context $ctx -Source $FileName -Path $FileName                      #I had to start a new PS session. The initial session was erroring out
Set-AzStorageFileContent -ShareName $share.Name -Context $ctx -Source $FileName -Path $FileName

#Download a file from the share using OAuth 
#Get-AzStorageShare -Context $ctx -Name entraazfilesshare|Get-AzStorageFile 
Get-AzStorageShare -Context $ctx -Name $share.Name|Get-AzStorageFile                            #Shows the file name                                                    
Get-AzStorageFileContent -Context $ctx -ShareName $share.Name -Path "DummyFile_174716CST.txt"   #Downloads the file


#region Mounting validation from Win11 AzVM and Kerberos authentication with NTLM over network mapping
#This works after granting 'Admin consent' on the 'API Permissions' blade for the system-assigned MSI 
#otherwise you get error:  New-SmbMapping: The system cannot contact a domain controller to service the authentication request. Please try again later.
New-SmbMapping -LocalPath Z: -Persistent:$false -RemotePath "\\$([System.Uri]::new($share.Context.FileEndPoint).Host)\$($share.Name)"
<#Status Local Path Remote Path
------ ---------- -----------
OK     Z:         \\entraazfiles1.file.core.windows.net\entraazfilesshare
#>
Get-SmbMapping


Get-ChildItem Z:\
New-Item -ItemType Directory -Path Z:\myDirectory
Set-Content -Path Z:\myDirectory\hello.txt -Value "Hello Azure Files"

Get-ChildItem -Path Z:\ -Recurse

Get-Content -Path Z:\myDirectory\hello.txt
#Hello Azure Files


Remove-SmbMapping -LocalPath Z: -Force


#endregion


#endregion





#region Mount file share with storage key
Test-NetConnection -ComputerName '<SAName>.file.core.windows.net' -Port 445
cmd.exe /C "cmdkey /add:`"<SAName>.file.core.windows.net`" /user:`"Azure\<SAName>`" /pass:`"<>`""  #Adds to windows credential manager. Fetch from Key vault
New-PSDrive -Name X -PSProvider FileSystem -Root "\\<SAName>.file.core.windows.net\<>" -Persist
#endregion



#region write to existing fileshare for Azure Batch testing
$storageAcct= Get-AzStorageAccount -Name ayn -ResourceGroupName Infrastructure -Verbose

New-AzStorageShare -Name myshare -Context $storageAcct.Context
New-AzStorageDirectory -Context $storageAcct.Context -ShareName myshare -Path myDirectory

$a= hostname
$a| Out-File -FilePath $($a+'.txt') -Force

Set-AzStorageFileContent -Context $storageAcct.Context -ShareName "myshare" -Source $($a+'.txt') -Path $('myDirectory\'+$a+'.txt')
#endregion




#region File share transfer validation thru context without Azure Login
$Context  = New-AzStorageContext -StorageAccountName ($storageAccountName = '<>') -StorageAccountKey ($storageAccountKey = '<>')
Set-Content -Path ($FileName = "$(hostname).txt") -Value (hostname)                                               #Creates local file
Set-AzStorageFileContent -Context $Context -ShareName 'myshare' -Source $FileName -Path ("myDirectory\$FileName") #Uploads to storage account fileshare
#endregion


# region Some troubleshooting steps for entra joined Win11 mapping over Kerberos and NTLM
#after granting admin consent for the storage account MSI, the kerberos token acquisition works

<#klist purge

Current LogonId is 0:0x14c5c3f
        Deleting all tickets:
        Ticket(s) purged!
PS C:\temp> klist get cifs/entraazfiles1.file.core.windows.net

Current LogonId is 0:0x14c5c3f
A ticket to cifs/entraazfiles1.file.core.windows.net has been retrieved successfully.

Cached Tickets: (2)

#0>     Client: ayan@<> @ AzureAD
        Server: krbtgt/KERBEROS.MICROSOFTONLINE.COM @ KERBEROS.MICROSOFTONLINE.COM
        KerbTicket Encryption Type: Unknown (-1)
        Ticket Flags 0x40810000 -> forwardable renewable name_canonicalize
        Start Time: 2/7/2026 17:22:58 (local)
        End Time:   2/8/2026 3:22:58 (local)
        Renew Time: 2/14/2026 17:22:58 (local)
        Session Key Type: AES-256-CTS-HMAC-SHA1-96
        Cache Flags: 0x400 -> 0x400
        Kdc Called: TicketSuppliedAtLogon

#1>     Client: ayan@<> @ AzureAD
        Server: cifs/entraazfiles1.file.core.windows.net @ KERBEROS.MICROSOFTONLINE.COM
        KerbTicket Encryption Type: AES-256-CTS-HMAC-SHA1-96
        Ticket Flags 0x40000000 -> forwardable
        Start Time: 2/7/2026 17:22:58 (local)
        End Time:   2/7/2026 18:22:58 (local)
        Renew Time: 0
        Session Key Type: AES-256-CTS-HMAC-SHA1-96
        Cache Flags: 0
        Kdc Called: KdcProxy:login.microsoftonline.com
#>


Get-SmbConnection|fl *  #The dialect shows the SMB version the machine is connected with to the FileShare. Runs only with Admin
<#SmbInstance           : Default
ContinuouslyAvailable : True
Credential            : KERBEROS.MICROSOFTONLINE.COM\ayan@<>
Dialect               : 3.1.1
Encrypted             : True
NumOpens              : 1
Redirected            : False
ServerName            : entraazfiles1.file.core.windows.net
ShareName             : entraazfilesshare
Signed                : False
UserName              : AzureAD\<>
PSComputerName        :
CimClass              : ROOT/Microsoft/Windows/SMB:MSFT_SmbConnection
CimInstanceProperties : {ContinuouslyAvailable, Credential, Dialect, Encrypted…}
CimSystemProperties   : Microsoft.Management.Infrastructure.CimSystemProperties
#>


$since = (Get-Date).AddMinutes(-5)
Get-WinEvent -FilterHashtable @{LogName  = 'Microsoft-Windows-SMBClient/Security'; StartTime = $since} | 
        Where-Object Id -in 31001,31023 | Select-Object TimeCreated, Id, Message | Format-List

Get-SmbConnection |  Where-Object ServerName -eq 'entraazfiles1.file.core.windows.net' | Format-Table -AutoSize ServerName, ShareName, UserName, Credential, Dialect, Encrypted

Get-WinEvent -FilterHashtable @{ LogName='Microsoft-Windows-SMBClient/Connectivity'; StartTime=$since } -ErrorAction SilentlyContinue |
  Select-Object TimeCreated, Id, LevelDisplayName, Message | Sort-Object TimeCreated


cmd.exe /c "net use \\entraazfiles1.file.core.windows.net\* /delete /y"  # Nuke net use sessions

# Check/delete cached creds that can push SMB into NTLM
cmdkey /list | findstr /i "entraazfiles1 file.core.windows.net"

#endregion


#ShareClient parameter. Untested
#-SkipGetProperty specifically because fetching share properties isn’t supported in some OAuth flows
$share = Get-AzStorageShare -Context $ctx -Name 'entraazfilesshare' -SkipGetProperty
$shareClient = $share.ShareClient
Set-AzStorageFileContent -ShareClient $shareClient -Context $ctx -Source $FileName -Path $FileName -Debug
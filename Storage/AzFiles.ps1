Get-SmbConnection  #The dialect shows the SMB version the machine is connected with to the FileShare


#Uploads to storage account fileshare
$Context=New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
Set-AzStorageFileContent -Context $Context -ShareName "myshare" -Source $($a+'.txt') -Path $('myDirectory\'+$a+'.txt')




#Mount file share
Test-NetConnection -ComputerName '<SAName>.file.core.windows.net' -Port 445
cmd.exe /C "cmdkey /add:`"<SAName>.file.core.windows.net`" /user:`"Azure\<SAName>`" /pass:`"<>`""  #Adds to windows credential manager. Fetch from Key vault
New-PSDrive -Name X -PSProvider FileSystem -Root "\\<SAName>.file.core.windows.net\<>" -Persist




#region write to existing fileshare for Azure Batch testing
$storageAcct= Get-AzStorageAccount -Name ayn -ResourceGroupName Infrastructure -Verbose

New-AzStorageShare -Name myshare -Context $storageAcct.Context
New-AzStorageDirectory -Context $storageAcct.Context -ShareName myshare -Path myDirectory

$a= hostname
$a| Out-File -FilePath $($a+'.txt') -Force

Set-AzStorageFileContent -Context $storageAcct.Context -ShareName "myshare" -Source $($a+'.txt') -Path $('myDirectory\'+$a+'.txt')
#endregion




#region File share transfer validation  thru context without Azure Login
$storageAccountName = 'ayn'
$storageAccountKey = '<>'
$Context=New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

#Creates local file
$a= hostname
$a| Out-File -FilePath $($a+'.txt') -Force

#Uploads to storage account fileshare
Set-AzStorageFileContent -Context $Context -ShareName "myshare" -Source $($a+'.txt') -Path $('myDirectory\'+$a+'.txt')
#endregion

#Enable hierarchal namespace and SFTP while creating the storage account.
#Create SFTP credentials from the SFTP blade

#region connectivity validation


#region using the WinSCP module. One needs WinSCP to connect and copy the SshHostKeyFingerprint
Install-Module -Name WinSCP 
Install-Module -Name WinSCP -Scope CurrentUser -Repository PSGallery -Verbose
#Enter credentials to connect to FTP server.
$FTPUsername = "naceus2ftppocsa.<>"
$FTPPwd = '<>'
$Password = ConvertTo-SecureString $FTPPwd -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($FTPUsername, $Password)

#Import WinSCP module
Import-Module WinSCP

#Create WinSCP session to your FTP server. 10.0.0.3 is the FTP server. 
#In WINSCP: Session--Server protocol  information--Copy to Clipboard-- Copy fingerprint Contents after 'SHA-256 =' row
$WinSCPSession = New-WinSCPSession -SessionOption (New-WinSCPSessionOption -HostName naceus2ftppocsa.blob.core.windows.net -Protocol Sftp -Credential $Credential -SshHostKeyFingerprint 'ecdsa-sha2-nistp256 256 <>')

Get-WinSCPChildItem -WinSCPSession $WinSCPSession
Get-WinSCPChildItem -WinSCPSession $WinSCPSession -Path '/TestAzure'
Send-WinSCPItem -WinSCPSession $WinSCPSession -Path C:\Temp\TestFile.txt -RemotePath '/Folder2/'
Receive-WinSCPItem -WinSCPSession $WinSCPSession -RemotePath '/Folder2/ReadMe.txt' -LocalPath C:\Temp

Remove-WinSCPSession -WinSCPSession $WinSCPSession
#endregion



#region Posh-SSH module. works on it's own. No dependency on OpenSSH service or anything.
Install-Module -Name Posh-SSH

$SFTPSession = New-SFTPSession -ComputerName naceus2ftppocsa.blob.core.windows.net -Credential $Credential #Using the same $Credential object as the WinSCP test

Get-SFTPItem -SessionId $SFTPSession.SessionId -Path /TestAzure -Destination c:\temp -Verbose #Worked. Copied the folder and it's contents from the SFTP blob container to the destination local folder
#endregion


#endregion


#region Install Open ssh. Couldn't fine the relevant Microsoft published module yet
winget search "openssh beta"
winget install "openssh beta"

Set-Service sshd -StartupType Automatic
Set-Service sshd -Verbose

Get-Service sshd  #Verify running
#endregion


#region NFS mount to windows    https://www.wintellect.com/using-nfs-with-azure-blob-storage/
Select-AzSubscription c2d7e81b-ed6a-4de9-a4cd-36e679ec4259

Register-AzProviderFeature -FeatureName AllowNFSV3 -ProviderNamespace Microsoft.Storage -Verbose
Register-AzResourceProvider -ProviderNamespace Microsoft.Storage

Get-AzProviderFeature -ProviderNamespace Microsoft.Storage -FeatureName AllowNFSV3 -Verbose #Verify that the feature is registered

#to enable write access to the NFS share  
New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default -Name AnonymousUid -PropertyType DWord -Value 0
New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default -Name AnonymousGid -PropertyType DWord -Value 0


mount -o sec=sys,vers=3,nolock,proto=tcp nfstest9.blob.core.windows.net:/nfstest9/test  /nfs   #Failed
mount -o nolock nfstest9.blob.core.windows.net:/nfstest9/test Z:  #Succeeded  
#endregion
#region on the 2012 server
#Install Windows Management framework 5.1
#https://www.microsoft.com/en-us/download/details.aspx?id=54616

#Install PS7
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI"


Enable-PSRemoting -Force -Verbose

Set-Item WSMan:\localhost\Client\TrustedHosts -Value "<>.local"  #since domain is different

Get-Item WSMan:\localhost\Client\TrustedHosts


Enable-WSManCredSSP -Role Server -Force

Get-PSSessionConfiguration | ft Name, PSVersion
#endregion


#region On client machine

Test-WSMan '<>.local' -Verbose

Set-Item WSMan:\localhost\Client\TrustedHosts -Value "<>.local" -Concatenate


$cred     = New-Object System.Management.Automation.PSCredential "<>\<>",$(ConvertTo-SecureString '<>' -asplaintext -force)


Invoke-Command -ComputerName '<>.local' -Credential $cred -ScriptBlock { gps }
Enter-PSSession -ComputerName '<>.local' -Credential $cred -Verbose





Enter-PSSession -ComputerName '<>.local' -Credential $cred -ConfigurationName 'PowerShell.7.5.2' -Verbose
#endregion
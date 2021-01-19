#requires -modules ActiveDirectory

#Variables to be customized
$LegacyADGroup = "EMEA_ResetLegacyCTXProfile"
$LegacySAPRestoreGroup = "EMEA_Legacy-RestoreSAPSettings"
$LegacyProfileShare = "\\nittoeurope.com\NE\Profiles"

$XenAppZDC = "NESRVCTX100" #Choose any Zone Data Collector

#Initialize script variables
$LegacyResetUsers = ""

#Try loading Citrix XenApp 6.5 Powershell modules, exit when failed
if ((Get-PSSnapin "Citrix.XenApp.Commands" -EA silentlycontinue) -eq $null)
  {
	try {Add-PSSnapin Citrix* -ErrorAction Stop }
	catch {Write-error "Error loading XenApp Powershell snapin"; Return }
  }

while ($true)
{
Write-host "Cleaning up first..."
[System.GC]::Collect()
#Sleep 15

#Getting today's suffix
$suffix = "." + (get-date).ToString('yyyyMd')

$LegacyResetUsers = Get-ADGroupMember -Identity $LegacyADGroup
foreach ($LegacyResetUser in $LegacyResetUsers)
{
Write-Host "Processing " $LegacyResetUser.name -ForegroundColor Yellow
$Legacysession = ""
$Legacysession = Get-XASession | select Accountname | where {$_.Accountname -like ("*"+$LegacyResetUser.SamAccountName)}

if ($Legacysession -ne $null)
    {
    write-host "User" $LegacyResetUser.name "has a current session. Moving on." -ForegroundColor Red
    continue
    }
$LegacyProfilePath = $LegacyProfileShare + "\" + $LegacyResetUsers.samaccountname
$LegacyProfileResetLog = $LegacyProfileShare + "\ResetLog\"+($LegacyResetUser.SamAccountName + $suffix)
write-host "Resetting Legacy profile for user" $LegacyResetUser.name -ForegroundColor Green
rename-item $LegacyProfilePath ($LegacyProfilePath+$suffix)

write-host "Logging User Profile Reset" -ForegroundColor Green
new-item $LegacyProfileResetLog -ItemType file

Write-Host "Removing user from Legacy Profile Reset AD Group" -ForegroundColor Green
Remove-ADGroupMember -Identity EMEA_ResetLegacyCTXProfile -Members $legacyresetuser.samaccountname -Confirm:$False

Write-Host "Adding user to Legacy SAP Restore AD Group" -ForegroundColor Green
Add-ADGroupMember -Identity $LegacySAPRestoreGroup -Members $legacyresetuser.samaccountname

}

Write-Host "Waiting for next run..."
#To Do: check for empty
clear-variable -name LegacyResetUsers
[System.GC]::GetTotalMemory($true) | out-null
Sleep 15

}
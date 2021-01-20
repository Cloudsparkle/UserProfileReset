#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Perform reset of selected user on Legacy Citrix environment
.DESCRIPTION
  This script is part of a set to reset and backup/restor a Citrix userprofile. This is the part to reset the profile on the Legacy Citrix environment.
.INPUTS
  User from AD Group
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  19/01/2021
  Purpose/Change: Legacy Citrix user profile reset
.EXAMPLE
  None
#>

#Variables to be customized
$LegacyADGroup = "EMEA_Legacy-ResetCTXProfile"
$LegacySAPRestoreGroup = "EMEA_Legacy-RestoreSAPSettings"

$LegacyProfileShare = "\\nittoeurope.com\NE\Profiles\"
$LegacyResetLogPath = $LegacyProfileShare + "0. Resetlog\"
$SAPNWBCSettingsPath = "\UPM_Profile\AppData\Roaming\SAP\NWBC\"

$XenAppZDC = "NESRVCTX100" #Choose any Zone Data Collector

#Initialize script variables
$LegacyResetUsers = ""

#Try loading Citrix XenApp 6.5 Powershell modules, exit when failed
if ((Get-PSSnapin "Citrix.XenApp.Commands" -EA silentlycontinue) -eq $null)
{
  try {Add-PSSnapin Citrix* -ErrorAction Stop }
	catch {Write-error "Error loading XenApp Powershell snapin"; Return }
}

#start loop
while ($true)
{
  #Getting today's suffix
  $suffix = "." + (get-date).ToString('yyyyMMdd')

  $LegacyResetUsers = Get-ADGroupMember -Identity $LegacyADGroup
  foreach ($LegacyResetUser in $LegacyResetUsers)
  {
    #Initialize variables per user
    $Legacysession = ""
    $RestoreLogID = ""

    Write-Host "Processing " $LegacyResetUser.name -ForegroundColor Yellow

    $RestoreLogID = Get-ChildItem $LegacyResetLogPath | select name | where {$_.name -like ($LegacyResetUser.SamAccountName+"*")}
    if ($RestoreLogID -ne $null)
    {
      Write-host "Incomplete legacy rofile reset detected. Check " $LegacyResetLogPath -ForegroundColor Red
      Continue
    }

    $Legacysession = Get-XASession | select Accountname | where {$_.Accountname -like ("*"+$LegacyResetUser.SamAccountName)}

    if ($Legacysession -ne $null)
    {
      write-host "User" $LegacyResetUser.name "has a current session. Moving on." -ForegroundColor Red
      continue
    }

    $LegacyProfilePath = $LegacyProfileShare + $LegacyResetUser.samaccountname + "\"
    $LegacySAPPath = $LegacyProfilePath + $SAPNWBCSettingsPath
    $LegacyProfileResetLog = $LegacyProfileShare + "0. ResetLog\"+($LegacyResetUser.SamAccountName + $suffix)

    write-host "Resetting Legacy profile for user" $LegacyResetUser.name -ForegroundColor Green
    rename-item $LegacyProfilePath ($LegacyProfilePath+$suffix)

    write-host "Logging User Profile Reset" -ForegroundColor Green
    new-item $LegacyProfileResetLog -ItemType file

    $LegacySAPExist = Test-Path -Path $LegacySAPPath
    if ($LegacySAPExist)
    {
      Write-Host "Legacy SAP Settings detected. Adding user to Legacy SAP Restore AD Group" -ForegroundColor Yellow
      Add-ADGroupMember -Identity $LegacySAPRestoreGroup -Members $legacyresetuser.samaccountname
    }

    Write-Host "Profile Reset complete. Removing user from Legacy Profile Reset AD Group" -ForegroundColor Green
    Remove-ADGroupMember -Identity $LegacyADGroup -Members $legacyresetuser.samaccountname -Confirm:$False

  }

  Write-Host "Waiting for next run..."
  #To Do: check for empty
  clear-variable -name LegacyResetUsers
  "Memory used before collection: $([System.GC]::GetTotalMemory($false))"
  [System.GC]::Collect()
  Sleep 15
  "Memory used after full collection: $([System.GC]::GetTotalMemory($true))"
  Sleep 15

}

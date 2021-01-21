#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Perform reset of selected user on Current Citrix environment
.DESCRIPTION
  This script is part of a set to reset and backup/restor a Citrix userprofile. This is the part to reset the profile on the Current Citrix environment.
.INPUTS
  User from AD Group
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  19/01/2021
  Purpose/Change: Current Citrix user profile reset
.EXAMPLE
  None
#>

#Variables to be customized
$CurrentADGroup = "EMEA_Current-ResetCTXProfile"
$CurrentSAPRestoreGroup = "EMEA_Current-RestoreSAPSettings"

$CurrentProfileShare = "\\nitctxfil1vp.nittoeurope.com\profiles$\"
$CurrentResetLogPath = $CurrentProfileShare + "0. Resetlog\"

$SAPNWBCSettingsPath = "\UPM_Profile\AppData\Roaming\SAP\NWBC\"
$QVSettingsPath = "\UPM_Profile\AppData\Roaming\QlikTech\QlikView\"

#Set DDC to connect to
$CTXDDC = "nitcitddc1vp"
#Initialize script variables
$CurrentResetUsers = ""

#Try loading Citrix CVAD Powershell modules, exit when failed
if ((Get-PSSnapin "Citrix.Broker.Admin.*" -EA silentlycontinue) -eq $null)
{
  try {Add-PSSnapin Citrix* -ErrorAction Stop }
  catch {Write-error "Error loading Citrix CVAD Powershell snapin"; Return }
}

while ($true)
{
  #Getting today's suffix
  $suffix = "." + (get-date).ToString('yyyyMMdd')

  $CurrentResetUsers = Get-ADGroupMember -Identity $CurrentADGroup

  foreach ($CurrentResetUser in $CurentResetUsers)
  {
    #Initialize variable
    $Currentsession = ""
    $RestoreLogID = ""

    Write-Host "Processing " $CurrentResetUser.name -ForegroundColor Yellow

    $RestoreLogID = Get-ChildItem $CurrentResetLogPath | select name | where {$_.name -like ($CurrentResetUser.SamAccountName+"*")}
    if ($RestoreLogID -ne $null)
    {
      Write-host "Incomplete current rofile reset detected. Check " $CurrentResetLogPath -ForegroundColor Red
      Continue
    }

    $Currentsession = Get-BrokerSession -AdminAddress $ctxddc -UserSID $CurrentResetUser.SID

    if ($Currentsession -ne $null)
    {
      write-host "User" $CurrentResetUser.name "has a current session. Moving on." -ForegroundColor Red
      continue
    }

    $CurrentProfilePath = $CurrentProfileShare + $CurrentResetUser.samaccountname + ".nittoeurope" + "\"
    $CurrentSAPPath = $CurrentProfilePath + $SAPNWBCSettingsPath
    $CurrentQVPath = $CurrentProfilePath + $QVSettingsPath
    $CurrentProfileResetLog = $CurrentProfileShare + "\0. ResetLog\"+($CurrentResetUser.SamAccountName + $suffix)

    write-host "Resetting Current profile for user" $CurrentResetUser.name -ForegroundColor Green
    rename-item $CurrentProfilePath ($CurrentProfilePath+$suffix)

    write-host "Logging User Profile Reset" -ForegroundColor Green
    new-item $CurrentProfileResetLog -ItemType file

    $CurrentSAPExist = Test-Path -Path $CurrentSAPPath
    if ($CurrentSAPExist)
    {
      Write-Host "Current SAP settings detected. Adding user to Current SAP Restore AD Group" -ForegroundColor Green
      Add-ADGroupMember -Identity $CurrentSAPRestoreGroup -Members $Currentresetuser.samaccountname
    }

    $CurrentQVExist = Test-Path -Path $CurrentQVPath
    if ($CurrentQVExist)
    {
      Write-Host "Current QlikView settings detected. Adding user to Current Qlikview Restore AD Group" -ForegroundColor Green
      Add-ADGroupMember -Identity $CurrentQVRestoreGroup -Members $Currentresetuser.samaccountname
    }

    Write-Host "Profile reset complete. Removing user from Current Profile Reset AD Group" -ForegroundColor Green
    Remove-ADGroupMember -Identity $CurrentADGroup -Members $Currentresetuser.samaccountname -Confirm:$False

  }

  Write-Host "Waiting for next run..."
  #To Do: check for empty

  clear-variable -name CurrentResetUsers
  "Memory used before collection: $([System.GC]::GetTotalMemory($false))"
  [System.GC]::Collect()
  Sleep 15
  "Memory used after full collection: $([System.GC]::GetTotalMemory($true))"
  Sleep 15
}

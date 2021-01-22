#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Perform restore of SAP Settings after Current profile reset
.DESCRIPTION
  This script is part of a set to reset and backup/restore a Citrix userprofile. This is the part to restore SAP settings on the current environment
.INPUTS
  User from AD Group
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  19/01/2021
  Purpose/Change: Current Citrix SAP Settings profile restore
.EXAMPLE
  None
#>

$CTXDDC = "nitcitddc1vp"

#Try loading Citrix CVAD Powershell modules, exit when failed
if ((Get-PSSnapin "Citrix.Broker.Admin.*" -EA silentlycontinue) -eq $null)
{
  try {Add-PSSnapin Citrix* -ErrorAction Stop }
	catch {Write-error "Error loading Citrix CVAD Powershell snapin"; Return }
}

#Initialize
$CurrentSAPRestoreGroup = "EMEA_Current-RestoreSAPSettings"
$CurrentSAPRestoreGroupDone = "EMEA_Current-RestoreSAPSettingsDone"

$CurrentProfileShare = "\\nitctxfil1vp.nittoeurope.com\profiles$\"
$CurrentResetLogPath = $CurrentProfileShare + "0. Resetlog\"
$SAPNWBCXMLPath = "\UPM_Profile\AppData\Roaming\SAP\NWBC\*.xml"
$SAPNWBCSettingsPath = "\UPM_Profile\AppData\Roaming\SAP\NWBC\"
$SAPBCFavorites = "SAPBCFavorites.xml"
$SAPNWBCFavorites = "NWBCFavorites.xml"

while ($true)
{
  $SAPUsers = Get-ADGroupMember -Identity $CurrentSAPRestoreGroup
  foreach ($SAPUser in $SAPUsers)
  {
    Write-Host "Processing " $SAPUser.name -ForegroundColor Yellow

    $Currentsession = ""
    $Currentsession = Get-XASession | select Accountname | where {$_.Accountname -like ("*"+$SAPUser.SamAccountName)}

    if ($Currentsession -ne $null)
    {
      write-host "User" $SAPUser.name "has a current session. Moving on." -ForegroundColor Red
      continue
    }

    $RestoreLogID = Get-ChildItem $CurrentResetLogPath | select name | where {$_.name -like ($SAPUser.SamAccountName+"*")}

    $Backuppath = $CurrentProfileShare + $RestoreLogID.Name + $SAPNWBCXMLPath
    $CurrentPath = $CurrentProfileShare + $SAPUser.SamAccountName + ".nittoeurope" + $SAPNWBCSettingsPath
    $CurrentXMLFile1 = $Currentpath + $SAPBCFavorites
    $CurrentXMLFile2 = $Currentpath + $SAPNWBCFavorites

    $BackupExists =Test-Path -Path $Backuppath
    $CurrentExists =Test-Path -Path $CurrentPath

    if ($BackupExists)
    {
      Write-host "Settings backup exists..."

      if ($CurrentExists)
      {
        Write-host "User has accessed the Current application already."
        Write-Host "Copying files..."
        Copy-Item $Backuppath -Destination $CurrentPath
        Write-Host "Fixing permissions..."
        $XML1exists = Test-Path -Path $CurrentXMLFile1
        if ($XML1exists)
        {
          icacls $CurrentXMLFile1 /setowner $SAPUser.samaccountname
          icacls $CurrentXMLFile1 /inheritancelevel:e
        }
        $XML2exists = Test-Path -Path $CurrentXMLFile2
        if ($XML2exists)
        {
          icacls $CurrentXMLFile2 /setowner $SAPUser.samaccountname
          icacls $CurrentXMLFile2 /inheritancelevel:e
        }

        Write-Host "Restore Complete Removing user from AD Group" -ForegroundColor Green
        Remove-ADGroupMember -Identity $CurrentSAPRestoreGroup -Members $SAPUser.samaccountname -Confirm:$False
        Add-ADGroupMember -Identity $CurrentSAPRestoreGroupDone -Members $SAPUser.samaccountname
      }
      Else
      {
        write-host "User has not launched the Current application yet. Moving on." -ForegroundColor red
      }
    }
  }

  Write-Host "Waiting for next run..."
  clear-variable -name SAPUsers
  "Memory used before collection: $([System.GC]::GetTotalMemory($false))"
  [System.GC]::Collect()
  Sleep 15
  "Memory used after full collection: $([System.GC]::GetTotalMemory($true))"
  Sleep 15
}

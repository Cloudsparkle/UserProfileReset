#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Perform restore of SAP Settings after Legacy profile reset
.DESCRIPTION
  This script is part of a set to reset and backup/restore a Citrix userprofile. This is the part to restore SAP settings on the legacy environment
.INPUTS
  User from AD Group
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  19/01/2021
  Purpose/Change: Legacy Citrix SAP Settings profile restore
.EXAMPLE
  None
#>

#Try loading Citrix XenApp 6.5 Powershell modules, exit when failed
if ((Get-PSSnapin "Citrix.XenApp.Commands" -EA silentlycontinue) -eq $null)
{
  try {Add-PSSnapin Citrix* -ErrorAction Stop }
  catch {Write-error "Error loading XenApp Powershell snapin"; Return }
}

#Initialize
$LegacySAPRestoreGroup = "EMEA_Legacy-RestoreSAPSettings"
$LegacySAPRestoreGroupDone = "EMEA_Legacy-RestoreSAPSettingsDone"

$LegacyProfileShare = "\\nittoeurope.com\NE\Profiles\"
$LegacyResetLogPath = $LegacyProfileShare + "0. Resetlog\"
$SAPNWBCXMLPath = "\UPM_Profile\AppData\Roaming\SAP\NWBC\*.xml"
$SAPNWBCSettingsPath = "\UPM_Profile\AppData\Roaming\SAP\NWBC\"

$SAPBCFavorites = "SAPBCFavorites.xml"
$SAPNWBCFavorites = "NWBCFavorites.xml"

while ($true)
{
  $SAPUsers = Get-ADGroupMember -Identity $LegacySAPRestoreGroup
  foreach ($SAPUser in $SAPUsers)
  {
    Write-Host "Processing " $SAPUser.name -ForegroundColor Yellow

    $Legacysession = ""
    $Legacysession = Get-XASession | select Accountname | where {$_.Accountname -like ("*"+$SAPUser.SamAccountName)}

    if ($Legacysession -ne $null)
    {
      write-host "User" $SAPUser.name "has a current session. Moving on." -ForegroundColor Red
      continue
    }

    $RestoreLogID = Get-ChildItem $LegacyResetLogPath | select name | where {$_.name -like ($SAPUser.SamAccountName+"*")}
    $Backuppath = $LegacyProfileShare + $RestoreLogID.Name + $SAPNWBCXMLPath
    $LegacyPath = $LegacyProfileShare + $SAPUser.SamAccountName + $SAPNWBCSettingsPath
    $LegacyXMLFile1 = $Legacypath + $SAPBCFavorites
    $LegacyXMLFile2 = $Legacypath + $SAPNWBCFavorites

    $BackupExists =Test-Path -Path $Backuppath
    $LegacyExists =Test-Path -Path $LegacyPath

    if ($BackupExists -eq $true)
    {
      Write-host "Backup settings exist..."

      if ($LegacyExists -eq $true)
      {
        Write-host "User has accessed the Legacy application already."
        Write-Host "Copying files..."
        Copy-Item $Backuppath -Destination $LegacyPath
        Write-Host "Fixing permissions..."
        $XML1exists = Test-Path -Path $LegacyXMLFile1
        if ($XML1exists -eq $true)
        {
          icacls $LegacyXMLFile1 /setowner $SAPUser.samaccountname
          icacls $LegacyXMLFile1 /inheritancelevel:e
        }
        $XML2exists = Test-Path -Path $LegacyXMLFile2
        if ($XML2exists -eq $true)
        {
          icacls $LegacyXMLFile2 /setowner $SAPUser.samaccountname
          icacls $LegacyXMLFile2 /inheritancelevel:e
        }

        Write-Host "Restore Complete Removing user from AD Group" -ForegroundColor Green
        Remove-ADGroupMember -Identity $LegacySAPRestoreGroup -Members $SAPUser.samaccountname -Confirm:$False
        Add-ADGroupMember -Identity $LegacySAPRestoreGroupDone -Members $SAPUser.samaccountname
      }
      Else
      {
        write-host "User has not launched the Legacy application yet. Moving on." -ForegroundColor red
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

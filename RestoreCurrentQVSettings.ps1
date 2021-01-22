#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Perform restore of QlikView Settings after Current profile reset
.DESCRIPTION
  This script is part of a set to reset and backup/restore a Citrix userprofile. This is the part to restore QlikView settings on the current environment
.INPUTS
  User from AD Group
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  19/01/2021
  Purpose/Change: Current Citrix QlikView Settings profile restore
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
$CurrentQVRestoreGroup = "EMEA_Current-RestoreQVSettings"
$CurrentQVRestoreGroupDone = "EMEA_Current-RestoreQVSettingsDone"

$CurrentProfileShare = "\\nittoeurope.com\NE\Profiles\"
$CurrentResetLogPath = $CurrentProfileShare + "0. Resetlog\"
$QVINIPath = "\UPM_Profile\AppData\Roaming\QlikTech\QlikView\settings.ini"
$QVINI = "settings.ini"
$QVSettingsPath = "\UPM_Profile\AppData\Roaming\QlikTech\QlikView\"

while ($true)
{
  $QVUsers = Get-ADGroupMember -Identity $CurrentQVRestoreGroup
  foreach ($QVUser in $QVUsers)
  {
    Write-Host "Processing " $QVUser.name -ForegroundColor Yellow

    $Currentsession = ""
    $Currentsession = Get-XASession | select Accountname | where {$_.Accountname -like ("*"+$QVUser.SamAccountName)}

    if ($Currentsession -ne $null)
    {
      write-host "User" $QVUser.name "has a current session. Moving on." -ForegroundColor Red
      continue
    }

    $RestoreLogID = Get-ChildItem $CurrentResetLogPath | select name | where {$_.name -like ($QVUser.SamAccountName+"*")}

    $Backuppath = $CurrentProfileShare + $RestoreLogID.Name + $QVINIPath
    $CurrentPath = $CurrentProfileShare + $QVUser.SamAccountName + ".nittoeurope" + $QVSettingsPath
    $CurrentINIFile1 = $Currentpath + $QVINI

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
        $INI1exists = Test-Path -Path $CurrentINIFile1
        if ($INI1exists)
        {
          icacls $CurrentINIFile1 /setowner $QVUser.samaccountname
          icacls $CurrentINIFile1 /inheritancelevel:e
        }
        Write-Host "Restore Complete Removing user from AD Group" -ForegroundColor Green
        Remove-ADGroupMember -Identity $CurrentQVRestoreGroup -Members $QVUser.samaccountname -Confirm:$False
        Add-ADGroupMember -Identity $CurrentQVRestoreGroupDone -Members $QVUser.samaccountname
      }
      Else
      {
        write-host "User has not launched the Current application yet. Moving on." -ForegroundColor red
      }
    }
  }

  Write-Host "Waiting for next run..."
  clear-variable -name QVUsers
  "Memory used before collection: $([System.GC]::GetTotalMemory($false))"
  [System.GC]::Collect()
  Sleep 15
  "Memory used after full collection: $([System.GC]::GetTotalMemory($true))"
  Sleep 15
}

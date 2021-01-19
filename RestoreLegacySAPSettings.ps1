#requires -modules ActiveDirectory
#
#Try loading Citrix XenApp 6.5 Powershell modules, exit when failed
if ((Get-PSSnapin "Citrix.XenApp.Commands" -EA silentlycontinue) -eq $null)
  {
	try {Add-PSSnapin Citrix* -ErrorAction Stop }
	catch {Write-error "Error loading XenApp Powershell snapin"; Return }
  }

#Initialize
$LegacySAPRestoreGroup = "EMEA_Legacy-RestoreSAPSettings"
$LegacyProfileShare = "\\nittoeurope.com\NE\Profiles\"
$LegacyResetLogPath = $LegacyProfileShare + "\Resetlog\"
$SAPNWBCXMLPath = "\UPM_Profile\AppData\Roaming\SAP\NWBC\*.xml"
$SAPNWBCSettingsPath = "\UPM_Profile\AppData\Roaming\SAP\NWBC\"
$SAPBCFavorites = "SAPBCFavorites.xml"
$SAPNWBCFavorites = "NWBCFavorites.xml"

while ($true)
{
#Write-host "Cleaning up first..."
#[System.GC]::Collect()
#Sleep 15

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
$RestoreLogID = Get-ChildItem $LegacyResetLogPath | select name | where {$_.name -like ($NWBCUser.SamAccountName+"*")}

$Backuppath = $LegacyProfileShare + $RestoreLogID.Name + $SAPNWBCXMLPath
$LegacyPath = $LegacyProfileShare + $SAPUser.SamAccountName + $SAPNWBCSettingsPath
$LegacyXMLFile1 = $Legachpath + $SAPBCFavorites
$LegacyXMLFile2 = $Legachpath + $SAPNWBCFavorites

$BackupExists =Test-Path -Path $Backuppath
$LegacyExists =Test-Path -Path $LegacyPath

#Write-Host $Backuppath, $BackupExists
#Write-Host $LegacyPath, $LegacyExists

if ($BackupExists -eq $true)
    {
    Write-host "Backup settings exist..."

    if ($LegacyExists -eq $true)
        {
#        Write-host "User has accessed the Legacy application already."
#        Write-Host "Copying files..."
#        Copy-Item $Backuppath -Destination $LegacyPath
#        Write-Host "Fixing permissions..."
#        $XML1exists = Test-Path -Path $LegacyXMLFile1
#        if ($XML2exists -eq $true)
#            {
#            icacls $LegacyXMLFile1 /setowner $SAPUser.samaccountname
#            icacls $LegacyXMLFile1 /inheritancelevel:e
#            }
#        $XML2exists = Test-Path -Path $LegacyXMLFile2
#        if ($XML2exists -eq $true)
#            {
#            icacls $LegacyXMLFile2 /setowner $SAPUser.samaccountname
#            icacls $LegacyXMLFile2 /inheritancelevel:e
#            }
        
#        Write-Host "Restore Complete Removing user from AD Group" -ForegroundColor Green
#        Remove-ADGroupMember -Identity $LegacySAPRestoreGroup -Members $SAPUser.samaccountname -Confirm:$False
        }
    Else
        {
        write-host "User has not launched the Legacy application yet. Moving on." -ForegroundColor red
        }
    }
Else
    {
    write-host "Backup location does not contain application data. Nothing to restore." -ForegroundColor red
#    Write-Host "Removing user from AD Group" -ForegroundColor Green
#    Remove-ADGroupMember -Identity $LegacySAPRestoreGroup -Members $SAPUser.samaccountname -Confirm:$False

#TO DO: CleanRestoreFileLog
    }
}

Write-Host "Waiting for next run..."
clear-variable -name SAPUsers
#[System.GC]::GetTotalMemory($true) | out-null
#Sleep 15

}
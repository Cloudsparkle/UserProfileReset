#requires -modules ActiveDirectory
#

#Initialize
$LegacySAPRestoreGroupDone = "EMEA_Legacy-RestoreSAPSettingsDone"

$LegacyProfileShare = "\\nittoeurope.com\NE\Profiles\"
$LegacyResetLogPath = $LegacyProfileShare + "\0. Resetlog\"

while ($true)
{
    $SAPRestoredUsers = Get-ADGroupMember -Identity $LegacySAPRestoreGroupDone
    foreach ($SAPRestoredUser in $SAPRestoredUsers)
    {
        Write-Host "Processing " $SAPRestoredUser.name -ForegroundColor Yellow

        $RestoreLogID = Get-ChildItem $LegacyResetLogPath | select name | where {$_.name -like ($SAPRestoredUser.SamAccountName+"*")}

        

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
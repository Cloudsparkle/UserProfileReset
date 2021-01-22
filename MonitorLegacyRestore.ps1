#requires -modules ActiveDirectory
#

#Initialize
$LegacySAPRestoreGroupDone = "EMEA_Legacy-RestoreSAPSettingsDone"
$LegacyResetRunningGroup = "EMEA_Legacy-ResetCTXProfileRunning"

$LegacyProfileShare = "\\nittoeurope.com\NE\Profiles\"
$LegacyResetLogPath = $LegacyProfileShare + "0. Resetlog\"

while ($true)
{
    $RestoreLogID = ""
    $SAPRestoreComplete = $false

    $LegacyResetUsers = Get-ADGroupMember -Identity $LegacyResetRunningGroup
    $SAPRestoredUsers = Get-ADGroupMember -Identity $LegacySAPRestoreGroupDone | select samaccountname
    
    foreach ($LegacyResetUser in $LegacyResetUsers)
    {
        Write-Host "Processing " $LegacyResetUser.name -ForegroundColor Yellow

        if ($SAPRestoredUsers.samaccountname -contains $LegacyResetUser.SamAccountName)
        {
            $SAPRestoreComplete = $true
        }
        
        if ($SAPRestoreComplete)
        {


            $RestoreLogID = Get-ChildItem $LegacyResetLogPath | select name | where {$_.name -like ($LegacyResetUser.SamAccountName+"*")}
        
            if ($RestoreLogID -ne $null)
            {
                Write-Host "Profile reset complete for" $LegacyResetUser.name ". Cleaning up." -ForegroundColor Green
                Remove-Item ($LegacyResetLogPath+$RestoreLogID.Name) -Force -confirm:$False
                Remove-ADGroupMember -Identity $LegacySAPRestoreGroupDone -Members $LegacyResetUser.samaccountname -Confirm:$False
                Remove-ADGroupMember -Identity $LegacyResetRunningGroup -Members $LegacyResetUser.samaccountname -Confirm:$False
                                
            }
        }
    }
    
    Write-Host "Waiting for next run..."

    "Memory used before collection: $([System.GC]::GetTotalMemory($false))"
    [System.GC]::Collect()
    Sleep 15
    "Memory used after full collection: $([System.GC]::GetTotalMemory($true))"
    Sleep 15

}
Add-PSSnapin Citrix*
$CTXDDC = "nitcitddc1vp"

while ($true)
{
write-host "Cleaning up first..."
[System.GC]::Collect()
Sleep 15

$QVUsers = Get-ADGroupMember -Identity FUJ_NE_CTX_MIGRATE-QV-SETTINGS
foreach ($QVUser in $QVUsers)
{
Write-Host "Processing " $QVUser.name -ForegroundColor Yellow

$Currentsession = ""
$Currentsession = Get-BrokerSession -AdminAddress $ctxddc -UserSID $QVUser.SID

if ($Currentsession -ne $null)
    {
    write-host "User" $QVUser.name "has a current session. Moving on." -ForegroundColor Red
    continue
    }

#$ADUser = Get-ADUser $QVUser | select samaccountname

$Legacypath = "\\nittoeurope.com\NE\Profiles\" + $QVUser.samaccountname + "\UPM_Profile\AppData\Roaming\QlikTech\QlikView\*.ini"
$FJPath = "\\nitctxfil1vp.nittoeurope.com\profiles$\"+ $QVUser.samaccountname + ".nittoeurope\UPM_Profile\AppData\Roaming\QlikTech\QlikView"
$FJXMLPath = "\\nitctxfil1vp.nittoeurope.com\profiles$\"+ $QVUser.samaccountname + ".nittoeurope\UPM_Profile\AppData\Roaming\QlikTech\QlikView\settings.ini"

$LegacyExists =Test-Path -Path $Legacypath
$FJExists =Test-Path -Path $FJPath

#Write-Host $Legacypath, $LegacyExists, $FJExists

if ($LegacyExists -eq $true)
    {
    Write-host "Legacy settings exist..."

    if ($FJExists -eq $true)
        {
        Write-host "User has accessed the FJ application already."
        Write-Host "Copying files..."
        Copy-Item $Legacypath -Destination $FJPath
        Write-Host "Fixing permissions..."
        icacls $FJXMLPath /setowner $QVUser.samaccountname
        icacls $FJXMLPath /inheritancelevel:e
                
        Write-Host "Removing user from AD Group" -ForegroundColor Green
        Remove-ADGroupMember -Identity FUJ_NE_CTX_MIGRATE-QV-SETTINGS -Members $QVUser.samaccountname -Confirm:$False
        }
    Else
        {
        write-host "User has not launched the FJ application yet. Moving on." -ForegroundColor red
        }
    }


}

Write-Host "Waiting for next run..."
clear-variable -name QVusers
[System.GC]::GetTotalMemory($true) | out-null
Sleep 60

}
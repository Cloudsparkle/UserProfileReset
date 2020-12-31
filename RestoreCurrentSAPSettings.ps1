Add-PSSnapin Citrix*
$CTXDDC = "nitcitddc1vp"

while ($true)
{
Write-host "Cleaning up first..."
[System.GC]::Collect()
Sleep 15

$NWBCUsers = Get-ADGroupMember -Identity FUJ_NE_CTX_MIGRATE-SAP-SETTINGS
foreach ($NWBCUser in $NWBCUsers)
{
Write-Host "Processing " $NWBCUser.name -ForegroundColor Yellow

$Currentsession = ""
$Currentsession = Get-BrokerSession -AdminAddress $ctxddc -UserSID $NWBCUser.SID

if ($Currentsession -ne $null)
    {
    write-host "User" $NWBCUser.name "has a current session. Moving on." -ForegroundColor Red
    continue
    }

#$ADUser = Get-ADUser $NWBCUser | select samaccountname

$Legacypath = "\\nittoeurope.com\NE\Profiles\" + $NWBCUser.samaccountname + "\UPM_Profile\AppData\Roaming\SAP\NWBC\*.xml"
$FJPath = "\\nitctxfil1vp.nittoeurope.com\profiles$\"+ $NWBCUser.samaccountname + ".nittoeurope\UPM_Profile\AppData\Roaming\SAP\NWBC"
$FJXMLPath = "\\nitctxfil1vp.nittoeurope.com\profiles$\"+ $NWBCUser.samaccountname + ".nittoeurope\UPM_Profile\AppData\Roaming\SAP\NWBC\SAPBCFavorites.xml"
$FJXMLPath2 = "\\nitctxfil1vp.nittoeurope.com\profiles$\"+ $NWBCUser.samaccountname + ".nittoeurope\UPM_Profile\AppData\Roaming\SAP\NWBC\NWBCFavorites.xml"

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
        icacls $FJXMLPath /setowner $NWBCUser.samaccountname
        icacls $FJXMLPath /inheritancelevel:e
        $XML2exists = Test-Path -Path $FJXMLPath2
        if ($XML2exists -eq $true)
            {
            icacls $FJXMLPath2 /setowner $NWBCUser.samaccountname
            icacls $FJXMLPath2 /inheritancelevel:e
            }
        
        Write-Host "Removing user from AD Group" -ForegroundColor Green
        Remove-ADGroupMember -Identity FUJ_NE_CTX_MIGRATE-SAP-SETTINGS -Members $NWBCUser.samaccountname -Confirm:$False
        }
    Else
        {
        write-host "User has not launched the FJ application yet. Moving on." -ForegroundColor red
        }
    }
Else
    {
    write-host "User has not launched the Legacy application. Nothing to migrate." -ForegroundColor red
    Write-Host "Removing user from AD Group" -ForegroundColor Green
    Remove-ADGroupMember -Identity FUJ_NE_CTX_MIGRATE-SAP-SETTINGS -Members $NWBCUser.samaccountname -Confirm:$False
    }
}

Write-Host "Waiting for next run..."
clear-variable -name NWBCUsers
[System.GC]::GetTotalMemory($true) | out-null
Sleep 15

}
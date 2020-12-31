#requires -modules ActiveDirectory

#Variables to be customized
$LegacyADGroup = "EMEA_ResetLegacyCTXProfile"
$CurrentADGroup = "EMEA_ResetCurrentCTXProfile"
$LegacyProfileShare = "\\nittoeurope.com\NE\Profiles"
$CurrentProfileShare = "\\nitctxfil1vp.nittoeurope.com\profiles$"

$CTXDDC = "nitcitddc1vp"
$XenAppZDC = "NESRVCTX100" #Choose any Zone Data Collector

#Initialize script variables
$LegacyResetUsers = ""
$CurrentResetUsers = ""

#Try loading Citrix XenApp 6.5 Powershell modules, exit when failed
if ((Get-PSSnapin "Citrix.XenApp.Commands" -EA silentlycontinue) -eq $null)
  {
	try {Add-PSSnapin Citrix* -ErrorAction Stop }
	catch {Write-error "Error loading XenApp Powershell snapin"; Return }
  }

#Try loading Citrix CVAD Powershell modules, exit when failed
if ((Get-PSSnapin "Citrix.Broker.Admin.*" -EA silentlycontinue) -eq $null)
  {
	try {Add-PSSnapin Citrix* -ErrorAction Stop }
	catch {Write-error "Error loading Citrix CVAD Powershell snapin"; Return }
  }

while ($true)
{
Write-host "Cleaning up first..."
[System.GC]::Collect()
#Sleep 15

#Getting today's suffix
$suffix = "." + (get-date).ToString('yyyyMd')

$LegacyResetUsers = Get-ADGroupMember -Identity $LegacyADGroup
$CurrentResetUsers = Get-ADGroupMember -Identity $CurrentADGroup
foreach ($LegacyResetUser in $LegacyResetUsers)
{
Write-Host "Processing " $LegacyResetUser.name -ForegroundColor Yellow
}

foreach ($CurrentResetUser in $CurentResetUsers)
{
Write-Host "Processing " $CurrentResetUser.name -ForegroundColor Yellow

$Currentsession = ""
$Currentsession = Get-BrokerSession -AdminAddress $ctxddc -UserSID $NWBCUser.SID

if ($Currentsession -ne $null)
    {
    write-host "User" $NWBCUser.name "has a current session. Moving on." -ForegroundColor Red
    continue
    }

}

Write-Host "Waiting for next run..."
#To Do: check for empy
clear-variable -name LegacyResetUsers
clear-variable -name CurrentResetUsers
[System.GC]::GetTotalMemory($true) | out-null
Sleep 15

}
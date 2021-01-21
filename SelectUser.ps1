#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Select user for Profile reset
.DESCRIPTION
  This script is part of a set to reset and backup/restor a Citrix userprofile. This is the part to select the user to be reset.
.INPUTS
  AD Domain, AD User
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  19/01/2021
  Purpose/Change: Select User for Citrix profile reset
.EXAMPLE
  None
#>

#Initialize variables
$SelectedDomain = ""
$LegacyProfileShare = "\\nittoeurope.com\NE\Profiles\"
$CurrentProfileShare = "\\nitctxfil1vp.nittoeurope.com\profiles$\"

$CurrentProfileSuffix = ".nittoeurope"
$ResetLegacy = "No"
$ResetCurrent = "No"

$LegacyADGroup = "EMEA_Legacy-ResetCTXProfile"
$CurrentADGroup = "EMEA_Current-ResetCTXProfile"

Add-Type -AssemblyName PresentationFramework

#Get the AD DomainName
$ADForestInfo = Get-ADForest
$SelectedDomain = $ADForestInfo.Domains | Out-GridView -Title "Select AD Domain" -OutputMode Single

#Check for a valid DomainName
if ($SelectedDomain -eq $null)
{
  [System.Windows.MessageBox]::Show("AD Domain not selected","Error","OK","Error")
  exit
}

#Find the right AD Domain Controller
$dc = Get-ADDomainController -DomainName $SelectedDomain -Discover -NextClosestSite

#Get all users from selected domain and select the user for reset
$ADUserList = Get-ADUser -filter * -Server $SelectedDomain | sort name | select Name, samaccountname
$SelectedUser = $ADUserList | Out-GridView -Title "UserProfileReset: Select the user to reset" -OutputMode Single

#Basic check for selecte user
if ($SelectedUser -eq $null)
{
  [System.Windows.MessageBox]::Show("Source group not selected","Error","OK","Error")
  exit 1
}

$LegacyProfilePath = $LegacyProfileShare  + $SelectedUser.samaccountname
$CurrentProfilePath = $CurrentProfileShare + $SelectedUser.samaccountname + $CurrentProfileSuffix

#Check if path to profile exists
$LegacyExists =Test-Path -Path $LegacyProfilePath
$CurrentExists =Test-Path -Path $CurrentProfilePath

if ($LegacyExists)
{
  #Ask for reset on Legacy Citrix servers
  $ResetLegacy = [System.Windows.MessageBox]::Show('Do you want to reset the profile on Legacy Citrix Servers?','Legacy Profile Exists','YesNo','Question')
}

if ($CurrentExists)
{
  #Ask for reset on Current Citrix servers
  $ResetCurrent = [System.Windows.MessageBox]::Show('Do you want to reset the profile on Current Citrix Servers?','Current Profile Exists','YesNo','Question')
}

if ($ResetLegacy -eq "Yes")
{
  Add-ADGroupMember -Identity $LegacyADGroup -Members $SelectedUser.samaccountname
  $message = "User " + $selectedUser.name + " has been selected for Legacy Citrix Profile reset"
  [System.Windows.MessageBox]::Show($message,"Finished","OK","Asterisk")
}

if ($ResetCurrent -eq "Yes")
{
  Add-ADGroupMember -Identity $CurrentADGroup -Members $SelectedUser.samaccountname
  $message = "User " + $selectedUser.name + " has been selected for Current Citrix Profile reset"
  [System.Windows.MessageBox]::Show($message,"Finished","OK","Asterisk")
}

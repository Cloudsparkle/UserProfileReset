#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Copy AD group members from one AD group to another AD group in the same domain
.DESCRIPTION
  This script provides a GUI to quickly copy AD group members to another existing group in the same domain. Multi-domain forests are supported, the script will query for the AD domain.
.PARAMETER <Parameter_Name>
    None
.INPUTS
  AD Domain, Source AD group, Destination AD Group
.OUTPUTS
  None
.NOTES
  Version:        1.1
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  09/03/2020
  Purpose/Change: Copy AD Group members to another group

.EXAMPLE
  None
#>

#Initialize variables
$SelectedDomain = ""
$SourceGroup = ""
$DestinationGroup = ""
$LegacyProfileShare = "\\nittoeurope.com\NE\Profiles"
$CurrentProfileShare = "\\nitctxfil1vp.nittoeurope.com\profiles$"
$LegacyADGroup = "EMEA_ResetLegacyCTXProfile"
$CurrentADGroup = "EMEA_ResetCurrentCTXProfile"

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

#Get all users from selected domain and select source and destination groups
$ADUserList = Get-ADUser -filter * -Server $SelectedDomain | sort name | select Name, samaccountname
$SelectedUser = $ADUserList | Out-GridView -Title "UserProfileReset: Select the user to reset" -OutputMode Single

#Basic checks for selecte groups
if ($SelectedUser -eq $null)
  {
    [System.Windows.MessageBox]::Show("Source group not selected","Error","OK","Error")
    exit 1
  }

$LegacyProfilePath = $LegacyProfileShare + "\" + $SelectedUser.samaccountname
$CurrentProfilePath = $CurrentProfileShare + "\" + $SelectedUser.samaccountname + ".nittoeurope"

$LegacyExists =Test-Path -Path $LegacyProfilePath
$CurrentExists =Test-Path -Path $CurrentProfilePath

if ($LegacyExists)
    {
    #Ask for
    $ResetLegacy = [System.Windows.MessageBox]::Show('Do you want to reset the profile on Legacy Citrix Servers?','Legacy Profile Exists','YesNo','Question')
    }

if ($CurrentExists)
    {
    #Ask for
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


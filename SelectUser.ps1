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

# Make sure we can display the fancy stuff
Add-Type -AssemblyName PresentationFramework

#Function to read config.ini
Function Get-IniContent
{
    <#
    .Synopsis
        Gets the content of an INI file
    .Description
        Gets the content of an INI file and returns it as a hashtable
    .Notes
        Author        : Oliver Lipkau <oliver@lipkau.net>
        Blog        : http://oliver.lipkau.net/blog/
        Source        : https://github.com/lipkau/PsIni
                      http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91
        Version        : 1.0 - 2010/03/12 - Initial release
                      1.1 - 2014/12/11 - Typo (Thx SLDR)
                                         Typo (Thx Dave Stiff)
        #Requires -Version 2.0
    .Inputs
        System.String
    .Outputs
        System.Collections.Hashtable
    .Parameter FilePath
        Specifies the path to the input file.
    .Example
        $FileContent = Get-IniContent "C:\myinifile.ini"
        -----------
        Description
        Saves the content of the c:\myinifile.ini in a hashtable called $FileContent
    .Example
        $inifilepath | $FileContent = Get-IniContent
        -----------
        Description
        Gets the content of the ini file passed through the pipe into a hashtable called $FileContent
    .Example
        C:\PS>$FileContent = Get-IniContent "c:\settings.ini"
        C:\PS>$FileContent["Section"]["Key"]
        -----------
        Description
        Returns the key "Key" of the section "Section" from the C:\settings.ini file
    .Link
        Out-IniFile
    #>

    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [ValidateScript({(Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini")})]
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]
        [string]$FilePath
    )

    Begin
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}

    Process
    {
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"

        $ini = @{}
        switch -regex -file $FilePath
        {
            "^\[(.+)\]$" # Section
            {
                $section = $matches[1]
                $ini[$section] = @{}
                $CommentCount = 0
            }
            "^(;.*)$" # Comment
            {
                if (!($section))
                {
                    $section = "No-Section"
                    $ini[$section] = @{}
                }
                $value = $matches[1]
                $CommentCount = $CommentCount + 1
                $name = "Comment" + $CommentCount
                $ini[$section][$name] = $value
            }
            "(.+?)\s*=\s*(.*)" # Key
            {
                if (!($section))
                {
                    $section = "No-Section"
                    $ini[$section] = @{}
                }
                $name,$value = $matches[1..2]
                $ini[$section][$name] = $value
            }
        }
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath"
        Return $ini
    }

    End
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}
}

$currentDir = [System.AppDomain]::CurrentDomain.BaseDirectory.TrimEnd('\')
if ($currentDir -eq $PSHOME.TrimEnd('\'))
	{
		$currentDir = $PSScriptRoot
	}

#Read inifile
$IniFilePath = $currentDir + "\config.ini"
$IniFileExists = Test-Path $IniFilePath
If ($IniFileExists -eq $true)
{
    $IniFile = Get-IniContent $IniFilePath

    $LegacyADGroup = $IniFile["AD"]["LegacyADGroup"]
    if ($LegacyADGroup -eq $null)
      {
        [System.Windows.MessageBox]::Show("Legacy AD Group not found in config.ini.","Error","OK","Error")
        exit 1
      }

    $CurrentADGroup = $IniFile["AD"]["CurrentADGroup"]
    if ($CurrentADGroup -eq $null)
      {
        [System.Windows.MessageBox]::Show("Current AD Group not found in config.ini.","Error","OK","Error")
        exit 1
      }

    $LegacyProfileShare = $IniFile["SHARE"]["LegacyProfileShare"]
    if ($LegacyProfileShare -eq $null)
      {
        [System.Windows.MessageBox]::Show("Legacy profile share not found in config.ini.","Error","OK","Error")
        exit 1
      }
    
    $CurrentProfileShare = $IniFile["SHARE"]["CurrentProfileShare"]
    if ($CurrentProfileShare -eq $null)
      {
        [System.Windows.MessageBox]::Show("Current profile share not found in config.ini.","Error","OK","Error")
        exit 1
      }


}   
Else
{
    [System.Windows.MessageBox]::Show("Config.ini not found.","Error","OK","Error")
    exit 1
}

#Initialize variables
$SelectedDomain = ""
$ResetNeeded = $false

#$LegacyProfileShare = "\\nittoeurope.com\NE\Profiles\"
#$CurrentProfileShare = "\\nitctxfil1vp.nittoeurope.com\profiles$\"

#Get the AD DomainName
$ADForestInfo = Get-ADForest
$SelectedDomain = $ADForestInfo.Domains | Out-GridView -Title "Select AD Domain" -OutputMode Single

#Check for a valid DomainName
if ($SelectedDomain -eq $null)
  {
    [System.Windows.MessageBox]::Show("AD Domain not selected.","Error","OK","Error")
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
    [System.Windows.MessageBox]::Show("User not selected.","Error","OK","Error")
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
    $resetneeded = $true
    }

if ($ResetCurrent -eq "Yes")
    {
    Add-ADGroupMember -Identity $CurrentADGroup -Members $SelectedUser.samaccountname
    $message = "User " + $selectedUser.name + " has been selected for Current Citrix Profile reset"
    [System.Windows.MessageBox]::Show($message,"Finished","OK","Asterisk")
    $resetneeded = $true
    }

if ($ResetNeeded -eq $false)
{
    $message = "User " + $selectedUser.name + " does not have a Citrix profile to reset."
    [System.Windows.MessageBox]::Show($message,"Finished","OK","Asterisk")
}     

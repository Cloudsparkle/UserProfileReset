#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Select the user that needs a Citrix userprofile reset.
.DESCRIPTION
  This script is part of a set to reset and backup/restore a Citrix userprofile. This is the part to select the user for whom the profile to reset
.INPUTS
  User from AD Group
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  19/01/2021
  Purpose/Change: Citrix profile reset user selector
.EXAMPLE
  None
#>

# Make sure we can display the fancy stuff
Add-Type -AssemblyName PresentationFramework

# Function to read config.ini
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

# Get the current running directory
$currentDir = [System.AppDomain]::CurrentDomain.BaseDirectory.TrimEnd('\')
if ($currentDir -eq $PSHOME.TrimEnd('\'))
{
  $currentDir = $PSScriptRoot
}

# Read config.ini
$IniFilePath = $currentDir + "\config.ini"
$IniFileExists = Test-Path $IniFilePath
If ($IniFileExists -eq $true)
{
  $IniFile = Get-IniContent $IniFilePath

  # Users that need to have their profile reset on the legacy Citrix will be added to this AD group for batch processing in another script
  $LegacyADGroup = $IniFile["AD"]["LegacyADGroup"]
  if ($LegacyADGroup -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Legacy AD Group not found in config.ini.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
      }
    }
  }

  # Users that need to have their profile reset on the current Citrix will be added to this AD group for batch processing in another script
  $CurrentADGroup = $IniFile["AD"]["CurrentADGroup"]
  if ($CurrentADGroup -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Current AD Group not found in config.ini.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
      }
    }
  }

  # Getting the Citrix UPM Profile share for the Legacy environment
  $LegacyProfileShare = $IniFile["SHARE"]["LegacyProfileShare"]
  if ($LegacyProfileShare -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Legacy profile share not found in config.ini.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
      }
    }
  }
  Else
  {
    # Making sure the path has a trailing \, exists and is accessible
    $LegacyProfileShare.TrimEnd('\') | out-null
    $LegacyProfileShare += '\' 
    $LegacyShareExists =Test-Path -Path $LegacyProfileShare
    if ($LegacyShareExists -eq $false)
    {
      $msgBoxInput = [System.Windows.MessageBox]::Show("Legacy profile share not reachable. Please check config.ini.","Error","OK","Error")
      switch  ($msgBoxInput)
      {
        "OK"
        {
          Exit 1
        }
      }
    }
  }

  # Getting the Citrix UPM Profile share for the current environment
  $CurrentProfileShare = $IniFile["SHARE"]["CurrentProfileShare"]
  if ($CurrentProfileShare -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Current profile share not found in config.ini.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
      }
    }
  }
  Else
  {
    # Making sure the path has a trailing \, exists and is accessible
    $CurrentProfileShare.TrimEnd('\') | out-null
    $CurrentProfileShare += '\' 
    $CurrentShareExists = Test-Path -Path $CurrentProfileShare
    if ($CurrentShareExists -eq $false)
    {
      $msgBoxInput = [System.Windows.MessageBox]::Show("Current profile share not reachable. Please check config.ini.","Error","OK","Error")
      switch  ($msgBoxInput)
      {
        "OK"
        {
          Exit 1
        }
      }
    }
  }

  # When the user forlders in the profile share have a suffix, that's read here
  $LegacyProfileSuffix = $IniFile["GENERAL"]["LegacyProfileSuffix"]
  $CurrentProfileSuffix = $IniFile["GENERAL"]["CurrentProfileSuffix"]
}
Else
{
  $msgBoxInput = [System.Windows.MessageBox]::Show("Config.ini not found.","Error","OK","Error")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 1
    }
  }
}

# Initialize variables
$SelectedDomain = ""
$ResetPossible = $false
$resetRequested = $false

# Get the AD DomainName
$ADForestInfo = Get-ADForest
$SelectedDomain = $ADForestInfo.Domains | Out-GridView -Title "Select AD Domain" -OutputMode Single

# Check for a valid DomainName
if ($SelectedDomain -eq $null)
{
  $msgBoxInput = [System.Windows.MessageBox]::Show("AD Domain not selected.","Error","OK","Error")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 1
    }
  }
}

# Find the right AD Domain Controller
$dc = Get-ADDomainController -DomainName $SelectedDomain -Discover -NextClosestSite

# Get all users from selected domain and select the user for which to reset the profile
$ADUserList = Get-ADUser -filter * -Server $SelectedDomain | sort name | select Name, samaccountname
$SelectedUser = $ADUserList | Out-GridView -Title "UserProfileReset: Select the user to reset" -OutputMode Single

#Basic checks for selected user
if ($SelectedUser -eq $null)
{
  $msgBoxInput = [System.Windows.MessageBox]::Show("User not selected.","Error","OK","Error")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 1
    }
  }
}

$LegacyProfilePath = $LegacyProfileShare + $SelectedUser.samaccountname + $LegacyProfileSuffix
$CurrentProfilePath = $CurrentProfileShare + $SelectedUser.samaccountname + $CurrentProfileSuffix

$LegacyExists =Test-Path -Path $LegacyProfilePath
$CurrentExists =Test-Path -Path $CurrentProfilePath

if ($LegacyExists)
{
  # Ask for a reset of the Legacy user profile
  $ResetLegacy = [System.Windows.MessageBox]::Show('Do you want to reset the profile on Legacy Citrix Servers?','Legacy Profile Exists','YesNo','Question')
  $ResetPossible = $true
}

if ($CurrentExists)
{
  # Ask for a reset of the current user profile
  $ResetCurrent = [System.Windows.MessageBox]::Show('Do you want to reset the profile on Current Citrix Servers?','Current Profile Exists','YesNo','Question')
  $ResetPossible = $true
}

if ($ResetPossible -eq $false)
{
  $message = "User " + $selectedUser.name + " does not have a Citrix profile to reset."
  $msgBoxInput = [System.Windows.MessageBox]::Show($message,"Finished","OK","Asterisk")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 1
    }
  }
}

if ($ResetLegacy -eq "Yes")
{
  Add-ADGroupMember -Identity $LegacyADGroup -Members $SelectedUser.samaccountname
  $message = "User " + $selectedUser.name + " has been selected for Legacy Citrix Profile reset"
  $msgBoxInput = [System.Windows.MessageBox]::Show($message,"Finished","OK","Asterisk")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 0
    }
  }
  $ResetRequested = $true
}

if ($ResetCurrent -eq "Yes")
{
  Add-ADGroupMember -Identity $CurrentADGroup -Members $SelectedUser.samaccountname
  $message = "User " + $selectedUser.name + " has been selected for Current Citrix Profile reset"
  $msgBoxInput = [System.Windows.MessageBox]::Show($message,"Finished","OK","Asterisk")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 0
    }
  }
  $ResetRequested = $true
}

if ($ResetRequested -eq $false)
{
  $message = "A Citrix profile reset for user " + $selectedUser.name + " was not requested."
  $msgBoxInput = [System.Windows.MessageBox]::Show($message,"Finished","OK","Asterisk")
  switch  ($msgBoxInput)
  {
    "OK"
    {
      Exit 0
    }
  }
}

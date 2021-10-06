#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Perform reset of selected user on Current Citrix environment
.DESCRIPTION
  This script is part of a set to reset and backup/restor a Citrix userprofile. This is the part to reset the profile on the Current Citrix environment.
.INPUTS
  User from AD Group
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  19/01/2021
  Purpose/Change: Current Citrix user profile reset
.EXAMPLE
  None
#>

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

  # Users that need to have SAP settings restored will be added to this AD group for batch processing in another script
  $CurrentSAPRestoreGroup = $IniFile["AD"]["CurrentSAPRestoreGroup"]
  if ($CurrentSAPRestoreGroup -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Current SAP Restore AD Group not found in config.ini.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
      }
    }
  }

  # Users that need to have QV settings restored will be added to this AD group for batch processing in another script
  $CurrentQVRestoreGroup = $IniFile["AD"]["CurrentQVRestoreGroup"]
  if ($CurrentQVRestoreGroup -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Current QV Restore AD Group not found in config.ini.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
      }
    }
  }

  # As long as restore was not completed, users will be member of a specific AD Group
  $CurrentResetRunningGroup = $IniFile["AD"]["CurrentResetRunningGroup"]
  if ($CurrentResetRunningGroup -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Current Reset Running AD Group not found in config.ini.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
      }
    }
  }

  # Get the Delivery Controller
  $CTXDDC = $IniFile["CURRENT"]["$CTXDDC"]
  if ($CTXDDC -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Current Citrix Delivery Controller not found in config.ini.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
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

  # Getting the SAP Settings path for the Current environment
  $SAPNWBCSettingsPath = $IniFile["SHARE"]["SAPNWBCSettingsPath"]
  if ($SAPNWBCSettingsPath -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Legacy SAP Settings Path not found in config.ini.","Error","OK","Error")
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
    # Making sure the path has a trailing \
    $SAPNWBCSettingsPath.TrimEnd('\') | out-null
    $SAPNWBCSettingsPath += '\'
  }

  # Getting the QV Settings path for the Current environment
$QVSettingsPath = $IniFile["SHARE"]["QVSettingsPath"]
  if ($QVSettingsPath -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Current QV Settings Path not found in config.ini.","Error","OK","Error")
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
    # Making sure the path has a trailing \
    $QVSettingsPath.TrimEnd('\') | out-null
    $QVSettingsPath += '\'
  }

  # When the user forlders in the profile share have a suffix, that's read here
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

#Initialize script variables
$CurrentResetLogPath = $CurrentProfileShare + "0. Resetlog\"
$CurrentResetUsers = ""

#Try loading Citrix CVAD Powershell modules, exit when failed
if ((Get-PSSnapin "Citrix.Broker.Admin.*" -EA silentlycontinue) -eq $null)
{
  try {Add-PSSnapin Citrix* -ErrorAction Stop }
  catch {Write-error "Error loading Citrix CVAD Powershell snapin"; Return }
}

while ($true)
{
  #Getting today's suffix
  $suffix = "." + (get-date).ToString('yyyyMMdd')

  $CurrentResetUsers = Get-ADGroupMember -Identity $CurrentADGroup

  foreach ($CurrentResetUser in $CurrentResetUsers)
  {
    #Initialize variable
    $Currentsession = ""
    $RestoreLogID = ""

    Write-Host "Processing " $CurrentResetUser.name -ForegroundColor Yellow

    $RestoreLogID = Get-ChildItem $CurrentResetLogPath | select name | where {$_.name -like ($CurrentResetUser.SamAccountName+"*")}
    if ($RestoreLogID -ne $null)
    {
      Write-host "Incomplete current rofile reset detected. Check " $CurrentResetLogPath -ForegroundColor Red
      Continue
    }

    $Currentsession = Get-BrokerSession -AdminAddress $ctxddc -UserSID $CurrentResetUser.SID

    if ($Currentsession -ne $null)
    {
      write-host "User" $CurrentResetUser.name "has a current session. Moving on." -ForegroundColor Red
      continue
    }

    $CurrentProfilePath = $CurrentProfileShare + $CurrentResetUser.samaccountname + $CurrentProfileSuffix
    $CurrentProfileRenameTo = $CurrentProfileShare + $CurrentResetUser.samaccountname + $suffix
    $CurrentSAPPath = $CurrentProfilePath + "\" + $SAPNWBCSettingsPath
    $CurrentQVPath = $CurrentProfilePath + "\" + $QVSettingsPath
    $CurrentProfileResetLog = $CurrentResetLogPath + ($CurrentResetUser.SamAccountName + $suffix)
    $Restoreneeded = $False

    $CurrentProfileExist = test-path -Path $currentprofilepath
    if ($CurrentProfileExist)
    {
        write-host "Resetting Current profile for user" $CurrentResetUser.name -ForegroundColor Green

        write-host "Logging User Profile Reset" -ForegroundColor Green
        new-item $CurrentProfileResetLog -ItemType file

        $CurrentSAPExist = Test-Path -Path $CurrentSAPPath
        if ($CurrentSAPExist)
        {
            Write-Host "Current SAP settings detected. Adding user to Current SAP Restore AD Group" -ForegroundColor Green
            Add-ADGroupMember -Identity $CurrentSAPRestoreGroup -Members $Currentresetuser.samaccountname
            $RestoreNeeded = $true
        }

        $CurrentQVExist = Test-Path -Path $CurrentQVPath
        if ($CurrentQVExist)
        {
            Write-Host "Current QlikView settings detected. Adding user to Current Qlikview Restore AD Group" -ForegroundColor Green
            Add-ADGroupMember -Identity $CurrentQVRestoreGroup -Members $Currentresetuser.samaccountname
            $RestoreNeeded = $true
        }

        if ($RestoreNeeded)
        {
            Add-ADGroupMember -Identity $CurrentResetRunningGroup -Members $Currentresetuser.samaccountname
        }

        rename-item $CurrentProfilePath ($CurrentProfileRenameTo)
        Write-Host "Profile reset complete. Removing user from Current Profile Reset AD Group" -ForegroundColor Green


    }
else
    {
        write-host "Current profile for user does not exist. Reset cancelled" -ForegroundColor Red
    }

    Remove-ADGroupMember -Identity $CurrentADGroup -Members $Currentresetuser.samaccountname -Confirm:$False
    }
  Write-Host "Waiting for next run..."

  #"Memory used before collection: $([System.GC]::GetTotalMemory($false))"
  [System.GC]::Collect()
  Sleep 15
  #"Memory used after full collection: $([System.GC]::GetTotalMemory($true))"
  Sleep 15
}

#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Perform reset of selected user on Legacy Citrix environment
.DESCRIPTION
  This script is part of a set to reset and backup/restor a Citrix userprofile. This is the part to reset the profile on the Legacy Citrix environment.
.INPUTS
  User from AD Group
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  19/01/2021
  Purpose/Change: Legacy Citrix user profile reset
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

  # Users that need to have SAP settings restored will be added to this AD group for batch processing in another script
  $LegacySAPRestoreGroup = $IniFile["AD"]["LegacySAPRestoreGroup"]
  if ($LegacySAPRestoreGroup -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Legacy SAP Restore AD Group not found in config.ini.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
      }
    }
  }

  # As long as restore was not completed, users will be member of a specific AD Group
  $LegacyResetRunningGroup = $IniFile["AD"]["LegacyResetRunningGroup"]
  if ($LegacyResetRunningGroup -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Legacy Reset Running AD Group not found in config.ini.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
      }
    }
  }

  # Get the Zone Data Collector for the XenApp 6.5 Legacy Farm
  $XenAppZDC = $IniFile["LEGACY"]["XenAppZDC"]
  if ($XenAppZDC -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Legacy Citrix XenApp ZDC not found in config.ini.","Error","OK","Error")
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

  # Getting the SAP Settings path for the Legacy environment
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


  # When the user forlders in the profile share have a suffix, that's read here
  $LegacyProfileSuffix = $IniFile["GENERAL"]["LegacyProfileSuffix"]
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
$LegacyResetLogPath = $LegacyProfileShare + "0. Resetlog\"
$LegacyResetUsers = ""

#Try loading Citrix XenApp 6.5 Powershell modules, exit when failed
if ((Get-PSSnapin "Citrix.XenApp.Commands" -EA silentlycontinue) -eq $null)
{
  try {Add-PSSnapin Citrix* -ErrorAction Stop }
	catch {Write-error "Error loading XenApp Powershell snapin"; Return }
}

#start loop
while ($true)
{
  #Getting today's suffix
  $suffix = "." + (get-date).ToString('yyyyMMdd')

  $LegacyResetUsers = Get-ADGroupMember -Identity $LegacyADGroup
  foreach ($LegacyResetUser in $LegacyResetUsers)
  {
    #Initialize variables per user
    $Legacysession = ""
    $RestoreLogID = ""

    Write-Host "Processing " $LegacyResetUser.name -ForegroundColor Yellow

    $RestoreLogID = Get-ChildItem $LegacyResetLogPath | select name | where {$_.name -like ($LegacyResetUser.SamAccountName+"*")}
    if ($RestoreLogID -ne $null)
    {
      Write-host "Incomplete legacy rofile reset detected. Check" $LegacyResetLogPath -ForegroundColor Yellow
      Continue
    }

    $Legacysession = Get-XASession -Computername $XenAppZDC | select Accountname | where {$_.Accountname -like ("*"+$LegacyResetUser.SamAccountName)}

    if ($Legacysession -ne $null)
    {
      write-host "User" $LegacyResetUser.name "has a current session. Moving on." -ForegroundColor Red
      continue
    }

    $LegacyProfilePath = $LegacyProfileShare + $LegacyResetUser.samaccountname
    $LegacySAPPath = $LegacyProfilePath + "\" + $SAPNWBCSettingsPath
    $LegacyProfileResetLog = $LegacyResetLogPath + ($LegacyResetUser.SamAccountName + $suffix)

    $LegacyProfileExist = test-path -Path $Legacyprofilepath
    if ($LegacyProfileExist)
    {
        write-host "Resetting Legacy profile for user" $LegacyResetUser.name -ForegroundColor Green

        write-host "Logging User Profile Reset" -ForegroundColor Green
        new-item $LegacyProfileResetLog -ItemType file

        $LegacySAPExist = Test-Path -Path $LegacySAPPath
        if ($LegacySAPExist)
        {
            Write-Host "Legacy SAP Settings detected. Adding user to Legacy SAP Restore AD Group" -ForegroundColor Yellow
            Add-ADGroupMember -Identity $LegacySAPRestoreGroup -Members $legacyresetuser.samaccountname
            Add-ADGroupMember -Identity $LegacyResetRunningGroup -Members $legacyresetuser.samaccountname
        }
        rename-item $LegacyProfilePath ($LegacyProfilePath+$suffix)
        Write-Host "Profile Reset complete. Removing user from Legacy Profile Reset AD Group" -ForegroundColor Green
    }
    else
    {
        write-host "Legacy profile for user does not exist. Reset cancelled" -ForegroundColor Red
    }

    Remove-ADGroupMember -Identity $LegacyADGroup -Members $legacyresetuser.samaccountname -Confirm:$False

  }

  Write-Host "Waiting for next run..."

  #"Memory used before collection: $([System.GC]::GetTotalMemory($false))"
  [System.GC]::Collect()
  Sleep 15
  #"Memory used after full collection: $([System.GC]::GetTotalMemory($true))"
  Sleep 15
}

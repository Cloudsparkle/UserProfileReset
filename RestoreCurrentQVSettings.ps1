#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Perform restore of QlikView Settings after Current profile reset
.DESCRIPTION
  This script is part of a set to reset and backup/restore a Citrix userprofile. This is the part to restore QlikView settings on the current environment
.INPUTS
  User from AD Group
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  19/01/2021
  Purpose/Change: Current Citrix QlikView Settings profile restore
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

  # Users that need to have QV settings restored will be added to this AD group for batch processing in another script
  $CurrentQVRestoreGroupDone = $IniFile["AD"]["CurrentQVRestoreGroupDone"]
  if ($CurrentQVRestoreGroup -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Current QV Restore Done AD Group not found in config.ini.","Error","OK","Error")
    switch  ($msgBoxInput)
    {
      "OK"
      {
        Exit 1
      }
    }
  }

  # As long as restore was not completed, users will be member of a specific AD Group
  $CurrentResetRunningGroupDone = $IniFile["AD"]["CurrentResetRunningGroupDone"]
  if ($CurrentResetRunningGroupDone -eq $null)
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

$CTXDDC = "nitcitddc1vp"

#Try loading Citrix CVAD Powershell modules, exit when failed
if ((Get-PSSnapin "Citrix.Broker.Admin.*" -EA silentlycontinue) -eq $null)
{
  try {Add-PSSnapin Citrix* -ErrorAction Stop }
	catch {Write-error "Error loading Citrix CVAD Powershell snapin"; Return }
}

#Initialize
$QVINI = "settings.ini"
$CurrentResetLogPath = $CurrentProfileShare + "0. Resetlog\"
$QVINIPath = $QVSettingsPath + $QVINI

while ($true)
{
  $QVUsers = Get-ADGroupMember -Identity $CurrentQVRestoreGroup
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

    $RestoreLogID = Get-ChildItem $CurrentResetLogPath | select name | where {$_.name -like ($QVUser.SamAccountName+"*")}

    $Backuppath = $CurrentProfileShare + $RestoreLogID.Name + "\"  + $QVINIPath
    $CurrentPath = $CurrentProfileShare + $QVUser.SamAccountName + $CurrentProfileSuffix + "\"  + $QVSettingsPath
    $CurrentINIFile1 = $Currentpath + $QVINI

    $BackupExists =Test-Path -Path $Backuppath
    $CurrentExists =Test-Path -Path $CurrentPath

    if ($BackupExists)
    {
      Write-host "Settings backup exists..."

      if ($CurrentExists)
      {
        Write-host "User has accessed the Current application already."
        Write-Host "Copying files..."
        Copy-Item $Backuppath -Destination $CurrentPath
        Write-Host "Fixing permissions..."
        $INI1exists = Test-Path -Path $CurrentINIFile1
        if ($INI1exists)
        {
          icacls $CurrentINIFile1 /setowner $QVUser.samaccountname
          icacls $CurrentINIFile1 /inheritancelevel:e
        }
        Write-Host "Restore Complete Removing user from AD Group" -ForegroundColor Green
        Remove-ADGroupMember -Identity $CurrentQVRestoreGroup -Members $QVUser.samaccountname -Confirm:$False
        Add-ADGroupMember -Identity $CurrentQVRestoreGroupDone -Members $QVUser.samaccountname
      }
      Else
      {
        write-host "User has not launched the Current application yet. Moving on." -ForegroundColor red
      }
    }
  }

  Write-Host "Waiting for next run..."
  clear-variable -name QVUsers
  "Memory used before collection: $([System.GC]::GetTotalMemory($false))"
  [System.GC]::Collect()
  Sleep 15
  "Memory used after full collection: $([System.GC]::GetTotalMemory($true))"
  Sleep 15
}

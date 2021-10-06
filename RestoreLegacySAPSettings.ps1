#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Perform restore of SAP Settings after Legacy profile reset
.DESCRIPTION
  This script is part of a set to reset and backup/restore a Citrix userprofile. This is the part to restore SAP settings on the legacy environment
.INPUTS
  User from AD Group
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  19/01/2021
  Purpose/Change: Legacy Citrix SAP Settings profile restore
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

  # When the restore is completed, users will be added to specific AD group for monitoring
  $LegacySAPRestoreGroupDone = $IniFile["AD"]["LegacySAPRestoreGroupDone"]
  if ($LegacySAPRestoreGroupDone -eq $null)
  {
    $msgBoxInput = [System.Windows.MessageBox]::Show("Legacy Reset Done AD Group not found in config.ini.","Error","OK","Error")
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

#Try loading Citrix XenApp 6.5 Powershell modules, exit when failed
if ((Get-PSSnapin "Citrix.XenApp.Commands" -EA silentlycontinue) -eq $null)
{
  try {Add-PSSnapin Citrix* -ErrorAction Stop }
  catch {Write-error "Error loading XenApp Powershell snapin"; Return }
}

#Initialize
$SAPNWBCXMLPath = $SAPNWBCSettingsPath + "*.xml"
$LegacyResetLogPath = $LegacyProfileShare + "0. Resetlog\"
$SAPBCFavorites = "SAPBCFavorites.xml"
$SAPNWBCFavorites = "NWBCFavorites.xml"

while ($true)
{
  $SAPUsers = Get-ADGroupMember -Identity $LegacySAPRestoreGroup
  foreach ($SAPUser in $SAPUsers)
  {
    Write-Host "Processing " $SAPUser.name -ForegroundColor Yellow

    $Legacysession = ""
    $Legacysession = Get-XASession -Computername $XenAppZDC | select Accountname | where {$_.Accountname -like ("*"+$SAPUser.SamAccountName)}

    if ($Legacysession -ne $null)
    {
      write-host "User" $SAPUser.name "has a current session. Moving on." -ForegroundColor Red
      continue
    }

    $RestoreLogID = Get-ChildItem $LegacyResetLogPath | select name | where {$_.name -like ($SAPUser.SamAccountName+"*")}
    $Backuppath = $LegacyProfileShare + $RestoreLogID.Name + "\" + $SAPNWBCXMLPath
    $LegacyPath = $LegacyProfileShare + $SAPUser.SamAccountName + "\" + $SAPNWBCSettingsPath
    $LegacyXMLFile1 = $Legacypath + $SAPBCFavorites
    $LegacyXMLFile2 = $Legacypath + $SAPNWBCFavorites

    $BackupExists =Test-Path -Path $Backuppath
    $LegacyExists =Test-Path -Path $LegacyPath

    if ($BackupExists)
    {
      Write-host "Settings backup exists..."

      if ($LegacyExists)
      {
        Write-host "User has accessed the Legacy application already."
        Write-Host "Copying files..."
        Copy-Item $Backuppath -Destination $LegacyPath
        Write-Host "Fixing permissions..."
        $XML1exists = Test-Path -Path $LegacyXMLFile1
        if ($XML1exists)
        {
          icacls $LegacyXMLFile1 /setowner $SAPUser.samaccountname
          icacls $LegacyXMLFile1 /inheritancelevel:e
        }
        $XML2exists = Test-Path -Path $LegacyXMLFile2
        if ($XML2exists)
        {
          icacls $LegacyXMLFile2 /setowner $SAPUser.samaccountname
          icacls $LegacyXMLFile2 /inheritancelevel:e
        }

        Write-Host "Restore Complete Removing user from AD Group" -ForegroundColor Green
        Remove-ADGroupMember -Identity $LegacySAPRestoreGroup -Members $SAPUser.samaccountname -Confirm:$False
        Add-ADGroupMember -Identity $LegacySAPRestoreGroupDone -Members $SAPUser.samaccountname
      }
      Else
      {
        write-host "User has not launched the Legacy application yet. Moving on." -ForegroundColor red
      }
    }
  }

  Write-Host "Waiting for next run..."

  #"Memory used before collection: $([System.GC]::GetTotalMemory($false))"
  [System.GC]::Collect()
  Sleep 15
  #"Memory used after full collection: $([System.GC]::GetTotalMemory($true))"
  Sleep 15

}

# *******************************************************************************************************************
#
# Purpose: This script saves a script on the local device to to Clear Microsoft Teams and Authentication Data.
# It creates a scheduled task and sets it to to start automatically on events 4800 and 4802, which is when the
# device is locked or when the screen saver was invoked. Sets registry key to prevent Entra ID device registration
# prompt during login.
#
# Pre-requisite: Audit Other Logon/Logoff Events should be enabled. This is needed to generate events 4800 and 4802
# to trigger the script execution.
#
# ------------------------------------------- DISCLAIMER ------------------------------------------------------------
# This Sample Code is provided for the purpose of illustration only and is not intended to be used 
# in a production environment. THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" 
# WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED 
# WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE. We grant You a nonexclusive, 
# royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code 
# form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to 
# market Your software product in which the Sample Code is embedded; (ii) to include a valid copyright 
# notice on Your software product in which the Sample Code is embedded; and (iii) to indemnify, hold 
# harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ 
# fees, that arise or result from the use or distribution of the Sample Code.
#
# This sample script is not supported under any Microsoft standard support program or service. 
# The sample script is provided AS IS without warranty of any kind. Microsoft further disclaims 
# all implied warranties including, without limitation, any implied warranties of merchantability 
# or of fitness for a particular purpose. The entire risk arising out of the use or performance of 
# the sample scripts and documentation remains with you. In no event shall Microsoft, its authors, 
# or anyone else involved in the creation, production, or delivery of the scripts be liable for any 
# damages whatsoever (including, without limitation, damages for loss of business profits, business 
# interruption, loss of business information, or other pecuniary loss) arising out of the use of or 
# inability to use the sample scripts or documentation, even if Microsoft has been advised of the 
# possibility of such damages.
# ------------------------------------------- DISCLAIMER ------------------------------------------------------------
#
# *******************************************************************************************************************

# Script Content Added Here

$content = @'
# If the device is Entra ID joined or Hybrid Joined it might autilatically sign-in with the user that logs on after signing out and signing back in.

# Recommended to set the registry key to avoid Entra ID device registration prompt: HKLM\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin, "BlockAADWorkplaceJoin"=dword:00000001

# IMPORTANT: This scripts removes Microsoft Teams offline data, including drafts.

# Info https://support.microsoft.com/en-us/office/sign-out-or-remove-an-account-from-microsoft-teams-a6d76e69-e1dd-4bc4-8e5f-04ba48384487
# When you sign out of Teams on any device, info associated with your account is removed from the Teams app until you sign back in again. However, other apps that you use will continue to have access to your account.
# Signing out of Teams in one device doesn’t sign you out of Teams in your other devices.

# Exit Microsoft Teams
try{ 
    $teamsRunning = Get-Process -Name ms-teams -ErrorAction SilentlyContinue
    If ($teamsRunning) { 
        Write-Host "Microsoft Teams will now close to clear the cache."
        Stop-Process -InputObject $teamsRunning -Force
        Start-Sleep -Seconds 5
        Write-Host "Microsoft Teams has closed successfully."
    }
} catch{ 
    echo $_
} 

# Clear the cache for Microsoft Teams and user authentication
Write-Host "Clearing Microsoft Teams and user authentication cache."
try{ 
    # API method (Seems similar to Settings app reset functionality, does not break app installation) - Not enough to clear signed in accounts of the device by itself
    [Windows.Management.Core.ApplicationDataManager,Windows.Management.Core,ContentType=WindowsRuntime] > $null 
    $valueTeams = [Windows.Management.Core.ApplicationDataManager]::CreateForPackageFamily("MSTeams_8wekyb3d8bbwe")
    $asyncInfoTeams = $valueTeams.ClearAsync()
    $valueAADBrokerPlugin = [Windows.Management.Core.ApplicationDataManager]::CreateForPackageFamily("Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy")
    $asyncInfoAADBrokerPlugin = $valueAADBrokerPlugin.ClearAsync()

    # Remove files method - Might affect other apps that use the saved credentials like OneDrive
    Get-ChildItem -Path $env:LOCALAPPDATA\"Microsoft\OneAuth" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    Get-ChildItem -Path $env:LOCALAPPDATA\"Microsoft\TokenBroker" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    Get-ChildItem -Path $env:LOCALAPPDATA\"Microsoft\IdentityCache" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
} catch{ 
    echo $_
} 
Write-Host "The Microsoft Teams and user authentication cache were cleared."

# Re-start Microsoft Teams
Write-Host "Starting Microsoft Teams."
Start-Process -FilePath "explorer.exe" -ArgumentList "shell:AppsFolder\MSTeams_8wekyb3d8bbwe!MSTeams"
'@
 
# Creates custom folder and writes PS script to it

$scriptFolder = "$env:ProgramData\CustomScripts"
$scriptFullPath = Join-Path $scriptFolder \ClearMSTeamsAndAuthenticationData.ps1
If (!(Test-Path $scriptFolder)) { New-Item -Path $scriptFolder -ItemType Directory -Force -Confirm:$false }
Out-File -FilePath $scriptFullPath -Encoding unicode -Force -InputObject $content -Confirm:$false
 
# Register the script as a scheduled task

$taskName = "Clear Microsoft Teams and Authentication Data on device lock"
$Path = 'PowerShell.exe'
$Arguments = "-ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File `"$scriptFullPath`""

$Service = new-object -ComObject ("Schedule.Service")
$Service.Connect()
$RootFolder = $Service.GetFolder("\")
$TaskDefinition = $Service.NewTask(0) # TaskDefinition object https://msdn.microsoft.com/en-us/library/windows/desktop/aa382542(v=vs.85).aspx
$TaskDefinition.RegistrationInfo.Description = '' # Description of the task.
$TaskDefinition.Settings.Enabled = $True # The task is enabled.
$TaskDefinition.Settings.AllowDemandStart = $True # The task can be run by using the Run command or the Context menu.
$TaskDefinition.Settings.AllowHardTerminate = $True # Indicates that the task may be terminated by the Task Scheduler service using TerminateProcess.
$TaskDefinition.Settings.DisallowStartIfOnBatteries = $False # The task will be started if the computer is running on batteries.
$TaskDefinition.Settings.MultipleInstances = 0 # Starts a new instance while an existing instance of the task is running.
$TaskDefinition.Settings.ExecutionTimeLimit = 'PT5M' # Sets the amount of time that is allowed to complete the task to 5 minutes.
$Triggers = $TaskDefinition.Triggers

# 4800 The workstation was locked
$Trigger = $Triggers.Create(0) ## 0 is an event trigger https://msdn.microsoft.com/en-us/library/windows/desktop/aa383898(v=vs.85).aspx
$Trigger.Enabled = $true
$Trigger.Id = '4800' # 4800 The workstation was locked
$Trigger.Subscription = "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[Provider[@Name='Microsoft-Windows-Security-Auditing'] and EventID=4800]]</Select></Query></QueryList>"

# 4802 The screen saver was invoked
$Trigger = $Triggers.Create(0) ## 0 is an event trigger https://msdn.microsoft.com/en-us/library/windows/desktop/aa383898(v=vs.85).aspx
$Trigger.Enabled = $true
$Trigger.Id = '4802' # 4802 The screen saver was invoked
$Trigger.Subscription = "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[Provider[@Name='Microsoft-Windows-Security-Auditing'] and EventID=4802]]</Select></Query></QueryList>"

$Action = $TaskDefinition.Actions.Create(0)
$Action.Path = $Path
$action.Arguments = $Arguments
$RootFolder.RegisterTaskDefinition($taskName, $TaskDefinition, 6, "S-1-5-32-545", $null, 4) | Out-Null

# Set registry key to prevent Entra ID device registration prompt
$RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin'
$RegValue     	= 'BlockAADWorkplaceJoin'
$Value    	= '1'

# Create the key if it does not exist
If (-NOT (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}  

# Set the value
$RegKey = Get-Item -Path $RegPath -ErrorAction SilentlyContinue
If ($RegKey.GetValueNames() -contains $RegValue) {
    Set-ItemProperty -Path $RegPath -Name $RegValue -Value $Value | Out-Null
}
Else {
    New-ItemProperty -Path $RegPath -Name $RegValue -Value $Value -PropertyType DWORD -Force | Out-Null
}
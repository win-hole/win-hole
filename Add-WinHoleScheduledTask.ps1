#requires -version 5 
#requires -modules ScheduledTasks
#requires -RunAsAdministrator

# creates scheduled tasks that will update the black lists daily

##### INITIALIZE #####

# import global settings
$settings = Get-Content .\settings.json | ConvertFrom-Json

# path to save files and log
[string]$script:dataPath = $settings.savePath

# log filename
[string]$script:logName = $settings.logName

# task name
[string]$schTaskName = $settings.schTaskName

# task username is SYSTEM so no passwords need to be stored in plain text
[string]$schTaskUser = "NT AUTHORITY\SYSTEM"

# start time of the daily update
[string]$schTaskStartTime = "3:30am"

# random delay of the start time
[timespan]$schTaskRndmDly = New-TimeSpan -Minutes 30

# execution time limit for the task
[timespan]$schTaskExecTimeLmt = New-TimeSpan -Minutes 120

# restart interval for the task
[timespan]$schTaskRsrtIntvl = New-TimeSpan -Minutes 5

# task restart count
[int]$schTaskRsrtCnt = 3



##### FUNCTIONS #####
#region

# load common functions
. $PSScriptRoot\Load-WinHoleFunctions.ps1

#endregion FUNCTIONS


##### MAIN #####

# create start-clustertrace task       
$taskAction = "powershell.exe"
$taskArgument = "-NonInteractive -NoProfile -ExecutionPolicy Bypass -file `"$Script:dataPath\bin\Update-WinHoleBlackList.ps1`""
$taskDescription = 'Updates the blacklist. Updates are daily (default).'
$taskAction = New-ScheduledTaskAction -WorkingDirectory "$Script:dataPath\bin" –Execute $taskAction -Argument $taskArgument
$taskTrigger = New-ScheduledTaskTrigger -Daily -At $schTaskStartTime -RandomDelay $schTaskRndmDly
$taskSettings = New-ScheduledTaskSettingsSet -Compatibility Win8 -MultipleInstances IgnoreNew -ExecutionTimeLimit $schTaskExecTimeLmt -RestartInterval $schTaskRsrtIntvl -RestartCount $schTaskRsrtCnt

try {
    Register-ScheduledTask -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -TaskName $schTaskName -Description $taskDescription -User $schTaskUser -RunLevel Highest -Force -ErrorAction Stop
} catch {
   Write-Log "The scheduled task could not be created: $($error[0].ToString())"
} 

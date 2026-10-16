param([string]$RunId,[string]$Scenario='Both')
$ErrorActionPreference='Stop'
$root='C:\AutoFrogE2E'
$task="AutoFrogE2E-$RunId-controller"
$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ("-NoProfile -ExecutionPolicy Bypass -File $root\run-e2e.ps1 -RunId $RunId -Scenario $Scenario")
$p=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$s=New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 100)
Register-ScheduledTask -TaskName $task -Action $a -Principal $p -Settings $s -Force | Out-Null
Start-ScheduledTask -TaskName $task
Write-Output $task

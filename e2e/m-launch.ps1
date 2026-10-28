# 실행 방식 시험(2026-10-28) — SSH 에서 제어부를 SYSTEM 예약 작업으로 띄운다(SSH 가 끊겨도 계속 돈다).
param([string]$RunId,[string]$Tests='T1,T2a,T2b,T3,T4')
$ErrorActionPreference='Stop'
$root='C:\AutoFrogE2E'
$task="AutoFrogE2E-$RunId-mctl"
$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File $root\m-host.ps1 -RunId $RunId -Tests $Tests"
$p=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$s=New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 6)
Register-ScheduledTask -TaskName $task -Action $a -Principal $p -Settings $s -Force | Out-Null
Start-ScheduledTask -TaskName $task
Write-Output $task

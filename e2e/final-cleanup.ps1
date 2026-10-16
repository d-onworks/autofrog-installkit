param([string]$RunId)
$ErrorActionPreference='Stop'
$r='C:\AutoFrogE2E'
$tasks=@(Get-ScheduledTask | Where-Object TaskName -like 'AutoFrogE2E-*')
if(@($tasks | Where-Object State -eq 'Running').Count){throw 'E2E task still running; refusing premature cleanup'}
foreach($t in $tasks){Unregister-ScheduledTask -TaskName $t.TaskName -Confirm:$false}
& "$r\cleanup.ps1" -ReportPath "$r\$RunId\final-cleanup-vm.json"
if($LASTEXITCODE -eq 3){throw 'Sandbox VM remains'}
$staleStatus=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -match '-File\s+"?C:\\AutoFrogE2E\\status\.ps1' })
foreach($p in $staleStatus){Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue}
$o=@{removedStatusProcesses=@($staleStatus.ProcessId);time=(Get-Date).ToString('o');removedTasks=@($tasks.TaskName);remainingTasks=@(Get-ScheduledTask | Where-Object TaskName -like 'AutoFrogE2E-*' | Select-Object TaskName,State);remainingProcesses=@(Get-Process WindowsSandbox*,vmmemWindowsSandbox -ErrorAction SilentlyContinue | Select-Object Name,Id)}
[IO.File]::WriteAllText("$r\$RunId\final-cleanup.json",($o | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding $false))

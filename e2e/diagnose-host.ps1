$ErrorActionPreference='Stop'
$task='AutoFrogE2E-capture'
try {
 $a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\AutoFrogE2E\capture-sandbox.ps1'
 $p=New-ScheduledTaskPrincipal -UserId '오토프로그' -LogonType Interactive -RunLevel Highest
 Register-ScheduledTask -TaskName $task -Action $a -Principal $p | Out-Null
 Start-ScheduledTask -TaskName $task
 Start-Sleep 3
 $result=(Get-ScheduledTaskInfo -TaskName $task).LastTaskResult
} finally { Unregister-ScheduledTask -TaskName $task -Confirm:$false }
$o=@{captureResult=$result;apps=@(Get-AppxPackage -AllUsers '*WindowsSandbox*' | Select-Object Name,Version,InstallLocation);processes=@(Get-Process WindowsSandbox* | Select-Object Name,Id,CPU,Path);boot=@(Get-Content C:\AutoFrogE2E\20261016-092855\S1\boot-console.log -Encoding UTF8 -Tail 20 -ErrorAction SilentlyContinue)}
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($o | ConvertTo-Json -Depth 6 -Compress)))

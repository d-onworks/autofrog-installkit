param([string]$Action='list',[string]$SandboxId='')
$ErrorActionPreference='Stop'
$t='AutoFrogE2E-cli'
try {
 $a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File C:\AutoFrogE2E\interactive-cli.ps1 -Action '+$Action+' -SandboxId "'+$SandboxId+'"')
 $p=New-ScheduledTaskPrincipal -UserId '오토프로그' -LogonType Interactive -RunLevel Highest
 Register-ScheduledTask -TaskName $t -Action $a -Principal $p | Out-Null; Start-ScheduledTask -TaskName $t
 Start-Sleep 3
 $deadline=(Get-Date).AddSeconds(40)
 while ((Get-ScheduledTask -TaskName $t).State -eq 'Running' -and (Get-Date) -lt $deadline) { Start-Sleep 2 }
 $o=@{taskResult=(Get-ScheduledTaskInfo -TaskName $t).LastTaskResult;result=(Get-Content "C:\AutoFrogE2E\20261016-092855\cli-$Action.json" -Raw -Encoding UTF8 | ConvertFrom-Json)}
 [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($o | ConvertTo-Json -Depth 8 -Compress)))
} finally { Unregister-ScheduledTask -TaskName $t -Confirm:$false }

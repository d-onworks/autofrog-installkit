# 로그인 E2E 호스트 쪽 — 기존 샌드박스를 정리하고, 로그인 시나리오(L1) 샌드박스를 오토프로그 화면에 띄운 뒤 바로 끝난다.
# 진행 확인은 login-status.ps1, 키 입력은 login-send.ps1. 다 끝나면 cleanup.ps1 로 닫는다.
param([Parameter(Mandatory)][string]$RunId,[string]$ZipPath='C:\AutoFrogE2E\autofrog-setup-kit-20261016.zip')
$ErrorActionPreference='Stop'
$Root='C:\AutoFrogE2E'
if ($RunId -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid RunId' }
$dir=Join-Path $Root "$RunId\L1"
New-Item -ItemType Directory -Force $dir | Out-Null
& icacls.exe $Root /grant '오토프로그:(OI)(CI)M' /Q | Out-Null
& (Join-Path $Root 'cleanup.ps1') -ReportPath (Join-Path $Root "$RunId\cleanup-before.json")
if ($LASTEXITCODE -eq 3) { throw 'Sandbox VM cleanup failed' }
foreach ($n in @('login-inside.ps1','console-bridge.ps1','visible-install.ps1')) { Copy-Item (Join-Path $Root $n) (Join-Path $dir $n) -Force }
Copy-Item $ZipPath (Join-Path $dir 'kit.zip') -Force
[IO.File]::WriteAllText((Join-Path $dir 'start.cmd'),"@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\e2e\login-inside.ps1 > C:\e2e\boot-console.log 2>&1`r`n",[Text.Encoding]::ASCII)
$escaped=[Security.SecurityElement]::Escape($dir)
$wsb=@"
<Configuration>
  <Networking>Enable</Networking><VGpu>Disable</VGpu><MemoryInMB>8192</MemoryInMB><ClipboardRedirection>Disable</ClipboardRedirection>
  <MappedFolders><MappedFolder><HostFolder>$escaped</HostFolder><SandboxFolder>C:\e2e</SandboxFolder><ReadOnly>false</ReadOnly></MappedFolder></MappedFolders>
  <LogonCommand><Command>cmd.exe /d /c C:\e2e\start.cmd</Command></LogonCommand>
</Configuration>
"@
$wsbPath=Join-Path $dir 'L1.wsb'; [IO.File]::WriteAllText($wsbPath,$wsb,(New-Object Text.UTF8Encoding $true))
$task="AutoFrogE2E-$RunId-L1"
if (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $task -Confirm:$false }
$action=New-ScheduledTaskAction -Execute "$env:WINDIR\System32\WindowsSandbox.exe" -Argument ('"'+$wsbPath+'"')
$principal=New-ScheduledTaskPrincipal -UserId '오토프로그' -LogonType Interactive -RunLevel Highest
$settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 120)
Register-ScheduledTask -TaskName $task -Action $action -Principal $principal -Settings $settings | Out-Null
Start-ScheduledTask -TaskName $task
Write-Output "started $task"

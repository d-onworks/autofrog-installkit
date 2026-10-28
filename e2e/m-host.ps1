# 실행 방식 시험(2026-10-28) — 집 PC 제어부(SYSTEM 예약 작업). 시험마다 새 샌드박스를 띄우고 끝나면 지운다.
param([string]$RunId,[string]$Tests='T1,T2a,T2b,T3,T4',[int]$TimeoutMinutes=60)
$ErrorActionPreference='Stop'
$Root='C:\AutoFrogE2E'
if ($RunId -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid RunId' }
$RunRoot=Join-Path $Root $RunId
New-Item -ItemType Directory -Force $RunRoot | Out-Null
function Save-Json($Object,[string]$Path) { [IO.File]::WriteAllText($Path,($Object | ConvertTo-Json -Depth 12),(New-Object Text.UTF8Encoding $false)) }
& icacls.exe $Root /grant '오토프로그:(OI)(CI)M' /Q | Out-Null
$ready=$false
for ($i=0;$i -le 20;$i++) {
  $old=$ErrorActionPreference; $ErrorActionPreference='Continue'
  $q=(& query.exe user 2>&1 | Out-String); $ErrorActionPreference=$old
  if ($q -match '(?m)오토프로그\s+.*\s(Active|활성)\s') { $ready=$true; break }
  Start-Sleep 60
}
if (-not $ready) { Save-Json @{status='BLOCKED';reason='no active session'} (Join-Path $RunRoot 'host-result.json'); exit 2 }
& (Join-Path $Root 'cleanup.ps1') -ReportPath (Join-Path $RunRoot 'cleanup-before.json')
if ($LASTEXITCODE -eq 3) { throw 'Sandbox VM cleanup failed' }
$results=@()
foreach ($t in $Tests.Split(',')) {
  $dir=Join-Path $RunRoot $t; New-Item -ItemType Directory -Force $dir | Out-Null
  foreach ($name in @('m-inside.ps1','m-bridge.ps1','m-shots.ps1','m-serve.ps1','m-probe.ps1','m-elevate.ps1','probe.ps1')) { Copy-Item (Join-Path $Root $name) (Join-Path $dir $name) -Force }
  $start="@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\e2e\m-inside.ps1 -Test $t > C:\e2e\boot-console.log 2>&1`r`n"
  [IO.File]::WriteAllText((Join-Path $dir 'start.cmd'),$start,[Text.Encoding]::ASCII)
  $escaped=[Security.SecurityElement]::Escape($dir)
  $wsb=@"
<Configuration>
  <Networking>Enable</Networking><VGpu>Disable</VGpu><MemoryInMB>8192</MemoryInMB>
  <MappedFolders><MappedFolder><HostFolder>$escaped</HostFolder><SandboxFolder>C:\e2e</SandboxFolder><ReadOnly>false</ReadOnly></MappedFolder></MappedFolders>
  <LogonCommand><Command>cmd.exe /d /c C:\e2e\start.cmd</Command></LogonCommand>
</Configuration>
"@
  $wsbPath=Join-Path $dir "$t.wsb"; [IO.File]::WriteAllText($wsbPath,$wsb,(New-Object Text.UTF8Encoding $true))
  $task="AutoFrogE2E-$RunId-$t"; $started=Get-Date
  try {
    $action=New-ScheduledTaskAction -Execute "$env:WINDIR\System32\WindowsSandbox.exe" -Argument ('"'+$wsbPath+'"')
    $principal=New-ScheduledTaskPrincipal -UserId '오토프로그' -LogonType Interactive -RunLevel Highest
    $settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::FromMinutes($TimeoutMinutes+2))
    Register-ScheduledTask -TaskName $task -Action $action -Principal $principal -Settings $settings | Out-Null
    Start-ScheduledTask -TaskName $task
    $deadline=$started.AddMinutes($TimeoutMinutes); $marker=Join-Path $dir 'out\done.json'
    while ((Get-Date) -lt $deadline -and -not (Test-Path $marker)) {
      $pids=@(Get-Process WindowsSandbox* -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
      if (((Get-Date)-$started).TotalSeconds -gt 150 -and $pids.Count -eq 0 -and -not (Test-Path (Join-Path $dir 'out'))) { throw 'Sandbox did not start' }
      Save-Json @{test=$t;state='RUNNING';elapsedSec=[int]((Get-Date)-$started).TotalSeconds;pids=$pids} (Join-Path $RunRoot 'host-progress.json')
      Start-Sleep 5
    }
    $results+=@{test=$t;done=(Test-Path $marker);sec=[math]::Round(((Get-Date)-$started).TotalSeconds,1)}
  } catch { $results+=@{test=$t;error=$_.Exception.Message} }
  finally {
    if (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $task -Confirm:$false }
    & (Join-Path $Root 'cleanup.ps1') -ReportPath (Join-Path $dir 'cleanup.json')
  }
  Save-Json $results (Join-Path $RunRoot 'host-result.json')
}
Save-Json @{finished=(Get-Date).ToString('o');results=$results} (Join-Path $RunRoot 'host-finished.json')

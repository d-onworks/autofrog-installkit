# 실행 방식 시험(2026-10-28) T2b — 표준 사용자 PC 에서 "관리자로 실행"에 관리자 계정을 넣은 상황.
# 이 스크립트는 관리자 계정(pcadmin)으로 돌고, 승격된(RunAs) PowerShell 창을 띄워 브리지가 명령을 치게 한다.
param([string]$Out)
$ErrorActionPreference='Continue'
New-Item -ItemType Directory -Force $Out | Out-Null
$id=[Security.Principal.WindowsIdentity]::GetCurrent()
$elev=(New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$r=[ordered]@{helperUser=$id.Name;helperElevated=$elev;runas=$null;error=$null}
try {
  Start-Process "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File C:\e2e\m-bridge.ps1 -Mode Launch -Out $Out"
  $r.runas='ok'
} catch {
  $r.error=$_.Exception.Message
  Start-Process "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File C:\e2e\m-bridge.ps1 -Mode Launch -Out $Out"
  $r.runas='fallback-no-runas'
}
[IO.File]::WriteAllText((Join-Path $Out 'elevate.json'),($r|ConvertTo-Json),(New-Object Text.UTF8Encoding $false))

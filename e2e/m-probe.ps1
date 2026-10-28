# 실행 방식 시험(2026-10-28) — 설치한 계정으로 "새 터미널"을 연 것처럼 probe.ps1 을 돌려 결과를 파일로 남긴다.
param([string]$OutFile)
$ErrorActionPreference='Continue'
$machine=[Environment]::GetEnvironmentVariable('Path','Machine'); $user=[Environment]::GetEnvironmentVariable('Path','User')
$env:PATH="$user;$machine"
Remove-Item Env:\PSExecutionPolicyPreference -ErrorAction SilentlyContinue
$o=& "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -File C:\e2e\probe.ps1 2>&1 | Out-String
[IO.File]::WriteAllText($OutFile,$o,(New-Object Text.UTF8Encoding $false))

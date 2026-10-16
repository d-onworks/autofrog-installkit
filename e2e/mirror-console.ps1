param([string]$Scenario='S2')
$ErrorActionPreference='Continue'
$host.UI.RawUI.WindowTitle='AutoFrog S2 - standard user live log'
while (-not (Test-Path "C:\e2e\out\$Scenario\monitor-stop.txt")) {
 Clear-Host;Write-Host '수강생(표준 사용자) 설치 로그 — 끝 40줄' -ForegroundColor Cyan
 $p="C:\e2e\out\$Scenario\progress.json";if(Test-Path $p){Write-Host ([IO.File]::ReadAllText($p))}
 $latest=Get-ChildItem "C:\e2e\out\$Scenario" -Filter 'install-*.live-setup.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
 if ($latest) { Get-Content $latest.FullName -Tail 40 -Encoding UTF8 | ForEach-Object { Write-Host $_ } }
 Start-Sleep 2
}
Start-Sleep 5

# 수강생이 Win+R 에 붙여 넣는 한 줄과 같은 명령을 보이는 창에서 돌린다(주소는 샌드박스 안 시험 서버, live.flag 가 있으면 진짜 주소).
param([string]$Prefix,[string]$Scenario,[string]$Label)
$ErrorActionPreference='Continue'
[Console]::OutputEncoding=New-Object Text.UTF8Encoding $false
$OutputEncoding=[Console]::OutputEncoding
$host.UI.RawUI.WindowTitle="AutoFrog $Scenario - $Label (one-liner)"
Write-Host "AutoFrog E2E $Scenario $Label - one-line installer"
# C:\e2e\live.flag 가 있으면 진짜 주소(autofrog.kr → 최신 릴리즈)로 — 수강생과 똑같은 한 줄
$live=Test-Path 'C:\e2e\live.flag'
$kitUrl=if ($live) { 'https://autofrog.kr/kit.ps1' } else { 'http://localhost:8765/kit.ps1' }
if ($live) { Remove-Item Env:\AUTOFROG_KIT_ZIP -ErrorAction SilentlyContinue } else { $env:AUTOFROG_KIT_ZIP='http://localhost:8765/autofrog-setup-kit.zip' }
Write-Host "kit url: $kitUrl"
$env:AUTOFROG_AUTO='1'
Remove-Item Env:\PSExecutionPolicyPreference -ErrorAction SilentlyContinue
$logs=Join-Path $env:USERPROFILE 'autofrog-kit-logs'
$before=if (Test-Path "$logs\result-latest.json") { (Get-Item "$logs\result-latest.json").LastWriteTime } else { [datetime]::MinValue }
$sw=[Diagnostics.Stopwatch]::StartNew()
# C:\e2e\twoline.flag = 2번 명령(2026-10-22 · 백신이 irm|iex 한 줄을 막는 PC 용 — 받아 저장한 뒤 -File 로 실행).
#   내용 'cmd' = Win+R 처럼 cmd 가 그대로 넘김 / 'ps' = 이미 열린 PowerShell 창에 붙여 넣은 경우($env:TEMP 를 바깥 셸이 먼저 푼다)
$two=if (Test-Path 'C:\e2e\twoline.flag') { (Get-Content 'C:\e2e\twoline.flag' -Raw).Trim() } else { '' }
if ($two -eq 'cmd') {
    Write-Host 'command: 2 (via cmd, like Win+R)'
    & $env:ComSpec /d /c ('powershell -NoProfile -c "irm '+$kitUrl+' -OutFile $env:TEMP\af.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File $env:TEMP\af.ps1"') 2>&1 | Tee-Object -FilePath "$Prefix.stdout.log"
} elseif ($two -eq 'ps') {
    Write-Host 'command: 2 (pasted into PowerShell)'
    & powershell -NoProfile -c "irm $kitUrl -OutFile $env:TEMP\af.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File $env:TEMP\af.ps1" 2>&1 | Tee-Object -FilePath "$Prefix.stdout.log"
} else {
    & powershell.exe -ExecutionPolicy Bypass -c "irm $kitUrl | iex" 2>&1 | Tee-Object -FilePath "$Prefix.stdout.log"
}
$psExit=$LASTEXITCODE; $sw.Stop()
$rc=1; $fresh=$false
if (Test-Path "$logs\result-latest.json") {
    $j=[IO.File]::ReadAllText("$logs\result-latest.json") | ConvertFrom-Json
    $fresh=((Get-Item "$logs\result-latest.json").LastWriteTime -gt $before)
    if ($fresh -and $j.allOk) { $rc=0 }
    Clear-Host
    Write-Host "AutoFrog E2E $Scenario $Label - final version table" -ForegroundColor Cyan
    foreach ($row in $j.verify.PSObject.Properties) { $state=if($row.Value.ok){' OK '}else{'실패'}; Write-Host ('[{0}] {1,-10} {2}' -f $state,$row.Name,$row.Value.version) }
    foreach ($row in $j.steps.PSObject.Properties) { Write-Host ('step {0,-10} {1}' -f $row.Name,$row.Value.state) }
}
Write-Host "`nexit(by result)=$rc psExit=$psExit freshResult=$fresh seconds=$([math]::Round($sw.Elapsed.TotalSeconds,2))"
[IO.File]::WriteAllText("$Prefix.exit.json",(@{exit=$rc;psExit=$psExit;freshResult=$fresh;sec=[math]::Round($sw.Elapsed.TotalSeconds,2);timeout=$false} | ConvertTo-Json),(New-Object Text.UTF8Encoding $false))
Start-Sleep 18
exit $rc

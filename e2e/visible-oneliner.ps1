# 수강생이 Win+R 에 붙여 넣는 한 줄과 같은 명령을 보이는 창에서 돌린다(주소만 샌드박스 안 시험 서버).
param([string]$Prefix,[string]$Scenario,[string]$Label)
$ErrorActionPreference='Continue'
[Console]::OutputEncoding=New-Object Text.UTF8Encoding $false
$OutputEncoding=[Console]::OutputEncoding
$host.UI.RawUI.WindowTitle="AutoFrog $Scenario - $Label (one-liner)"
Write-Host "AutoFrog E2E $Scenario $Label - one-line installer"
$env:AUTOFROG_KIT_ZIP='http://localhost:8765/autofrog-setup-kit.zip'
$env:AUTOFROG_AUTO='1'
Remove-Item Env:\PSExecutionPolicyPreference -ErrorAction SilentlyContinue
$logs=Join-Path $env:USERPROFILE 'autofrog-kit-logs'
$before=if (Test-Path "$logs\result-latest.json") { (Get-Item "$logs\result-latest.json").LastWriteTime } else { [datetime]::MinValue }
$sw=[Diagnostics.Stopwatch]::StartNew()
& powershell.exe -ExecutionPolicy Bypass -c "irm http://localhost:8765/kit.ps1 | iex" 2>&1 | Tee-Object -FilePath "$Prefix.stdout.log"
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

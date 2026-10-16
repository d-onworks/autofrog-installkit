param([string]$Bat,[string]$Prefix,[string]$Scenario,[string]$Label)
$ErrorActionPreference='Continue'
[Console]::OutputEncoding=New-Object Text.UTF8Encoding $false
$OutputEncoding=[Console]::OutputEncoding
$host.UI.RawUI.WindowTitle="AutoFrog $Scenario - $Label"
Add-Type @'
using System; using System.Runtime.InteropServices;
public class E2EConsole {
 [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
}
'@
[void][E2EConsole]::ShowWindow([E2EConsole]::GetConsoleWindow(),3)
Write-Host "AutoFrog E2E $Scenario $Label - visible installer"
$sw=[Diagnostics.Stopwatch]::StartNew()
& $env:ComSpec /d /c ('""'+$Bat+'" /auto"') 2>&1 | Tee-Object -FilePath "$Prefix.stdout.log"
$rc=$LASTEXITCODE; $sw.Stop()
# 결과 표가 화면 아래로 밀리지 않게, 원본 로그는 보존하고 마지막 화면에 다시 표시한다.
Clear-Host
Write-Host "AutoFrog E2E $Scenario $Label - final version table" -ForegroundColor Cyan
$report=Join-Path $env:USERPROFILE 'autofrog-kit-logs\result-latest.json'
if (Test-Path $report) {
 $j=[IO.File]::ReadAllText($report) | ConvertFrom-Json
 foreach ($row in $j.verify.PSObject.Properties) {
  $state=if($row.Value.ok){' OK '}else{'실패'}
  Write-Host ('[{0}] {1,-10} {2}' -f $state,$row.Name,$row.Value.version)
 }
 foreach($row in $j.steps.PSObject.Properties) { Write-Host ('step {0,-10} {1}' -f $row.Name,$row.Value.state) }
}
Write-Host "`nInstaller exit=$rc; seconds=$([math]::Round($sw.Elapsed.TotalSeconds,2))"
[IO.File]::WriteAllText("$Prefix.exit.json",(@{exit=$rc;sec=[math]::Round($sw.Elapsed.TotalSeconds,2);timeout=$false} | ConvertTo-Json),(New-Object Text.UTF8Encoding $false))
Start-Sleep 18
exit $rc

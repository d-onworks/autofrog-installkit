param([string]$Scenario='S1')
$ErrorActionPreference='Continue'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$out="C:\e2e\out\$Scenario";$screens=Join-Path $out 'screens';New-Item -ItemType Directory -Force $screens | Out-Null
function Shot([string]$Tag) {
 try {
  $r=[Windows.Forms.SystemInformation]::VirtualScreen
  $b=New-Object Drawing.Bitmap($r.Width,$r.Height);$g=[Drawing.Graphics]::FromImage($b)
  $g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size)
  $path=Join-Path $screens ((Get-Date -Format 'HHmmss_fff')+'_'+$Tag+'.png')
  $b.Save($path,[Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$b.Dispose()
 } catch { [IO.File]::AppendAllText((Join-Path $out 'capture-errors.log'),($_.Exception.Message+"`r`n")) }
}
$seen=@{};$last=(Get-Date).AddSeconds(-60);$lastPhase='';$warningSeen=@{}
while (-not (Test-Path (Join-Path $out 'monitor-stop.txt'))) {
 $phase='';try { $phase=(Get-Content (Join-Path $out 'progress.json') -Raw -Encoding UTF8 | ConvertFrom-Json).phase } catch {}
 if ($phase -in 'install-1','install-2') {
  if ($phase -ne $lastPhase) { Start-Sleep 2;Shot ($phase+'-start');$last=Get-Date }
  if (((Get-Date)-$last).TotalSeconds -ge 60) { Shot ($phase+'-periodic');$last=Get-Date }
 }
 foreach ($label in @('install-1','install-2')) {
  $log=Join-Path $out "$label.live-setup.log"
  if (Test-Path $log) {
   $warnings=@(Get-Content $log -Encoding UTF8 -Tail 100 | Where-Object { $_ -match '\[(실패|주의)\]' })
   if ($warnings.Count -gt 0) { $key=$label+':'+$warnings[-1];if (-not $warningSeen.ContainsKey($key)) { Shot ($label+'-warning');$warningSeen[$key]=$true } }
  }
  $f=Join-Path $out "$label.exit.json"
  if ((Test-Path $f) -and -not $seen.ContainsKey($f)) {
   $seen[$f]=$true;$v=Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json
   if ($v.exit -ne 0) { Shot ($label+'-exit-fail') }
   if ($label -eq 'install-1') { Shot 'final-version-table' } else { Shot 'idempotent-end' }
  }
 }
 if ($phase -eq 'complete' -and $lastPhase -ne 'complete') { Shot 'scenario-complete' }
 $lastPhase=$phase;Start-Sleep 2
}
Shot 'monitor-end'

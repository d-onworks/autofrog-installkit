# 실행 방식 시험(2026-10-28) — 진행 상황을 base64 JSON 으로 돌려준다(맥에서 풀어 본다).
param([string]$RunId)
$r=Join-Path 'C:\AutoFrogE2E' $RunId
$o=[ordered]@{time=(Get-Date).ToString('o');processes=@(Get-Process WindowsSandbox*,vmmemWindowsSandbox -ErrorAction SilentlyContinue | Select-Object Name,Id);tasks=@(Get-ScheduledTask | Where-Object TaskName -like "AutoFrogE2E-$RunId-*" | Select-Object TaskName,@{n='State';e={[string]$_.State}});files=[ordered]@{}}
foreach ($n in 'host-progress.json','host-result.json','host-finished.json') { $p=Join-Path $r $n; if (Test-Path $p) { try { $o.files[$n]=[IO.File]::ReadAllText($p) | ConvertFrom-Json } catch {} } }
foreach ($t in @(Get-ChildItem $r -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)) {
  $d=Join-Path $r "$t\out"; if (-not (Test-Path $d)) { continue }
  $x=[ordered]@{}
  foreach ($n in 'progress.json','error.json','done.json') { $p=Join-Path $d $n; if (Test-Path $p) { try { $x[$n]=[IO.File]::ReadAllText($p) | ConvertFrom-Json } catch {} } }
  $x.screens=@(Get-ChildItem "$d\screens" -ErrorAction SilentlyContinue).Count
  $x.insideTail=@(if (Test-Path "$d\inside.log") { [IO.File]::ReadAllLines("$d\inside.log") | Select-Object -Last 4 })
  $c=Get-ChildItem $d -Recurse -Filter 'console.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($c) { $x.console=$c.FullName.Substring($d.Length); $x.consoleTail=@([IO.File]::ReadAllLines($c.FullName) | Where-Object { $_.Trim() } | Select-Object -Last 6) }
  $o.files[$t]=$x
}
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($o | ConvertTo-Json -Depth 8 -Compress)))

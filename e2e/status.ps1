param([string]$RunId='20261016-092855')
$r=Join-Path 'C:\AutoFrogE2E' $RunId
$o=[ordered]@{time=(Get-Date).ToString('o');files=[ordered]@{};processes=@(Get-Process WindowsSandbox* -ErrorAction SilentlyContinue | Select-Object Name,Id,SessionId);tasks=@(Get-ScheduledTask | Where-Object TaskName -like "AutoFrogE2E-$RunId-*" | Select-Object TaskName,State)}
foreach ($name in @('host-progress.json','host-result.json','host-session.json','S1\out\S1\progress.json','S1\out\S1\error-Boot.json','S1\out\S1\error-Worker.json','S1\out\S1\done.json','S2\out\S2\progress.json','S2\out\S2\error-Boot.json','S2\out\S2\error-Worker.json','S2\out\S2\done.json')) {
 $p=Join-Path $r $name; if (Test-Path $p) { try { $o.files[$name]=Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} }
}
foreach ($s in @('S1','S2')) { $lp=Join-Path $r "$s\out\$s\install-1.live-setup.log"; if (Test-Path $lp) { $o.files["$s-live-tail"]=@([IO.File]::ReadAllLines($lp) | Select-Object -Last 12) };  $p=Join-Path $r "$s\out\$s\install-1.stdout.log"; if (Test-Path $p) { $o.files["$s-install-size"]=(Get-Item $p).Length } }
$o.processes=@(Get-Process WindowsSandbox*,vmmemWindowsSandbox -ErrorAction SilentlyContinue | Select-Object Name,Id,SessionId)
foreach ($s in @('S1','S2')) {
 $d=Join-Path $r "$s\out\$s"
 $o.files["$s-screens"]=@(Get-ChildItem "$d\screens" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 3 Name,Length)
 foreach ($f in @('result-first.json','result-second.json','worker-done.json','fresh.process.json','login.process.json','command-checks.json','command-checks.process.json')) {
  $fp=Join-Path $d $f
  if(Test-Path $fp){$o.files["$s-$f"]=[IO.File]::ReadAllText($fp) | ConvertFrom-Json}
 }
}
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($o | ConvertTo-Json -Depth 15 -Compress)))

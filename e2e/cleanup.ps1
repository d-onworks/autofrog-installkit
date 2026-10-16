param([string]$ReportPath='C:\AutoFrogE2E\cleanup-latest.json')
$ErrorActionPreference='Continue'
$before=@(Get-Process WindowsSandbox*,vmmemWindowsSandbox -ErrorAction SilentlyContinue | Select-Object Name,Id)
Get-Process WindowsSandbox* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 2
$raw=(& hcsdiag.exe list 2>&1 | Out-String)
$kills=@()
$vmMatches=[regex]::Matches($raw,'(?im)^\s*([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})\s*\r?$')
for ($i=0;$i -lt $vmMatches.Count;$i++) {
 $start=$vmMatches[$i].Index; $end=$raw.Length; if ($i+1 -lt $vmMatches.Count) { $end=$vmMatches[$i+1].Index }
 $block=$raw.Substring($start,$end-$start)
 if ($block -match '(?i)Windows\s*Sandbox|DisposableClientVM') {
  $vmId=$vmMatches[$i].Groups[1].Value
  $msg=@(& hcsdiag.exe kill $vmId 2>&1 | ForEach-Object { "$_" })
  $kills+=@{id=$vmId;exit=$LASTEXITCODE;output=$msg}
 }
}
$deadline=(Get-Date).AddSeconds(60)
while ((Get-Process vmmemWindowsSandbox -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep 2 }
$remaining=@(Get-Process WindowsSandbox*,vmmemWindowsSandbox -ErrorAction SilentlyContinue | Select-Object Name,Id)
$o=@{time=(Get-Date).ToString('o');before=$before;hcsBefore=$raw;kills=$kills;remaining=$remaining;clean=($remaining.Count -eq 0);hcsAfter=@(& hcsdiag.exe list 2>&1 | ForEach-Object { "$_" })}
[IO.File]::WriteAllText($ReportPath,($o | ConvertTo-Json -Depth 6),(New-Object Text.UTF8Encoding $false))
if (-not $o.clean) { exit 3 }

# 로그인 E2E 진행 상황 — 단계·콘솔 끝부분·결과 파일을 base64 JSON 으로 돌려준다(한글 깨짐 방지)
param([Parameter(Mandatory)][string]$RunId,[int]$Tail=45)
$o=Join-Path 'C:\AutoFrogE2E' "$RunId\L1\out\L1"
$r=[ordered]@{time=(Get-Date).ToString('o');sandbox=@(Get-Process WindowsSandbox* -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)}
foreach ($f in @('progress.json','error.json','done.json','install.exit.json','login-latest.json','login-procs.json','after-login.json')) {
  $p=Join-Path $o $f; if (Test-Path $p) { $r[$f]=[IO.File]::ReadAllText($p) }
}
$c=Join-Path $o 'console.txt'
if (Test-Path $c) { $lines=@([IO.File]::ReadAllLines($c) | Where-Object { $_.Trim() }); $r.console=@($lines | Select-Object -Last $Tail) }
$b=Join-Path $o 'bridge.log'; if (Test-Path $b) { $r.bridge=@([IO.File]::ReadAllLines($b) | Select-Object -Last 6) }
$l=Join-Path $o 'install.live-setup.log'; if ((Test-Path $l) -and -not $r.Contains('console')) { $r.installTail=@([IO.File]::ReadAllLines($l) | Select-Object -Last 6) }
$r.screens=@(Get-ChildItem (Join-Path $o 'screens') -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -ExpandProperty Name)
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($r | ConvertTo-Json -Depth 6 -Compress)))

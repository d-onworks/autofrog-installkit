# 실행 방식 시험(2026-10-28) — 샌드박스 안 작은 시험 서버.
#   /echo.ps1 : 실행됐다는 표시만 찍는다(명령줄 해석 확인용)
#   /amsi.ps1 : 백신이 "악성"으로 잡는 상황을 흉내 낸다(마이크로소프트 공식 AMSI 시험 문자열 — 실제 악성 코드 아님).
#               이 파일 자체가 디스크에서 잡히지 않게 문자열을 실행 중에 이어 붙인다.
param([string]$Out='C:\e2e\out')
$ErrorActionPreference='Continue'
$log=Join-Path $Out 'serve.log'
$echo="Write-Host ''`r`nWrite-Host ('  ECHO-RAN  file=[' + `$PSCommandPath + ']  temp=[' + `$env:TEMP + ']') -ForegroundColor Green`r`n"
$sample='AMSI Test Sample: '+'7e72c3ce-861b'+'-4339-8740-0ac1484c1386'
$amsi="Write-Host 'amsi-sim start'`r`n`$x = '"+$sample+"'`r`nWrite-Host 'amsi-sim end'`r`n"
$l=New-Object Net.HttpListener; $l.Prefixes.Add('http://localhost:8765/'); $l.Start()
Add-Content $log "$(Get-Date -Format o) listening"
while ($l.IsListening) {
  $ctx=$l.GetContext(); $res=$ctx.Response; $p=$ctx.Request.Url.AbsolutePath.TrimStart('/')
  try {
    $body=$null
    if ($p -eq 'echo.ps1') { $body=$echo } elseif ($p -eq 'amsi.ps1') { $body=$amsi }
    if ($body) { $b=[Text.Encoding]::ASCII.GetBytes($body); $res.ContentType='application/octet-stream'; $res.ContentLength64=$b.Length; $res.OutputStream.Write($b,0,$b.Length) } else { $res.StatusCode=404 }
  } catch { Add-Content $log "error $($_.Exception.Message)" }
  Add-Content $log "$(Get-Date -Format o) /$p $($res.StatusCode)"
  try { $res.Close() } catch {}
}

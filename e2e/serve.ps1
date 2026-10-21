# 샌드박스 안 시험용 배포 서버 — autofrog.kr/kit.ps1(넘겨주기) → install.ps1 → 키트 zip 을 흉내 낸다.
# 실제 배포처(Vercel·GitHub)처럼 application/octet-stream 으로 내보내, irm 이 BOM 으로 한글을 읽는지까지 같은 조건에서 본다.
param([string]$Scenario='S1')
$ErrorActionPreference='Continue'
$www='C:\e2e\www'; $log="C:\e2e\out\$Scenario\serve.log"
$l=New-Object Net.HttpListener; $l.Prefixes.Add('http://localhost:8765/'); $l.Start()
Add-Content $log "$(Get-Date -Format o) listening"
while ($l.IsListening) {
    $ctx=$l.GetContext(); $res=$ctx.Response
    $p=$ctx.Request.Url.AbsolutePath.TrimStart('/')
    try {
        if ($p -eq 'kit.ps1') { $res.StatusCode=302; $res.RedirectLocation='http://localhost:8765/install.ps1' }
        else {
            $f=Join-Path $www $p
            if ($p -and (Test-Path -LiteralPath $f -PathType Leaf)) {
                $b=[IO.File]::ReadAllBytes($f); $res.ContentType='application/octet-stream'; $res.ContentLength64=$b.Length
                $res.OutputStream.Write($b,0,$b.Length)
            } else { $res.StatusCode=404 }
        }
    } catch { Add-Content $log "error $($_.Exception.Message)" }
    Add-Content $log "$(Get-Date -Format o) /$p $($res.StatusCode)"
    try { $res.Close() } catch {}
}

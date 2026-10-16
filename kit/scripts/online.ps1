# 오토프로그 설치 키트 — 온라인 설치판 (setup.ps1 이 불러 쓴다)
# zip 안에 설치 파일(payload)이 없으면, 설치하는 그 자리에서 공식 배포처의 최신 안정판을 받아 검증한 뒤 쓴다.
#
# 최신 버전은 깃허브 API(인터넷 주소 하나당 시간당 60회 제한) 대신 releases/latest 주소가 넘겨 주는
# 이동(redirect) 주소에서 읽는다 → 한 교실 PC 15대가 같은 인터넷을 써도 제한에 안 걸린다.
# 검증: Node.js · GitHub CLI · Supabase CLI · 코덱스 · VS Code = 공식 체크섬(SHA-256)
#       Git = 공식 체크섬 파일이 없어 디지털 서명(Authenticode)으로 확인
# PowerShell 5.1 호환.

$script:NodeMajor = 24   # 수업 기간 동안 고정(build.py 와 같은 값)
$script:DlDir = Join-Path $script:KitHome 'downloads'

function Get-WebText([string]$url) {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 60 -UserAgent 'autofrog-installkit'
    if ($r.Content -is [byte[]]) { return [Text.Encoding]::UTF8.GetString($r.Content) }
    return [string]$r.Content
}

function Get-LatestTag([string]$repo) {
    # https://github.com/<repo>/releases/latest → /releases/tag/<태그> 로 넘겨 준다. 그 태그만 읽는다.
    $req = [Net.HttpWebRequest]::Create("https://github.com/$repo/releases/latest")
    $req.Method = 'HEAD'
    $req.AllowAutoRedirect = $false
    $req.UserAgent = 'autofrog-installkit'
    $req.Timeout = 30000
    $res = $req.GetResponse()
    try { $loc = [string]$res.Headers['Location'] } finally { $res.Close() }
    $m = [regex]::Match($loc, '/releases/tag/([^/?#]+)$')
    if (-not $m.Success) { throw "$repo 최신 버전을 알아내지 못했습니다(이동 주소: '$loc')." }
    return [Uri]::UnescapeDataString($m.Groups[1].Value)
}

function Save-Download([string]$url, [string]$name) {
    New-Item -ItemType Directory -Force -Path $script:DlDir | Out-Null
    $dest = Join-Path $script:DlDir $name
    $part = "$dest.part"
    for ($i = 1; $i -le 3; $i++) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $part -UseBasicParsing -TimeoutSec 900 -UserAgent 'autofrog-installkit'
            Move-Item $part $dest -Force
            return $dest
        } catch {
            Remove-Item $part -Force -ErrorAction SilentlyContinue
            if ($i -eq 3) { throw "내려받기 실패: $name — $($_.Exception.Message)" }
            Write-Warn2 "내려받기가 끊겼습니다. 다시 시도합니다($i/3)…"
            Start-Sleep -Seconds (5 * $i)
        }
    }
}

function Find-Sum([string]$sums, [string]$name) {
    # "체크섬  파일이름" 줄들에서 해당 파일의 값을 찾는다
    foreach ($line in ($sums -split "`n")) {
        $p = @($line.Trim() -split '\s+')
        if ($p.Count -ge 2 -and $p[-1].TrimStart('*') -eq $name) { return $p[0].ToLower() }
    }
    throw "체크섬 목록에 $name 이 없습니다."
}

function Assert-Sha256([string]$path, [string]$expected) {
    $got = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()
    if (-not $expected -or $got -ne $expected.ToLower()) {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        throw "받은 파일이 공식 체크섬과 다릅니다(중간에 깨졌거나 바뀐 파일): $(Split-Path $path -Leaf)"
    }
}

function Assert-Signed([string]$path, [string]$signerPattern) {
    $s = Get-AuthenticodeSignature -FilePath $path
    $subject = if ($s.SignerCertificate) { $s.SignerCertificate.Subject } else { '' }
    if ($s.Status -ne 'Valid' -or $subject -notmatch $signerPattern) {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        throw "디지털 서명이 올바르지 않습니다: $(Split-Path $path -Leaf) ($($s.Status) / $subject)"
    }
}

function Get-OnlineInstaller([string]$key) {
    $labels = @{ git = 'Git'; node = 'Node.js'; gh = 'GitHub CLI'; supabase = 'Supabase CLI'; codex = '코덱스'; vscode = 'VS Code' }
    Write-Step "$($labels[$key]) 최신판을 공식 배포처에서 내려받는 중…"
    switch ($key) {
        'git' {
            $tag = Get-LatestTag 'git-for-windows/git'          # 예: v2.56.0.windows.2 → Git-2.56.0.2-64-bit.exe
            $m = [regex]::Match($tag, '^v(\d+\.\d+\.\d+)\.windows\.(\d+)$')
            if (-not $m.Success) { throw "Git 버전 형식을 모릅니다: $tag" }
            $ver = $m.Groups[1].Value
            if ($m.Groups[2].Value -ne '1') { $ver += '.' + $m.Groups[2].Value }
            $name = "Git-$ver-64-bit.exe"
            $p = Save-Download "https://github.com/git-for-windows/git/releases/download/$tag/$name" $name
            Assert-Signed $p 'Johannes Schindelin|Git for Windows'
            return [pscustomobject]@{ Path = $p; Version = $ver }
        }
        'node' {
            $idx = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -TimeoutSec 60 -UserAgent 'autofrog-installkit'
            $v = @($idx | Where-Object { $_.lts -and $_.version -like "v$($script:NodeMajor).*" })[0].version
            if (-not $v) { throw "Node.js $($script:NodeMajor) LTS 버전을 찾지 못했습니다." }
            $name = "node-$v-win-x64.zip"
            $sum = Find-Sum (Get-WebText "https://nodejs.org/dist/$v/SHASUMS256.txt") $name
            $p = Save-Download "https://nodejs.org/dist/$v/$name" $name
            Assert-Sha256 $p $sum
            return [pscustomobject]@{ Path = $p; Version = $v.TrimStart('v') }
        }
        'gh' {
            $tag = Get-LatestTag 'cli/cli'; $ver = $tag.TrimStart('v')
            $name = "gh_${ver}_windows_amd64.zip"
            $base = "https://github.com/cli/cli/releases/download/$tag"
            $sum = Find-Sum (Get-WebText "$base/gh_${ver}_checksums.txt") $name
            $p = Save-Download "$base/$name" $name
            Assert-Sha256 $p $sum
            return [pscustomobject]@{ Path = $p; Version = $ver }
        }
        'supabase' {
            $tag = Get-LatestTag 'supabase/cli'; $ver = $tag.TrimStart('v')
            $name = "supabase_${ver}_windows_amd64.zip"
            $base = "https://github.com/supabase/cli/releases/download/$tag"
            $sum = Find-Sum (Get-WebText "$base/checksums.txt") $name
            $p = Save-Download "$base/$name" $name
            Assert-Sha256 $p $sum
            return [pscustomobject]@{ Path = $p; Version = $ver }
        }
        'codex' {
            $tag = Get-LatestTag 'openai/codex'; $ver = $tag -replace '^rust-v', ''
            $asset = 'codex-package-x86_64-pc-windows-msvc.tar.gz'
            $base = "https://github.com/openai/codex/releases/download/$tag"
            $sum = Find-Sum (Get-WebText "$base/codex-package_SHA256SUMS") $asset
            $p = Save-Download "$base/$asset" "codex-package-$ver-x86_64-pc-windows-msvc.tar.gz"
            Assert-Sha256 $p $sum
            return [pscustomobject]@{ Path = $p; Version = $ver }
        }
        'vscode' {
            # 사용자 설치판(관리자 권한 불필요). 공식 업데이트 서버가 최신 주소와 체크섬을 같이 준다.
            $j = Invoke-RestMethod -Uri 'https://update.code.visualstudio.com/api/update/win32-x64-user/stable/latest' -TimeoutSec 60 -UserAgent 'autofrog-installkit'
            $name = "VSCodeUserSetup-x64-$($j.productVersion).exe"
            $p = Save-Download $j.url $name
            Assert-Sha256 $p $j.sha256hash
            Assert-Signed $p 'Microsoft Corporation'
            return [pscustomobject]@{ Path = $p; Version = $j.productVersion }
        }
        default { throw "모르는 설치 항목: $key" }
    }
}

function Clear-OnlineDownloads {
    # 다 쓴 설치 파일(수백 MB)은 지운다. 다시 실행하면 그때 새로 받는다.
    if (Test-Path $script:DlDir) { Remove-Item $script:DlDir -Recurse -Force -ErrorAction SilentlyContinue }
}

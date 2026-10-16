# 오토프로그 바이브코딩 설치 키트 — 한 번에 설치
# 순서: 사전점검 → Git → Node.js → GitHub CLI·Supabase CLI → VS Code → PATH → 실행정책
#       → Vercel CLI → 클로드 코드 → 코덱스(+확인 없이 바로 실행 설정) → VS Code 설정 → 버전 표 검증
# 관리자 권한 없이 돌아가게 짰다(전부 내 계정 폴더에 설치). PowerShell 5.1 호환, UTF-8(BOM) 저장.
param([switch]$Auto)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'common.ps1')

$KitRoot  = Split-Path $PSScriptRoot -Parent
$Payload  = Join-Path $KitRoot 'payload'
$Manifest = Get-Content (Join-Path $Payload 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json

New-Item -ItemType Directory -Force -Path $script:LogDir, $script:KitHome, $script:KitBin | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile = Join-Path $script:LogDir "setup-$stamp.log"
try { Start-Transcript -Path $logFile -Force | Out-Null } catch {}

$Results = [ordered]@{}   # 단계별 결과(로그·검증 표에 쓴다)
function Set-Result([string]$k, [string]$state, [string]$note) {
    $Results[$k] = [ordered]@{ state = $state; note = $note }
}
function Get-PayloadFile([string]$key) { return Join-Path $Payload $Manifest.files.$key.file }

function Invoke-Step([string]$key, [string]$title, [scriptblock]$body) {
    Write-Title $title
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        & $body
    } catch {
        Write-Fail "$title — $($_.Exception.Message)"
        Set-Result $key 'FAIL' $_.Exception.Message
    }
    $sw.Stop()
    if ($Results.Contains($key)) { $Results[$key].sec = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
}

function Expand-Zip([string]$zip, [string]$dest) {
    # tar.exe(윈도우 10 1803+ 기본 내장)가 Expand-Archive 보다 훨씬 빠르다
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $tar = Join-Path $env:windir 'System32\tar.exe'
    if (Test-Path $tar) {
        $r = Invoke-Native $tar @('-xf', $zip, '-C', $dest)
        if ($r.Code -eq 0) { return }
    }
    Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
}

Write-Title "오토프로그 설치 키트 ($($Manifest.built))"
Write-Host '  필요한 프로그램을 차례로 설치합니다. 창을 닫지 말고 기다려 주세요.' -ForegroundColor White
Write-Host "  기록 파일: $logFile" -ForegroundColor DarkGray

# zip 에서 풀린 파일의 "인터넷에서 받음" 표시를 지운다(보안 경고 방지)
try { Get-ChildItem -LiteralPath $KitRoot -Recurse -File | Unblock-File } catch {}
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
Update-SessionPath

# ── 0. 사전 점검 ──────────────────────────────────────────
Invoke-Step 'precheck' '0. 사전 점검' {
    $notes = @()
    $build = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild
    if (-not [Environment]::Is64BitOperatingSystem) { throw '64비트 윈도우가 아닙니다. 이 키트는 64비트 전용입니다.' }
    if ($build -lt 17763) { throw "윈도우 버전이 너무 낮습니다(빌드 $build). 윈도우 10 1809 이상이 필요합니다." }
    $notes += "build=$build"
    $notes += "admin=$(Test-IsAdmin)"

    if ($env:USERNAME -match '[^\x00-\x7F]') {
        Write-Warn2 "윈도우 사용자 이름이 한글($env:USERNAME)입니다. 대부분 괜찮지만 일부 도구가 경로 문제를 일으킬 수 있습니다."
        $notes += 'korean-username'
    }
    $pol = Get-ExecutionPolicy -List
    $gpo = $pol | Where-Object { $_.Scope -in 'MachinePolicy', 'UserPolicy' -and $_.ExecutionPolicy -ne 'Undefined' }
    if ($gpo) {
        Write-Warn2 '회사 정책으로 PowerShell 스크립트 실행이 제한돼 있습니다. 설치는 계속하지만 일부 명령은 .cmd 로 실행해야 할 수 있습니다.'
        $notes += 'gpo-execution-policy'
    }

    $code = Get-Process -Name Code -ErrorAction SilentlyContinue
    if ($code) {
        if ($Auto) {
            $notes += 'vscode-running'
        } else {
            Write-Warn2 'VS Code 가 켜져 있습니다. 새로 설치한 프로그램을 VS Code 가 알아보려면 완전히 꺼야 합니다.'
            Read-Host '  VS Code 에서 작업을 저장한 뒤 Enter 를 누르면 VS Code 를 닫습니다'
            Get-Process -Name Code -ErrorAction SilentlyContinue | Stop-Process -Force
            Start-Sleep -Seconds 2
            Write-Ok 'VS Code 를 닫았습니다.'
        }
    }

    $hosts = @(
        @{ n = '클로드 다운로드';  u = 'https://downloads.claude.ai/claude-code-releases/latest' },
        @{ n = 'npm 저장소';       u = 'https://registry.npmjs.org/' },
        @{ n = 'GitHub';          u = 'https://github.com/' },
        @{ n = 'VS Code 확장';     u = 'https://marketplace.visualstudio.com/'; method = 'Get' }
    )
    foreach ($h in $hosts) {
        try {
            $method = if ($h.method) { $h.method } else { 'Head' }
            Invoke-WebRequest -Uri $h.u -Method $method -UseBasicParsing -TimeoutSec 15 | Out-Null
            Write-Ok "인터넷 연결 확인: $($h.n)"
        } catch {
            Write-Warn2 "$($h.n) 에 접속이 안 됩니다($($h.u)). 회사 방화벽이면 전산 담당께 허용을 요청하세요."
            $notes += "blocked:$($h.u)"
        }
    }
    Set-Result 'precheck' 'OK' ($notes -join ', ')
}

# ── 1. Git ────────────────────────────────────────────────
Invoke-Step 'git' '1. Git 설치' {
    $git = Find-Exe 'git'
    if ($git) {
        Write-Skip "이미 설치돼 있습니다: $git"
        Set-Result 'git' 'SKIP' $git
    } else {
        $exe = Get-PayloadFile 'git'
        Write-Step "Git $($Manifest.files.git.version) 설치 중(1~2분)…"
        $p = Start-Process -FilePath $exe -Wait -PassThru -ArgumentList @(
            '/VERYSILENT', '/NORESTART', '/NOCANCEL', '/SP-', '/SUPPRESSMSGBOXES', '/CLOSEAPPLICATIONS',
            ('/DIR="' + (Join-Path $env:LOCALAPPDATA 'Programs\Git') + '"'), '/o:PathOption=Cmd')
        if ($p.ExitCode -ne 0) { throw "Git 설치 프로그램이 오류로 끝났습니다(코드 $($p.ExitCode))." }
        Update-SessionPath
        $git = Find-Exe 'git'
        if (-not $git) {
            foreach ($c in @("$env:LOCALAPPDATA\Programs\Git\cmd", "$env:ProgramFiles\Git\cmd")) {
                if (Test-Path "$c\git.exe") { [void](Add-UserPath @($c)); Update-SessionPath; $git = "$c\git.exe"; break }
            }
        }
        if (-not $git) { throw 'Git 을 설치했지만 git 명령을 찾지 못했습니다.' }
        Write-Ok "Git 설치 완료: $git"
        Set-Result 'git' 'OK' $git
    }
    # 기본 설정(이미 있으면 그대로 둔다)
    $r = Invoke-Native 'git' @('config', '--global', '--get', 'init.defaultBranch')
    if (-not $r.Out) { [void](Invoke-Native 'git' @('config', '--global', 'init.defaultBranch', 'main')) }
}

# ── 2. Node.js ────────────────────────────────────────────
Invoke-Step 'node' '2. Node.js 설치' {
    $node = Find-Exe 'node'
    $major = 0
    if ($node) { $major = [int]((Invoke-Native 'node' @('-v')).Out.TrimStart('v').Split('.')[0]) }
    if ($node -and $major -ge 22) {
        Write-Skip "이미 설치돼 있습니다: $node (v$major)"
        Set-Result 'node' 'SKIP' $node
    } else {
        if ($node) { Write-Warn2 "오래된 Node(v$major)가 있습니다. 새 Node 24 를 내 계정 폴더에 따로 깔고 앞쪽 경로로 둡니다." }
        $dest = Join-Path $script:KitHome 'node'
        $tmp = Join-Path $script:KitHome '_node_tmp'
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Write-Step "Node.js $($Manifest.files.node.version) 압축 푸는 중…"
        Expand-Zip (Get-PayloadFile 'node') $tmp
        $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Move-Item $inner.FullName $dest
        Remove-Item $tmp -Recurse -Force
        [void](Add-UserPath @($dest))
        Update-SessionPath
        Write-Ok "Node.js 설치 완료: $dest"
        Set-Result 'node' 'OK' $dest
    }
    # npm 전역 설치 폴더 = %APPDATA%\npm (윈도우 표준 위치)로 맞추고 PATH 에 넣는다
    $npmGlobal = Join-Path $env:APPDATA 'npm'
    New-Item -ItemType Directory -Force -Path $npmGlobal | Out-Null
    $prefix = (Invoke-Native 'npm.cmd' @('config', 'get', 'prefix')).Out.Trim()
    if ($prefix -ine $npmGlobal) { [void](Invoke-Native 'npm.cmd' @('config', 'set', 'prefix', $npmGlobal)) }
    [void](Add-UserPath @('%APPDATA%\npm'))
    Update-SessionPath
}

# ── 3. GitHub CLI · Supabase CLI ──────────────────────────
Invoke-Step 'gh' '3-1. GitHub CLI 설치' {
    $gh = Find-Exe 'gh'
    if ($gh) { Write-Skip "이미 설치돼 있습니다: $gh"; Set-Result 'gh' 'SKIP' $gh; return }
    $tmp = Join-Path $script:KitHome '_gh_tmp'
    Expand-Zip (Get-PayloadFile 'gh') $tmp
    Copy-Item (Join-Path $tmp 'bin\gh.exe') $script:KitBin -Force
    Remove-Item $tmp -Recurse -Force
    Write-Ok "GitHub CLI $($Manifest.files.gh.version) 설치 완료"
    Set-Result 'gh' 'OK' (Join-Path $script:KitBin 'gh.exe')
}

Invoke-Step 'supabase' '3-2. Supabase CLI 설치' {
    $sb = Find-Exe 'supabase'
    if ($sb) { Write-Skip "이미 설치돼 있습니다: $sb"; Set-Result 'supabase' 'SKIP' $sb; return }
    $tmp = Join-Path $script:KitHome '_sb_tmp'
    Expand-Zip (Get-PayloadFile 'supabase') $tmp
    # supabase.exe 와 supabase-go.exe 는 반드시 같은 폴더에 있어야 한다
    Get-ChildItem $tmp -Recurse -Filter 'supabase*.exe' | ForEach-Object { Copy-Item $_.FullName $script:KitBin -Force }
    Remove-Item $tmp -Recurse -Force
    if (-not (Test-Path (Join-Path $script:KitBin 'supabase.exe'))) { throw 'supabase.exe 를 찾지 못했습니다.' }
    Write-Ok "Supabase CLI $($Manifest.files.supabase.version) 설치 완료"
    Set-Result 'supabase' 'OK' (Join-Path $script:KitBin 'supabase.exe')
}
[void](Add-UserPath @($script:KitBin))
Update-SessionPath

# ── 4. VS Code ────────────────────────────────────────────
function Find-CodeCmd {
    $c = Find-Exe 'code.cmd'
    if ($c) { return $c }
    foreach ($p in @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd", "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd")) {
        if (Test-Path $p) { return $p }
    }
    return $null
}
Invoke-Step 'vscode' '4. VS Code 설치' {
    $code = Find-CodeCmd
    if ($code) { Write-Skip "이미 설치돼 있습니다: $code"; Set-Result 'vscode' 'SKIP' $code; return }
    Write-Step "VS Code $($Manifest.files.vscode.version) 설치 중(1~2분)…"
    $p = Start-Process -FilePath (Get-PayloadFile 'vscode') -Wait -PassThru -ArgumentList @(
        '/VERYSILENT', '/NORESTART', '/SUPPRESSMSGBOXES',
        '/MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath')
    if ($p.ExitCode -ne 0) { throw "VS Code 설치 프로그램이 오류로 끝났습니다(코드 $($p.ExitCode))." }
    Update-SessionPath
    $code = Find-CodeCmd
    if (-not $code) { throw 'VS Code 를 설치했지만 code 명령을 찾지 못했습니다.' }
    [void](Add-UserPath @((Split-Path $code -Parent)))
    Update-SessionPath
    Write-Ok "VS Code 설치 완료: $code"
    Set-Result 'vscode' 'OK' $code
}

# ── 5. PowerShell 실행 정책 ───────────────────────────────
Invoke-Step 'policy' '5. PowerShell 실행 정책' {
    # npm 으로 깐 명령(vercel 등)은 .ps1 로도 만들어진다. 기본값(Restricted)이면 PowerShell 에서 막힌다.
    $pol = Get-ExecutionPolicy -List
    $gpo = $pol | Where-Object { $_.Scope -in 'MachinePolicy', 'UserPolicy' -and $_.ExecutionPolicy -ne 'Undefined' }
    if ($gpo) {
        Write-Warn2 '회사 정책으로 고정돼 있어 바꾸지 않습니다. 막히면 vercel.cmd 처럼 .cmd 를 붙여 실행하세요.'
        Set-Result 'policy' 'WARN' 'gpo'
        return
    }
    $cu = ($pol | Where-Object Scope -eq 'CurrentUser').ExecutionPolicy
    if ($cu -in 'RemoteSigned', 'Unrestricted', 'Bypass') { Write-Skip "이미 $cu"; Set-Result 'policy' 'SKIP' "$cu"; return }
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    } catch {
        # 1-install.bat 의 Process=Bypass 가 우선해도 저장된 CurrentUser 정책은 유효하다.
        if ($_.FullyQualifiedErrorId -notlike 'ExecutionPolicyOverride,*' -or
            (Get-ExecutionPolicy -Scope CurrentUser) -ne 'RemoteSigned') { throw }
    }
    Write-Ok '내 계정의 실행 정책을 RemoteSigned 로 바꿨습니다.'
    Set-Result 'policy' 'OK' 'RemoteSigned'
}

# ── 6. Vercel CLI ─────────────────────────────────────────
Invoke-Step 'vercel' '6. Vercel CLI 설치' {
    $v = Find-Exe 'vercel.cmd'
    if ($v) { Write-Skip "이미 설치돼 있습니다: $v"; Set-Result 'vercel' 'SKIP' $v; return }
    Write-Step 'npm 으로 설치 중(1~3분)…'
    $r = Invoke-Native 'npm.cmd' @('install', '-g', 'vercel@latest', '--no-fund', '--no-audit', '--loglevel=error')
    if ($r.Code -ne 0) { throw "npm 설치 실패(코드 $($r.Code)): $($r.Out | Select-Object -Last 1)" }
    $v = Join-Path $env:APPDATA 'npm\vercel.cmd'
    if (-not (Test-Path $v)) { throw 'vercel 명령이 만들어지지 않았습니다.' }
    Write-Ok 'Vercel CLI 설치 완료'
    Set-Result 'vercel' 'OK' $v
}

# ── 7. 클로드 코드 ────────────────────────────────────────
function Install-ClaudeNative {
    # 공식 설치 스크립트(claude.ai/install.ps1)와 같은 일을 한다: 최신 버전 → 체크섬 확인 → claude install
    $base = 'https://downloads.claude.ai/claude-code-releases'
    $ver = (Invoke-RestMethod -Uri "$base/latest" -TimeoutSec 30).ToString().Trim()
    if ($ver -notmatch '^\d+\.\d+\.\d+') { throw "버전 정보를 받지 못했습니다(받은 값: $($ver.Substring(0, [Math]::Min(40, $ver.Length))))." }
    $manifest = Invoke-RestMethod -Uri "$base/$ver/manifest.json" -TimeoutSec 30
    $sum = $manifest.platforms.'win32-x64'.checksum
    $dl = Join-Path $env:USERPROFILE '.claude\downloads'
    New-Item -ItemType Directory -Force -Path $dl | Out-Null
    $bin = Join-Path $dl "claude-$ver-win32-x64.exe"
    Write-Step "클로드 코드 $ver 내려받는 중…"
    Invoke-WebRequest -Uri "$base/$ver/win32-x64/claude.exe" -OutFile $bin -UseBasicParsing -TimeoutSec 600
    if ((Get-FileHash $bin -Algorithm SHA256).Hash.ToLower() -ne $sum) { Remove-Item $bin -Force; throw '체크섬이 맞지 않습니다.' }
    $r = Invoke-Native $bin @('install')
    Start-Sleep -Seconds 1
    Remove-Item $bin -Force -ErrorAction SilentlyContinue
    if ($r.Code -ne 0) { throw "claude install 실패(코드 $($r.Code))" }
}
Invoke-Step 'claude' '7. 클로드 코드 설치' {
    $c = Find-Exe 'claude'
    if ($c) { Write-Skip "이미 설치돼 있습니다: $c"; Set-Result 'claude' 'SKIP' $c; return }
    $how = 'native'
    try { Install-ClaudeNative } catch {
        Write-Warn2 "공식 경로 실패: $($_.Exception.Message) → npm 으로 다시 시도합니다."
        $how = 'npm'
        $r = Invoke-Native 'npm.cmd' @('install', '-g', '@anthropic-ai/claude-code', '--no-fund', '--no-audit', '--loglevel=error')
        if ($r.Code -ne 0) { throw "npm 설치도 실패했습니다(코드 $($r.Code))." }
    }
    [void](Add-UserPath @('%USERPROFILE%\.local\bin'))
    Update-SessionPath
    $c = Find-Exe 'claude'
    if (-not $c) { throw 'claude 명령을 찾지 못했습니다.' }
    Write-Ok "클로드 코드 설치 완료($how): $c"
    Set-Result 'claude' 'OK' "$how $c"
}

# ── 8. 코덱스 ─────────────────────────────────────────────
function Install-CodexOffline {
    # 공식 설치기(chatgpt.com/codex/install.ps1)와 같은 폴더 구조로 깐다 → 나중에 `codex update` 가 그대로 된다
    $target = 'x86_64-pc-windows-msvc'
    $ver = $Manifest.files.codex.version
    $root = Join-Path $env:USERPROFILE '.codex\packages\standalone'
    $releaseName = "$ver-$target"
    $releaseDir = Join-Path $root "releases\$releaseName"
    $current = Join-Path $root 'current'
    $visible = Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin'
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'releases'), (Split-Path $visible -Parent) | Out-Null
    $staging = Join-Path $root ".staging-$PID"
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $staging | Out-Null
    Write-Step "코덱스 $ver 압축 푸는 중…"
    $r = Invoke-Native (Join-Path $env:windir 'System32\tar.exe') @('-xzf', (Get-PayloadFile 'codex'), '-C', $staging)
    if ($r.Code -ne 0 -or -not (Test-Path (Join-Path $staging 'bin\codex.exe'))) { throw "코덱스 압축 해제 실패: $($r.Out)" }
    if (Test-Path $releaseDir) { Remove-Item $releaseDir -Recurse -Force }
    Move-Item $staging $releaseDir
    foreach ($link in @($current, $visible)) {
        if (Test-Path $link) { (Get-Item $link -Force).Delete() }
    }
    New-Item -ItemType Junction -Path $current -Target $releaseDir | Out-Null
    New-Item -ItemType Junction -Path $visible -Target (Join-Path $current 'bin') | Out-Null
    [IO.File]::WriteAllText((Join-Path $root 'auto-update-version'), $releaseName)
    [void](Add-UserPath @($visible))
    Update-SessionPath
}
Invoke-Step 'codex' '8. 코덱스 설치' {
    $c = Find-Exe 'codex'
    if ($c) { Write-Skip "이미 설치돼 있습니다: $c"; Set-Result 'codex' 'SKIP' $c }
    else {
        $how = 'offline'
        try { Install-CodexOffline } catch {
            Write-Warn2 "동봉 파일 설치 실패: $($_.Exception.Message) → npm 으로 다시 시도합니다."
            $how = 'npm'
            $r = Invoke-Native 'npm.cmd' @('install', '-g', '@openai/codex', '--no-fund', '--no-audit', '--loglevel=error')
            if ($r.Code -ne 0) { throw "npm 설치도 실패했습니다(코드 $($r.Code))." }
            Update-SessionPath
        }
        $c = Find-Exe 'codex'
        if (-not $c) { throw 'codex 명령을 찾지 못했습니다.' }
        Write-Ok "코덱스 설치 완료($how): $c"
        Set-Result 'codex' 'OK' "$how $c"
    }

    # 그냥 `codex` 만 쳐도 확인 없이(bypass) 바로 실행되게 — 맨 위 두 줄만 맞추고 나머지 설정은 그대로 둔다
    $cfgDir = Join-Path $env:USERPROFILE '.codex'
    $cfg = Join-Path $cfgDir 'config.toml'
    New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
    $want = @('approval_policy = "never"', 'sandbox_mode = "danger-full-access"')
    $lines = @()
    if (Test-Path $cfg) {
        Copy-Item $cfg "$cfg.bak-$stamp" -Force
        $lines = @(Get-Content $cfg -Encoding UTF8)
    }
    $firstTable = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*\[') { $firstTable = $i; break } }
    $head = @(); $tail = @()
    if ($firstTable -gt 0) { $head = @($lines[0..($firstTable - 1)] | Where-Object { $_ -notmatch '^\s*(approval_policy|sandbox_mode)\s*=' -and $_ -notmatch '^# 오토프로그 설치 키트' }) }
    if ($firstTable -lt $lines.Count) { $tail = @($lines[$firstTable..($lines.Count - 1)]) }
    $text = ((@('# 오토프로그 설치 키트: 확인 없이 바로 실행(연습 폴더에서만 쓰세요)') + $want + $head + $tail) -join "`r`n") + "`r`n"
    [IO.File]::WriteAllText($cfg, $text, (New-Object Text.UTF8Encoding $false))
    Write-Ok "코덱스 설정: 확인 없이 바로 실행 ($cfg)"
}

# ── 9. 바로가기 명령 · VS Code 설정 ────────────────────────
Invoke-Step 'extras' '9. 바로가기 명령과 VS Code 설정' {
    $enc = New-Object Text.UTF8Encoding $false
    [IO.File]::WriteAllText((Join-Path $script:KitBin 'cx.cmd'), "@echo off`r`ncodex --dangerously-bypass-approvals-and-sandbox %*`r`n", $enc)
    [IO.File]::WriteAllText((Join-Path $script:KitBin 'cc.cmd'), "@echo off`r`nclaude --dangerously-skip-permissions %*`r`n", $enc)
    Write-Ok 'cx = 코덱스 바로 실행, cc = 클로드 바로 실행'

    $notes = @()
    $code = Find-CodeCmd
    if ($code) {
        # 사용자 설정 파일이 없을 때만 만든다(있으면 손대지 않는다)
        $userDir = Join-Path $env:APPDATA 'Code\User'
        $settings = Join-Path $userDir 'settings.json'
        if (-not (Test-Path $settings)) {
            New-Item -ItemType Directory -Force -Path $userDir | Out-Null
            $json = "{`r`n  `"terminal.integrated.enablePersistentSessions`": false,`r`n  `"terminal.integrated.defaultProfile.windows`": `"PowerShell`",`r`n  `"workbench.iconTheme`": `"material-icon-theme`"`r`n}`r`n"
            [IO.File]::WriteAllText($settings, $json, $enc)
            $notes += 'settings.json'
        }
        $argv = Join-Path $env:USERPROFILE '.vscode\argv.json'
        if (-not (Test-Path $argv)) {
            New-Item -ItemType Directory -Force -Path (Split-Path $argv) | Out-Null
            [IO.File]::WriteAllText($argv, "{`r`n  `"locale`": `"ko`"`r`n}`r`n", $enc)
            $notes += 'locale=ko'
        }
        foreach ($ext in @('ms-ceintl.vscode-language-pack-ko', 'pkief.material-icon-theme', 'openai.chatgpt', 'anthropic.claude-code')) {
            Write-Step "VS Code 확장 설치: $ext"
            $r = Invoke-Native $code @('--install-extension', $ext, '--force')
            if ($r.Code -eq 0) { $notes += $ext } else { Write-Warn2 "확장 설치 실패: $ext"; $notes += "FAIL:$ext" }
        }
    }
    Set-Result 'extras' 'OK' ($notes -join ', ')
}

# ── 10. 검증: 새 창에서 버전 확인 ──────────────────────────
Write-Title '10. 설치 확인 (새 창 기준)'
Update-SessionPath
$verify = @'
$ErrorActionPreference = 'Continue'
$tools = [ordered]@{ git='git'; node='node'; npm='npm'; npx='npx'; gh='gh'; supabase='supabase'; vercel='vercel'; claude='claude'; codex='codex'; code='code' }
$out = [ordered]@{}
foreach ($k in $tools.Keys) {
    $cmd = Get-Command $tools[$k] -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { $out[$k] = [ordered]@{ ok = $false; version = ''; path = '' }; continue }
    try {
        # 출력 전체를 소비해야 네이티브 종료코드가 설정된다(First 1 은 파이프를 조기 종료한다).
        $LASTEXITCODE = -1
        $lines = @(& $tools[$k] --version 2>&1 | ForEach-Object { "$_" })
        $exitCode = $LASTEXITCODE
        $v = ($lines | Select-Object -First 1 | Out-String).Trim()
        $ok = ($exitCode -eq 0) -and ($v -ne '')
    } catch { $v = $_.Exception.Message; $ok = $false }
    $out[$k] = [ordered]@{ ok = $ok; version = $v; path = $cmd.Source }
}
$out | ConvertTo-Json -Depth 4 -Compress
'@
# 실행 정책을 우회하지 않고 수강생이 여는 새 PowerShell 창과 같은 조건으로 확인한다
# (명령 문자열로 넘기면 확인 스크립트 자체는 정책에 안 걸리고, 그 안의 vercel.ps1 같은 것은 걸린다)
$enc64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($verify))
$processPolicy = $env:PSExecutionPolicyPreference
try {
    # 배치의 Process=Bypass 환경변수를 검증용 새 창에 상속하지 않는다.
    Remove-Item Env:\PSExecutionPolicyPreference -ErrorAction SilentlyContinue
    $vr = Invoke-Native 'powershell.exe' @('-NoProfile', '-EncodedCommand', $enc64)
} finally {
    if ($null -ne $processPolicy) { $env:PSExecutionPolicyPreference = $processPolicy }
}
$verified = $null
try { $verified = ($vr.Out -split "`n" | Where-Object { $_.Trim().StartsWith('{') } | Select-Object -Last 1) | ConvertFrom-Json } catch {}
if (-not $verified) { $verified = [pscustomobject]@{}; Write-Fail "확인 단계 실행 실패: $($vr.Out)" }

$labels = [ordered]@{ git='Git'; node='Node.js'; npm='npm'; npx='npx'; gh='GitHub CLI'; supabase='Supabase CLI'; vercel='Vercel CLI'; claude='클로드 코드'; codex='코덱스'; code='VS Code' }
$allOk = (@($Results.Values | Where-Object { $_.state -eq 'FAIL' }).Count -eq 0)
Write-Host ''
foreach ($k in $labels.Keys) {
    $row = $verified.$k
    if ($row -and $row.ok) {
        Write-Host ('  [ OK ] {0,-14} {1}' -f $labels[$k], $row.version) -ForegroundColor Green
    } else {
        $allOk = $false
        Write-Host ('  [실패] {0,-14} {1}' -f $labels[$k], $(if ($row) { $row.version } else { '' })) -ForegroundColor Red
    }
}

$report = [ordered]@{
    kit = $Manifest.built; finished = (Get-Date).ToString('s'); user = $env:USERNAME
    allOk = $allOk; steps = $Results; verify = $verified
}
$reportFile = Join-Path $script:LogDir "result-$stamp.json"
[IO.File]::WriteAllText($reportFile, ($report | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding $false))
Copy-Item $reportFile (Join-Path $script:LogDir 'result-latest.json') -Force

Write-Host ''
if ($allOk) {
    Write-Host '  모든 설치가 끝났습니다.' -ForegroundColor Green
    Write-Host '  다음 단계: 같은 폴더의 [2-login.bat] 을 더블클릭하세요.' -ForegroundColor White
} else {
    Write-Host '  일부 설치가 안 됐습니다. 위 [실패] 줄과 아래 기록 파일을 강사에게 보여 주세요.' -ForegroundColor Yellow
    Write-Host "  $logFile" -ForegroundColor Yellow
}

if (-not $Auto) {
    # 새 PATH 를 물려받은 VS Code 를 이 창에서 띄운다(이미 켜진 VS Code 는 옛 PATH 를 쓴다)
    $code = Find-CodeCmd
    if ($code -and -not (Get-Process -Name Code -ErrorAction SilentlyContinue)) {
        Write-Host '  VS Code 를 엽니다. 아래 터미널에서 codex 또는 claude 를 입력해 보세요.' -ForegroundColor White
        Start-Process -FilePath $code -WindowStyle Hidden
    }
}
try { Stop-Transcript | Out-Null } catch {}
if ($allOk) { exit 0 } else { exit 1 }

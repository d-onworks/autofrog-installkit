# 오토프로그 설치 키트 — 로그인 마법사
# 브라우저 승인은 사람이 직접 한다. 이 스크립트는 순서를 잡아 주고, 됐는지 확인만 한다.
# -CheckOnly : 로그인 상태 표만 보여 준다(아무것도 실행하지 않음 — 점검·E2E 용)
# -Pause     : 끝나면 Enter 를 기다린다(바탕화면 '오토프로그 로그인' 아이콘으로 열 때 창이 바로 닫히지 않게)
param([switch]$CheckOnly, [switch]$Pause)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
Update-SessionPath
New-Item -ItemType Directory -Force -Path $script:LogDir | Out-Null

function Test-Login([string]$key) {
    switch ($key) {
        'codex'    { if (-not (Find-Exe 'codex'))    { return $null }; return ((Invoke-Native 'codex' @('login', 'status')).Code -eq 0) }
        'github'   { if (-not (Find-Exe 'gh'))       { return $null }; return ((Invoke-Native 'gh' @('auth', 'status', '--hostname', 'github.com')).Code -eq 0) }
        'vercel'   { if (-not (Find-Exe 'vercel.cmd')) { return $null }; return ((Invoke-Native 'vercel.cmd' @('whoami')).Code -eq 0) }
        'supabase' { if (-not (Find-Exe 'supabase')) { return $null }; return ((Invoke-Native 'supabase' @('projects', 'list')).Code -eq 0) }
        'claude'   {
            if (-not (Find-Exe 'claude')) { return $null }
            # 클로드 코드는 로그인하면 ~/.claude/.credentials.json 에 저장한다
            return (Test-Path (Join-Path $env:USERPROFILE '.claude\.credentials.json'))
        }
    }
}

$labels = [ordered]@{ codex = '코덱스(ChatGPT)'; claude = '클로드'; github = 'GitHub'; vercel = 'Vercel'; supabase = 'Supabase' }

function Show-Table {
    $rows = [ordered]@{}
    Write-Host ''
    foreach ($k in $labels.Keys) {
        $s = Test-Login $k
        $rows[$k] = $s
        if ($null -eq $s)  { Write-Host ('  [없음] {0,-16} 설치되지 않음' -f $labels[$k]) -ForegroundColor DarkGray }
        elseif ($s)        { Write-Host ('  [ OK ] {0,-16} 로그인됨' -f $labels[$k]) -ForegroundColor Green }
        else               { Write-Host ('  [ -- ] {0,-16} 로그인 필요' -f $labels[$k]) -ForegroundColor Yellow }
    }
    $f = Join-Path $script:LogDir 'login-latest.json'
    [IO.File]::WriteAllText($f, ($rows | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))
    return $rows
}

Write-Title '오토프로그 로그인 마법사'
$state = Show-Table
if ($CheckOnly) { exit 0 }

function Ask([string]$q) {
    $a = Read-Host "  $q (Enter = 예 / n = 건너뛰기)"
    return ($a -notmatch '^(n|no|아니)')
}

# 1. 코덱스
if ($state.codex -eq $false -and (Ask '코덱스(ChatGPT 계정)에 로그인할까요?')) {
    Write-Step '브라우저가 열리면 ChatGPT 계정으로 로그인하세요.'
    & codex login
    if ((Invoke-Native 'codex' @('login', 'status')).Code -ne 0) {
        Write-Warn2 '브라우저 로그인이 안 됐습니다. 코드 입력 방식으로 다시 시도합니다.'
        & codex login --device-auth
    }
}

# 2. 클로드 (클로드 코드는 처음 실행할 때 로그인 화면이 나온다)
if ($state.claude -eq $false -and (Ask '클로드에 로그인할까요?')) {
    Write-Step '클로드가 열리면 화면 안내대로 로그인하세요. 로그인이 끝나면 /exit 를 입력해 나옵니다.'
    & claude
}

# 3. GitHub — 질문 4개를 건너뛰고 바로 브라우저 승인으로 간다. git push 도 이 로그인을 쓰게 연결한다.
if ($state.github -eq $false -and (Ask 'GitHub 에 로그인할까요?')) {
    # git 비밀번호 관리자를 gh 로 먼저 지정해 둔다. 이게 없으면 gh 가 영어로
    # "Authenticate Git with your GitHub credentials? (Y/n)" 를 물어 수강생이 멈춘다.
    [void](Invoke-Native 'gh' @('auth', 'setup-git', '--hostname', 'github.com', '--force'))
    Write-Step '8자리 코드가 나오면 Enter 를 누르세요 → 브라우저가 열리면 코드를 붙여 넣고(Ctrl+V, 자동 복사됨) 승인합니다.'
    & gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key --clipboard
}
if ((Test-Login 'github')) {
    [void](Invoke-Native 'gh' @('auth', 'setup-git'))
    # git 커밋에 쓰는 이름·이메일이 비어 있으면 GitHub 계정으로 채운다
    if (-not (Invoke-Native 'git' @('config', '--global', '--get', 'user.name')).Out) {
        $login = (Invoke-Native 'gh' @('api', 'user', '--jq', '.login')).Out.Trim()
        $id = (Invoke-Native 'gh' @('api', 'user', '--jq', '.id')).Out.Trim()
        if ($login) {
            [void](Invoke-Native 'git' @('config', '--global', 'user.name', $login))
            [void](Invoke-Native 'git' @('config', '--global', 'user.email', "$id+$login@users.noreply.github.com"))
            Write-Ok "git 사용자 이름을 GitHub 계정($login)으로 맞췄습니다."
        }
    }
}

# 4. Vercel — 화면의 주소와 코드를 브라우저에서 승인(이메일 로그인은 2026-02 폐지됨)
if ($state.vercel -eq $false -and (Ask 'Vercel 에 로그인할까요?')) {
    Write-Step '브라우저에서 Continue with GitHub 를 누르면 됩니다.'
    & vercel.cmd login
}

# 5. Supabase — Enter 로 브라우저를 연 뒤, 브라우저에 나온 확인 코드(영문·숫자 8자리)를 창에 붙여 넣는다
if ($state.supabase -eq $false -and (Ask 'Supabase 에 로그인할까요?')) {
    Write-Step 'Enter 를 누르면 브라우저가 열립니다 → 로그인 후 나오는 확인 코드(8자리)를 복사해 이 창에 붙여 넣고 Enter.'
    & supabase login
}

Write-Title '로그인 결과'
$final = Show-Table
Write-Host ''
Write-Host '  [ -- ] 로 남은 곳은 바탕화면 [오토프로그 로그인] 아이콘을 다시 누르면 그것만 다시 물어봅니다.' -ForegroundColor White
if ($Pause) { Write-Host ''; [void](Read-Host '  Enter 를 누르면 창이 닫힙니다') }

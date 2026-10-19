#!/bin/bash
# 오토프로그 바이브코딩 설치 키트(맥) — 한 번에 설치
# 순서: 사전점검 → Git(개발자 도구) → Node.js → GitHub CLI·Supabase CLI → VS Code → 셸 PATH
#       → Vercel CLI → 클로드 코드 → 코덱스(+확인 없이 바로 실행 설정) → VS Code 설정 → 버전 표 검증
# 관리자 권한 없이 내 계정 폴더에만 설치한다. 예외는 애플 개발자 도구(Git 포함) 하나 — 맥이 직접 설치 창을 띄운다.
# 옵션: --auto     질문 없이 진행(점검·E2E 용)
#       --no-open  끝나고 VS Code 를 열지 않음

HERE="$(cd "$(dirname "$0")" && pwd)"
KIT_ROOT="$(dirname "$HERE")"
. "$HERE/common.sh"
. "$HERE/online.sh"

AUTO=0; NO_OPEN=0
for a in "$@"; do
    case "$a" in --auto) AUTO=1 ;; --no-open) NO_OPEN=1 ;; esac
done

mkdir -p "$LOG_DIR" "$KIT_HOME" "$KIT_BIN"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/setup-$STAMP.log"
RES_FILE="$LOG_DIR/.steps-$STAMP.txt"
: > "$RES_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

# 단계 결과: "키|상태|초|메모" 한 줄씩(bash 3.2 라 연관 배열 대신 파일)
set_result() { printf '%s|%s|%s|%s\n' "$1" "$2" "$((SECONDS - ${STEP_START:-$SECONDS}))" "$(printf '%s' "$3" | tr '|\n' '/ ')" >> "$RES_FILE"; }
result_state() { awk -F'|' -v k="$1" '$1 == k { s = $2 } END { print s }' "$RES_FILE"; }

run_step() {
    # run_step <키> <제목> <함수> — 함수가 실패하면 그 단계만 [실패]로 적고 다음 단계로 간다
    local key="$1" t="$2" fn="$3" rc
    title "$t"
    STEP_START=$SECONDS
    STEP_ERR=''
    "$fn"; rc=$?
    if [ $rc -ne 0 ]; then
        fail "$t — ${STEP_ERR:-오류}"
        set_result "$key" FAIL "${STEP_ERR:-오류}"
    fi
}
die_step() { STEP_ERR="$1"; return 1; }

title '오토프로그 설치 키트 (맥 · 온라인 설치판 — 최신판을 공식 배포처에서 받습니다)'
echo '  필요한 프로그램을 차례로 설치합니다. 창을 닫지 말고 기다려 주세요.'
printf '  %s기록 파일: %s%s\n' "$C_D" "$LOG_FILE" "$C_0"

# zip 에서 풀린 파일의 "인터넷에서 받음" 표시를 지운다(2-login.command 가 그냥 열리게)
/usr/bin/xattr -dr com.apple.quarantine "$KIT_ROOT" 2>/dev/null
refresh_session_path

# ── 0. 사전 점검 ──────────────────────────────────────────
s_precheck() {
    local notes='' v major minor free h
    v="$(/usr/bin/sw_vers -productVersion)"
    major="${v%%.*}"; minor="$(echo "$v" | cut -d. -f2)"
    if [ "$major" -lt 13 ] || { [ "$major" -eq 13 ] && [ "${minor:-0}" -lt 5 ]; }; then
        die_step "맥OS 버전이 너무 낮습니다($v). 맥OS 13.5(벤투라) 이상이 필요합니다 — 시스템 설정 → 일반 → 소프트웨어 업데이트"; return
    fi
    notes="macos=$v arch=$(mac_arch) admin=$(is_admin && echo yes || echo no)"
    free="$(df -g "$HOME" | awk 'NR == 2 { print $4 }')"
    if [ "${free:-99}" -lt 5 ]; then warn "디스크 여유 공간이 ${free}GB 입니다. 5GB 이상 비워 두세요."; notes="$notes lowdisk=${free}G"; fi

    if pgrep -xq 'Code' || pgrep -f -q 'Visual Studio Code.app/Contents/MacOS/'; then
        if [ $AUTO = 1 ]; then
            notes="$notes vscode-running"
        else
            warn 'VS Code 가 켜져 있습니다. 새로 설치한 프로그램을 VS Code 가 알아보려면 완전히 꺼야 합니다.'
            read -r -p '  VS Code 에서 작업을 저장한 뒤 Enter 를 누르면 VS Code 를 닫습니다 ' _
            /usr/bin/osascript -e 'quit app "Visual Studio Code"' >/dev/null 2>&1
            sleep 3
            ok 'VS Code 를 닫았습니다.'
        fi
    fi

    for h in 'https://downloads.claude.ai/claude-code-releases/latest|클로드 다운로드' \
             'https://chatgpt.com/codex/install.sh|코덱스 다운로드' \
             'https://registry.npmjs.org/|npm 저장소' \
             'https://github.com/|GitHub' \
             'https://nodejs.org/dist/index.json|Node.js 배포처' \
             'https://update.code.visualstudio.com/api/update/darwin-arm64/stable/latest|VS Code 배포처' \
             'https://marketplace.visualstudio.com/|VS Code 확장'; do
        if /usr/bin/curl -fsS -o /dev/null --connect-timeout 15 --max-time 30 -A "$UA" "${h%%|*}"; then
            ok "인터넷 연결 확인: ${h##*|}"
        else
            warn "${h##*|} 에 접속이 안 됩니다(${h%%|*}). 회사 방화벽이면 전산 담당께 허용을 요청하세요."
            notes="$notes blocked:${h%%|*}"
        fi
    done
    set_result precheck OK "$notes"
}

# ── 1. Git (애플 개발자 도구) ──────────────────────────────
install_clt_headless() {
    # 관리자 암호가 이미 확인된 상태(sudo -n)일 때만 — 창 없이 소프트웨어 업데이트로 설치(홈브루와 같은 방법)
    local flag=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress label
    touch "$flag"
    label="$(/usr/sbin/softwareupdate -l 2>/dev/null | grep -B 1 -E 'Command Line Tools' \
        | awk -F'*' '/^ *\*/ { print $2 }' | sed -e 's/^ *Label: //' -e 's/^ *//' | grep -iv beta | sort -V | tail -n 1)"
    if [ -z "$label" ]; then rm -f "$flag"; return 1; fi
    step "$label 설치 중(5~15분)…"
    sudo -n /usr/sbin/softwareupdate -i "$label" >/dev/null 2>&1
    rm -f "$flag"
    sudo -n /usr/bin/xcode-select --switch /Library/Developer/CommandLineTools >/dev/null 2>&1
    clt_ready
}
install_clt_dialog() {
    # 맥이 띄우는 공식 설치 창 — 암호 없이 [설치] → [동의] 만 누르면 된다
    local waited=0
    /usr/bin/xcode-select --install >/dev/null 2>&1
    echo
    printf '  %s화면 가운데에 "명령어 라인 개발자 도구" 설치 창이 떴습니다.%s\n' "$C_Y" "$C_0"
    printf '  %s[설치] → [동의] 를 누르고, 그 창의 설치가 끝날 때까지 기다려 주세요(5~15분).%s\n' "$C_Y" "$C_0"
    echo '  (창이 안 보이면 Dock 이나 다른 창 뒤를 확인하세요. 끝나면 여기서 저절로 다음 단계로 갑니다.)'
    while ! clt_ready; do
        sleep 10; waited=$((waited + 10))
        if [ $((waited % 60)) -eq 0 ]; then printf '  … 기다리는 중 (%d분)\n' $((waited / 60)); fi
        if [ $waited -ge 2700 ]; then return 1; fi
    done
}
s_git() {
    local g
    g="$(find_git)"
    if [ -n "$g" ]; then
        skip "이미 설치돼 있습니다: $g"
        set_result git SKIP "$g"
    else
        step 'Git 은 애플 "개발자 도구(Command Line Tools)" 에 들어 있어 그걸 설치합니다.'
        if sudo -n true 2>/dev/null && install_clt_headless; then
            g=headless
        elif [ $AUTO = 1 ]; then
            die_step '자동 모드에서는 개발자 도구 설치 창을 누를 사람이 없습니다.'; return
        elif install_clt_dialog; then
            g=dialog
        else
            die_step '개발자 도구 설치가 끝나지 않았습니다. 설치 창을 끝까지 진행한 뒤 1-install.command 를 다시 실행하세요.'; return
        fi
        clt_ready || { die_step '개발자 도구를 설치했지만 git 을 찾지 못했습니다.'; return; }
        ok "Git(개발자 도구) 설치 완료($g): /usr/bin/git"
        set_result git OK "$g /usr/bin/git"
    fi
    # 기본 설정(이미 있으면 그대로 둔다)
    if [ -z "$(git config --global --get init.defaultBranch 2>/dev/null)" ]; then git config --global init.defaultBranch main; fi
}

# ── 2. Node.js ────────────────────────────────────────────
s_node() {
    local major=0 n tmp inner prefix
    if have node; then major="$(node -v 2>/dev/null | sed 's/^v//; s/\..*//')"; fi
    if [ "${major:-0}" -ge 22 ] 2>/dev/null; then
        skip "이미 설치돼 있습니다: $(command -v node) (v$major)"
        set_result node SKIP "$(command -v node)"
    else
        [ "${major:-0}" -gt 0 ] && warn "오래된 Node(v$major)가 있습니다. 새 Node $NODE_MAJOR 를 내 계정 폴더에 따로 깔고 앞쪽 경로로 둡니다."
        get_installer node || { die_step 'Node.js 를 내려받지 못했습니다.'; return; }
        step "Node.js $INST_VER 압축 푸는 중…"
        tmp="$KIT_HOME/_node_tmp"; rm -rf "$tmp"; mkdir -p "$tmp"
        tar -xzf "$INST_PATH" -C "$tmp" || { die_step 'Node.js 압축 해제 실패'; return; }
        inner="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
        rm -rf "$KIT_HOME/node"; mv "$inner" "$KIT_HOME/node"; rm -rf "$tmp"
        refresh_session_path; hash -r
        ok "Node.js 설치 완료: $KIT_HOME/node"
        set_result node OK "$KIT_HOME/node"
    fi
    # npm 전역 설치 폴더 — 쓸 수 없는 곳(/usr/local 등 관리자 폴더)이면 내 계정 폴더로 바꾼다(sudo 없이 npm -g 가 되게)
    prefix="$(npm config get prefix 2>/dev/null)"
    if [ "$(command -v node)" = "$KIT_HOME/node/bin/node" ] || [ -z "$prefix" ] || [ ! -w "$prefix" ] \
       || { [ -e "$prefix/lib" ] && [ ! -w "$prefix/lib" ]; }; then
        mkdir -p "$NPM_GLOBAL"
        if [ "$prefix" != "$NPM_GLOBAL" ]; then npm config set prefix "$NPM_GLOBAL" >/dev/null 2>&1; fi
    fi
    refresh_session_path; hash -r
}

# ── 3. GitHub CLI · Supabase CLI ──────────────────────────
s_gh() {
    local tmp
    if have gh; then skip "이미 설치돼 있습니다: $(command -v gh)"; set_result gh SKIP "$(command -v gh)"; return 0; fi
    get_installer gh || { die_step 'GitHub CLI 를 내려받지 못했습니다.'; return; }
    tmp="$KIT_HOME/_gh_tmp"; rm -rf "$tmp"; mkdir -p "$tmp"
    /usr/bin/unzip -q "$INST_PATH" -d "$tmp" || { die_step 'GitHub CLI 압축 해제 실패'; return; }
    cp "$(find "$tmp" -path '*/bin/gh' -type f | head -n 1)" "$KIT_BIN/gh" && chmod +x "$KIT_BIN/gh"
    rm -rf "$tmp"
    [ -x "$KIT_BIN/gh" ] || { die_step 'gh 를 찾지 못했습니다.'; return; }
    ok "GitHub CLI $INST_VER 설치 완료"
    set_result gh OK "$KIT_BIN/gh"
}
s_supabase() {
    if have supabase; then skip "이미 설치돼 있습니다: $(command -v supabase)"; set_result supabase SKIP "$(command -v supabase)"; return 0; fi
    get_installer supabase || { die_step 'Supabase CLI 를 내려받지 못했습니다.'; return; }
    tar -xzf "$INST_PATH" -C "$KIT_BIN" supabase 2>/dev/null || tar -xzf "$INST_PATH" -C "$KIT_BIN" || { die_step 'Supabase CLI 압축 해제 실패'; return; }
    chmod +x "$KIT_BIN/supabase" 2>/dev/null
    [ -x "$KIT_BIN/supabase" ] || { die_step 'supabase 를 찾지 못했습니다.'; return; }
    ok "Supabase CLI $INST_VER 설치 완료"
    set_result supabase OK "$KIT_BIN/supabase"
}

# ── 4. VS Code ────────────────────────────────────────────
find_vscode_app() {
    local a
    for a in "/Applications/Visual Studio Code.app" "$HOME/Applications/Visual Studio Code.app"; do
        [ -d "$a" ] && { echo "$a"; return; }
    done
}
s_vscode() {
    local app tmp team
    app="$(find_vscode_app)"
    if [ -n "$app" ]; then
        skip "이미 설치돼 있습니다: $app"
        set_result vscode SKIP "$app"
    else
        get_installer vscode || { die_step 'VS Code 를 내려받지 못했습니다.'; return; }
        step "VS Code $INST_VER 설치 중(1~2분)…"
        # 관리자 권한이 필요 없는 "내 응용 프로그램" 폴더(~/Applications)에 둔다. Dock·Spotlight 에서 그대로 찾힌다.
        tmp="$KIT_HOME/_vscode_tmp"; rm -rf "$tmp"; mkdir -p "$tmp" "$HOME/Applications"
        /usr/bin/ditto -x -k "$INST_PATH" "$tmp" || { die_step 'VS Code 압축 해제 실패'; return; }
        team="$(/usr/bin/codesign -dv "$tmp/Visual Studio Code.app" 2>&1 | awk -F= '/^TeamIdentifier=/ { print $2 }')"
        if [ "$team" != "UBF8T346G9" ]; then rm -rf "$tmp"; die_step "VS Code 서명이 마이크로소프트 것이 아닙니다($team)."; return; fi
        mv "$tmp/Visual Studio Code.app" "$HOME/Applications/"
        rm -rf "$tmp"
        app="$HOME/Applications/Visual Studio Code.app"
        ok "VS Code 설치 완료: $app"
        set_result vscode OK "$app"
    fi
    # 터미널에서 code 명령(VS Code 의 "셸 명령 설치" 와 같은 일)
    if ! have code; then ln -sf "$app/Contents/Resources/app/bin/code" "$KIT_BIN/code"; fi
    hash -r
}

# ── 5. 셸 PATH ────────────────────────────────────────────
s_path() {
    write_path_block
    refresh_session_path; hash -r
    ok '새 터미널 창과 VS Code 터미널이 설치한 명령을 찾도록 셸 설정(~/.zprofile · ~/.zshrc)에 등록했습니다.'
    set_result path OK "$PATH_BEGIN"
}

# ── 6. Vercel CLI ─────────────────────────────────────────
s_vercel() {
    if have vercel; then skip "이미 설치돼 있습니다: $(command -v vercel)"; set_result vercel SKIP "$(command -v vercel)"; return 0; fi
    step 'npm 으로 설치 중(1~3분)…'
    npm install -g vercel@latest --no-fund --no-audit --loglevel=error || { die_step 'npm 설치 실패'; return; }
    hash -r
    have vercel || { die_step 'vercel 명령이 만들어지지 않았습니다.'; return; }
    ok 'Vercel CLI 설치 완료'
    set_result vercel OK "$(command -v vercel)"
}

# ── 7. 클로드 코드 ────────────────────────────────────────
s_claude() {
    local how=native
    if have claude; then skip "이미 설치돼 있습니다: $(command -v claude)"; set_result claude SKIP "$(command -v claude)"; return 0; fi
    step '클로드 코드 공식 설치 스크립트 실행 중(claude.ai/install.sh — 체크섬 확인 포함)…'
    if ! /usr/bin/curl -fsSL -A "$UA" https://claude.ai/install.sh | /bin/bash; then
        warn '공식 경로 실패 → npm 으로 다시 시도합니다.'
        how=npm
        npm install -g @anthropic-ai/claude-code --no-fund --no-audit --loglevel=error || { die_step 'npm 설치도 실패했습니다.'; return; }
    fi
    refresh_session_path; hash -r
    have claude || { die_step 'claude 명령을 찾지 못했습니다.'; return; }
    ok "클로드 코드 설치 완료($how): $(command -v claude)"
    set_result claude OK "$how $(command -v claude)"
}

# ── 8. 코덱스 ─────────────────────────────────────────────
s_codex() {
    local how=native cfg_dir="$HOME/.codex" cfg tmp
    if have codex; then
        skip "이미 설치돼 있습니다: $(command -v codex)"; set_result codex SKIP "$(command -v codex)"
    else
        step '코덱스 공식 설치 스크립트 실행 중(chatgpt.com/codex/install.sh — 체크섬 확인 포함)…'
        if ! /usr/bin/curl -fsSL -A "$UA" https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 /bin/sh; then
            warn '공식 경로 실패 → npm 으로 다시 시도합니다.'
            how=npm
            npm install -g @openai/codex --no-fund --no-audit --loglevel=error || { die_step 'npm 설치도 실패했습니다.'; return; }
        fi
        refresh_session_path; hash -r
        have codex || { die_step 'codex 명령을 찾지 못했습니다.'; return; }
        ok "코덱스 설치 완료($how): $(command -v codex)"
        set_result codex OK "$how $(command -v codex)"
    fi

    # 그냥 `codex` 만 쳐도 확인 없이(bypass) 바로 실행되게 — 맨 위 두 줄만 맞추고 나머지 설정은 그대로 둔다
    mkdir -p "$cfg_dir"; cfg="$cfg_dir/config.toml"; tmp="$cfg.autofrog-tmp"
    [ -f "$cfg" ] && cp "$cfg" "$cfg.bak-$STAMP"
    {
        echo '# 오토프로그 설치 키트: 확인 없이 바로 실행(연습 폴더에서만 쓰세요)'
        echo 'approval_policy = "never"'
        echo 'sandbox_mode = "danger-full-access"'
        [ -f "$cfg" ] && awk '
            /^[[:space:]]*\[/ { table = 1 }
            !table && /^[[:space:]]*(approval_policy|sandbox_mode)[[:space:]]*=/ { next }
            !table && /^# 오토프로그 설치 키트/ { next }
            { print }' "$cfg"
        true
    } > "$tmp" && mv "$tmp" "$cfg"
    grep -q '^approval_policy = "never"' "$cfg" 2>/dev/null || { die_step "코덱스 설정 파일을 쓰지 못했습니다($cfg)."; return; }
    ok "코덱스 설정: 확인 없이 바로 실행 ($cfg)"
}

# ── 9. 바로가기 명령 · VS Code 설정 ────────────────────────
s_extras() {
    local notes='' code_cli user_dir settings argv ext
    # cx·cc 는 셸 설정의 별칭으로 넣었다(5단계). 파일로 만들면 맥의 C 컴파일러 cc 를 가린다.
    rm -f "$KIT_BIN/cx" "$KIT_BIN/cc"
    ok 'cx = 코덱스 바로 실행, cc = 클로드 바로 실행 (새 터미널 창부터)'

    code_cli="$(command -v code)"
    if [ -n "$code_cli" ]; then
        # 사용자 설정 파일이 없을 때만 만든다(있으면 손대지 않는다)
        user_dir="$HOME/Library/Application Support/Code/User"
        settings="$user_dir/settings.json"
        if [ ! -f "$settings" ]; then
            mkdir -p "$user_dir"
            printf '{\n  "terminal.integrated.enablePersistentSessions": false,\n  "workbench.iconTheme": "material-icon-theme"\n}\n' > "$settings"
            notes="$notes settings.json"
        fi
        argv="$HOME/.vscode/argv.json"
        if [ ! -f "$argv" ]; then
            mkdir -p "$HOME/.vscode"; printf '{\n  "locale": "ko"\n}\n' > "$argv"; notes="$notes locale=ko"
        fi
        for ext in ms-ceintl.vscode-language-pack-ko pkief.material-icon-theme openai.chatgpt anthropic.claude-code; do
            step "VS Code 확장 설치: $ext"
            if "$code_cli" --install-extension "$ext" --force >/dev/null 2>&1; then notes="$notes $ext"; else warn "확장 설치 실패: $ext"; notes="$notes FAIL:$ext"; fi
        done
    fi
    set_result extras OK "$notes"
}

run_step precheck '0. 사전 점검'                  s_precheck
if [ "$(result_state precheck)" = FAIL ]; then
    echo; fail '이 맥에서는 설치를 계속할 수 없습니다. 위 안내를 확인해 주세요.'
    exit 1
fi
run_step git      '1. Git 설치 (애플 개발자 도구)'  s_git
run_step node     '2. Node.js 설치'                s_node
run_step gh       '3-1. GitHub CLI 설치'            s_gh
run_step supabase '3-2. Supabase CLI 설치'          s_supabase
run_step vscode   '4. VS Code 설치'                 s_vscode
run_step path     '5. 터미널 PATH 등록'              s_path
run_step vercel   '6. Vercel CLI 설치'              s_vercel
run_step claude   '7. 클로드 코드 설치'              s_claude
run_step codex    '8. 코덱스 설치'                   s_codex
run_step extras   '9. 바로가기 명령과 VS Code 설정'   s_extras

# ── 10. 검증: 새 터미널 창과 같은 조건에서 버전 확인 ─────────
title '10. 설치 확인 (새 터미널 창 기준)'
# 지금 창의 PATH 를 물려주지 않고, 로그인 셸을 새로 띄워 셸 설정 파일만으로 찾히는지 본다
VERIFY_SH="$KIT_HOME/verify.sh"
cat > "$VERIFY_SH" <<'EOF'
for k in git node npm npx gh supabase vercel claude codex code; do
  p="$(command -v "$k" 2>/dev/null)"
  if [ -z "$p" ]; then printf '%s\t0\t\t\n' "$k"; continue; fi
  if [ "$k" = git ] && [ "$p" = /usr/bin/git ] && ! /usr/bin/xcode-select -p >/dev/null 2>&1; then printf '%s\t0\t개발자 도구 없음\t%s\n' "$k" "$p"; continue; fi
  out="$("$k" --version 2>&1 </dev/null)"; rc=$?
  v="$(printf '%s\n' "$out" | sed -n '/./{p;q;}')"
  [ $rc -eq 0 ] && [ -n "$v" ] && okv=1 || okv=0
  printf '%s\t%s\t%s\t%s\n' "$k" "$okv" "$v" "$p"
done
# 바로가기 별칭이 새 창에서 살아 있는지
if alias cx >/dev/null 2>&1 && alias cc >/dev/null 2>&1; then printf 'alias\t1\t\t\n'; else printf 'alias\t0\t\t\n'; fi
EOF
LOGIN_SHELL="${SHELL:-/bin/zsh}"
case "$LOGIN_SHELL" in */zsh|*/bash) ;; *) LOGIN_SHELL=/bin/zsh ;; esac
VERIFIED="$(cd "$HOME" && /usr/bin/env -i HOME="$HOME" USER="$USER" LOGNAME="${LOGNAME:-$USER}" SHELL="$LOGIN_SHELL" TERM=xterm-256color \
    LANG="${LANG:-ko_KR.UTF-8}" PATH=/usr/bin:/bin:/usr/sbin:/sbin "$LOGIN_SHELL" -lic ". '$VERIFY_SH'" 2>/dev/null | grep -E $'^[a-z]+\t[01]\t')"

ALL_OK=1
grep -q '|FAIL|' "$RES_FILE" && ALL_OK=0
echo
VERIFY_JSON=''
for k in git node npm npx gh supabase vercel claude codex code; do
    case $k in
        # 한글은 화면에서 두 칸을 차지해 printf 폭 맞춤이 어긋난다 → 칸을 직접 맞춘 이름표(14칸)
        git) lab='Git           ' ;; node) lab='Node.js       ' ;; npm) lab='npm           ' ;; npx) lab='npx           ' ;;
        gh) lab='GitHub CLI    ' ;; supabase) lab='Supabase CLI  ' ;; vercel) lab='Vercel CLI    ' ;;
        claude) lab='클로드 코드   ' ;; codex) lab='코덱스        ' ;; code) lab='VS Code       ' ;;
    esac
    row="$(printf '%s\n' "$VERIFIED" | awk -F'\t' -v k="$k" '$1 == k { print; exit }')"
    rok="$(printf '%s' "$row" | cut -f2)"; rv="$(printf '%s' "$row" | cut -f3)"; rp="$(printf '%s' "$row" | cut -f4)"
    if [ "$rok" = 1 ]; then
        printf '  %s[ OK ] %s %s%s\n' "$C_G" "$lab" "$rv" "$C_0"
        VERIFY_JSON="$VERIFY_JSON\"$k\":{\"ok\":true,\"version\":\"$(json_escape "$rv")\",\"path\":\"$(json_escape "$rp")\"},"
    else
        ALL_OK=0
        printf '  %s[실패] %s %s%s\n' "$C_R" "$lab" "$rv" "$C_0"
        VERIFY_JSON="$VERIFY_JSON\"$k\":{\"ok\":false,\"version\":\"$(json_escape "$rv")\",\"path\":\"$(json_escape "$rp")\"},"
    fi
done
if [ "$(printf '%s\n' "$VERIFIED" | awk -F'\t' '$1 == "alias" { print $2 }')" != 1 ]; then
    ALL_OK=0; printf '  %s[실패] 바로가기 cx · cc 가 새 터미널 창에서 잡히지 않습니다(~/.zshrc 확인).%s\n' "$C_R" "$C_0"
fi
clear_downloads

# 새 PATH 를 물려받도록 VS Code 를 새로 띄운다
OPENED=false
APP="$(find_vscode_app)"
if [ $NO_OPEN = 0 ] && [ -n "$APP" ] && ! pgrep -f -q 'Visual Studio Code.app/Contents/MacOS/'; then
    echo; echo '  VS Code 를 엽니다. 아래 터미널(메뉴 [터미널] → [새 터미널])에서 codex 또는 claude 를 입력해 보세요.'
    /usr/bin/open "$APP" >/dev/null 2>&1 && OPENED=true || warn 'VS Code 를 열지 못했습니다. Launchpad 나 응용 프로그램 폴더에서 직접 여세요.'
fi

STEPS_JSON="$(awk -F'|' '{ gsub(/\\/, "\\\\", $4); gsub(/"/, "\\\"", $4); printf "%s\"%s\":{\"state\":\"%s\",\"sec\":%s,\"note\":\"%s\"}", (NR > 1 ? "," : ""), $1, $2, ($3 == "" ? 0 : $3), $4 }' "$RES_FILE")"
REPORT="$LOG_DIR/result-$STAMP.json"
printf '{"kit":"mac-online","finished":"%s","user":"%s","macos":"%s","arch":"%s","allOk":%s,"openedCode":%s,"steps":{%s},"verify":{%s}}\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$(json_escape "$USER")" "$(/usr/bin/sw_vers -productVersion)" "$(mac_arch)" \
    "$([ $ALL_OK = 1 ] && echo true || echo false)" "$OPENED" "$STEPS_JSON" "${VERIFY_JSON%,}" > "$REPORT"
cp "$REPORT" "$LOG_DIR/result-latest.json"
rm -f "$RES_FILE"

echo
if [ $ALL_OK = 1 ]; then
    printf '  %s모든 설치가 끝났습니다.%s\n' "$C_G" "$C_0"
    echo '  다음 단계: 같은 폴더의 [2-login.command] 를 더블클릭하세요.'
    exit 0
else
    printf '  %s일부 설치가 안 됐습니다. 위 [실패] 줄과 아래 기록 파일을 강사에게 보여 주세요.%s\n' "$C_Y" "$C_0"
    printf '  %s%s%s\n' "$C_Y" "$LOG_FILE" "$C_0"
    exit 1
fi

#!/bin/bash
# 오토프로그 설치 키트(맥) — 로그인 마법사
# 브라우저 승인은 사람이 직접 한다. 이 스크립트는 순서를 잡아 주고, 됐는지 확인만 한다.
# --check : 로그인 상태 표만 보여 준다(아무것도 실행하지 않음 — 점검·E2E 용)

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"
refresh_session_path
mkdir -p "$LOG_DIR"
CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

# 상태: 1 = 로그인됨, 0 = 로그인 필요, - = 설치 안 됨
test_login() {
    case "$1" in
        codex)    have codex    || { echo -; return; }; codex login status >/dev/null 2>&1 && echo 1 || echo 0 ;;
        github)   have gh       || { echo -; return; }; gh auth status --hostname github.com >/dev/null 2>&1 && echo 1 || echo 0 ;;
        vercel)   have vercel   || { echo -; return; }; vercel whoami </dev/null >/dev/null 2>&1 && echo 1 || echo 0 ;;
        supabase) have supabase || { echo -; return; }; supabase projects list </dev/null >/dev/null 2>&1 && echo 1 || echo 0 ;;
        claude)
            have claude || { echo -; return; }
            # 맥의 클로드 코드는 로그인 정보를 키체인("Claude Code-credentials")에 저장한다
            if /usr/bin/security find-generic-password -s 'Claude Code-credentials' >/dev/null 2>&1 \
               || [ -f "$HOME/.claude/.credentials.json" ]; then echo 1; else echo 0; fi ;;
    esac
}
label_of() {
    # 한글은 두 칸 폭이라 printf 폭 맞춤 대신 16칸으로 직접 맞춘다
    case "$1" in codex) echo '코덱스(ChatGPT) ' ;; claude) echo '클로드          ' ;; github) echo 'GitHub          ' ;; vercel) echo 'Vercel          ' ;; supabase) echo 'Supabase        ' ;; esac
}

S_codex=''; S_claude=''; S_github=''; S_vercel=''; S_supabase=''
show_table() {
    local k s json=''
    echo
    for k in codex claude github vercel supabase; do
        s="$(test_login "$k")"
        eval "S_$k=\$s"
        case "$s" in
            -) printf '  %s[없음] %s 설치되지 않음%s\n' "$C_D" "$(label_of $k)" "$C_0"; json="$json\"$k\":null," ;;
            1) printf '  %s[ OK ] %s 로그인됨%s\n' "$C_G" "$(label_of $k)" "$C_0"; json="$json\"$k\":true," ;;
            *) printf '  %s[ -- ] %s 로그인 필요%s\n' "$C_Y" "$(label_of $k)" "$C_0"; json="$json\"$k\":false," ;;
        esac
    done
    printf '{%s}\n' "${json%,}" > "$LOG_DIR/login-latest.json"
}

title '오토프로그 로그인 마법사'
show_table
[ $CHECK_ONLY = 1 ] && exit 0

ask() {
    local a
    read -r -p "  $1 (Enter = 예 / n = 건너뛰기) " a
    case "$a" in n|N|no|아니*) return 1 ;; *) return 0 ;; esac
}

# 1. 코덱스
if [ "$S_codex" = 0 ] && ask '코덱스(ChatGPT 계정)에 로그인할까요?'; then
    step '브라우저가 열리면 ChatGPT 계정으로 로그인하세요.'
    codex login
    if ! codex login status >/dev/null 2>&1; then
        warn '브라우저 로그인이 안 됐습니다. 코드 입력 방식으로 다시 시도합니다.'
        codex login --device-auth
    fi
fi

# 2. 클로드 (클로드 코드는 처음 실행할 때 로그인 화면이 나온다)
if [ "$S_claude" = 0 ] && ask '클로드에 로그인할까요?'; then
    step '클로드가 열리면 화면 안내대로 로그인하세요. 로그인이 끝나면 /exit 를 입력해 나옵니다.'
    claude
fi

# 3. GitHub — 질문 4개를 건너뛰고 바로 브라우저 승인으로 간다. git push 도 이 로그인을 쓰게 연결한다.
if [ "$S_github" = 0 ] && ask 'GitHub 에 로그인할까요?'; then
    # git 비밀번호 관리자를 gh 로 먼저 지정해 둔다. 이게 없으면 gh 가 영어로
    # "Authenticate Git with your GitHub credentials? (Y/n)" 를 물어 수강생이 멈춘다.
    gh auth setup-git --hostname github.com --force >/dev/null 2>&1
    step '8자리 코드가 나오면 Enter 를 누르세요 → 브라우저가 열리면 코드를 붙여 넣고(⌘+V, 자동 복사됨) 승인합니다.'
    gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key --clipboard
fi
if [ "$(test_login github)" = 1 ]; then
    gh auth setup-git >/dev/null 2>&1
    # git 커밋에 쓰는 이름·이메일이 비어 있으면 GitHub 계정으로 채운다
    if [ -z "$(git config --global --get user.name 2>/dev/null)" ]; then
        login="$(gh api user --jq .login 2>/dev/null)"; id="$(gh api user --jq .id 2>/dev/null)"
        if [ -n "$login" ]; then
            git config --global user.name "$login"
            git config --global user.email "$id+$login@users.noreply.github.com"
            ok "git 사용자 이름을 GitHub 계정($login)으로 맞췄습니다."
        fi
    fi
fi

# 4. Vercel — 화면의 주소와 코드를 브라우저에서 승인
if [ "$S_vercel" = 0 ] && ask 'Vercel 에 로그인할까요?'; then
    step '브라우저에서 Continue with GitHub 를 누르면 됩니다.'
    vercel login
fi

# 5. Supabase — Enter 로 브라우저를 연 뒤, 브라우저에 나온 확인 코드(영문·숫자 8자리)를 창에 붙여 넣는다
if [ "$S_supabase" = 0 ] && ask 'Supabase 에 로그인할까요?'; then
    step 'Enter 를 누르면 브라우저가 열립니다 → 로그인 후 나오는 확인 코드(8자리)를 복사해 이 창에 붙여 넣고 Enter.'
    supabase login
fi

title '로그인 결과'
show_table
echo
echo '  [ -- ] 로 남은 곳은 터미널에서  autofrog-login  을 다시 실행하면 그것만 다시 물어봅니다.'

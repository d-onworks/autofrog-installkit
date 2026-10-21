# 오토프로그 설치 키트(맥) — 공통 함수 (setup.sh · login.sh 가 같이 쓴다)
# 맥 기본 bash 3.2 에서 돌아가게 짰다(연관 배열·${var,,} 같은 새 문법 금지).
# ⚠️ python3·git 은 맥에 "가짜(shim)"로 먼저 깔려 있어, 개발자 도구가 없으면 부르는 순간 설치 창이 뜬다 — 함부로 부르지 않는다.

KIT_HOME="$HOME/.autofrog-kit"
KIT_BIN="$KIT_HOME/bin"
NPM_GLOBAL="$HOME/.npm-global"
LOG_DIR="$HOME/autofrog-kit-logs"
PATH_BEGIN='# >>> 오토프로그 설치 키트 >>>'
PATH_END='# <<< 오토프로그 설치 키트 <<<'

if [ -t 1 ]; then
    C_G=$'\033[32m'; C_DG=$'\033[2;32m'; C_C=$'\033[36m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_D=$'\033[2m'; C_0=$'\033[0m'
else
    C_G=''; C_DG=''; C_C=''; C_Y=''; C_R=''; C_D=''; C_0=''
fi
LINE='============================================================'

title() { printf '\n%s%s%s\n  %s%s%s\n%s%s%s\n' "$C_DG" "$LINE" "$C_0" "$C_G" "$1" "$C_0" "$C_DG" "$LINE" "$C_0"; }
step()  { printf '  %s> %s%s\n' "$C_C" "$1" "$C_0"; }
ok()    { printf '  %s[완료] %s%s\n' "$C_G" "$1" "$C_0"; }
skip()  { printf '  %s[건너뜀] %s%s\n' "$C_D" "$1" "$C_0"; }
warn()  { printf '  %s[주의] %s%s\n' "$C_Y" "$1" "$C_0"; }
fail()  { printf '  %s[실패] %s%s\n' "$C_R" "$1" "$C_0"; }

# 이 키트가 쓰는 폴더를 지금 창의 PATH 앞쪽에 붙인다(새 창은 아래 write_path_block 이 맡는다)
kit_path_dirs() {
    printf '%s\n' "$KIT_BIN" "$KIT_HOME/node/bin" "$NPM_GLOBAL/bin" "$HOME/.local/bin"
}
refresh_session_path() {
    local d
    for d in $(kit_path_dirs | sed '1!G;h;$!d'); do   # 거꾸로 붙여야 원래 순서가 맨 앞에 온다
        case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
    done
    export PATH
}

# 새 터미널 창·VS Code 터미널이 읽는 셸 설정 파일에 PATH 블록을 쓴다(여러 번 실행해도 블록은 하나)
write_path_block() {
    local f tmp
    local block
    block="$PATH_BEGIN
# 이 블록은 오토프로그 설치 키트가 관리합니다. 지우면 claude·codex 명령을 못 찾습니다.
for d in \"\$HOME/.local/bin\" \"\$HOME/.npm-global/bin\" \"\$HOME/.autofrog-kit/node/bin\" \"\$HOME/.autofrog-kit/bin\"; do
  case \":\$PATH:\" in *\":\$d:\"*) ;; *) PATH=\"\$d:\$PATH\" ;; esac
done
export PATH
# 바로가기: 터미널에서 직접 칠 때만 통하는 별칭. 맥의 cc 는 원래 C 컴파일러라 파일로 덮으면 npm 설치가 깨진다.
alias cx='codex --dangerously-bypass-approvals-and-sandbox'
alias cc='claude --dangerously-skip-permissions'
$PATH_END"
    for f in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bash_profile"; do
        # bash 설정은 이미 있거나, 이 사람이 bash 를 기본 셸로 쓸 때만 만든다
        if [ "$f" = "$HOME/.bash_profile" ] && [ ! -f "$f" ] && [ "${SHELL##*/}" != "bash" ]; then continue; fi
        touch "$f"
        tmp="$f.autofrog-tmp"
        awk -v b="$PATH_BEGIN" -v e="$PATH_END" '
            $0 == b { skip = 1; next }
            $0 == e { skip = 0; next }
            !skip { print }' "$f" > "$tmp"
        printf '\n%s\n' "$block" >> "$tmp"
        # 빈 줄이 계속 쌓이지 않게 연속 빈 줄은 하나로
        awk 'NF { blank = 0; print; next } !blank++ { print }' "$tmp" > "$f"
        rm -f "$tmp"
    done
}

have() { command -v "$1" >/dev/null 2>&1; }

# 개발자 도구(Command Line Tools)가 실제로 깔려 있나 — /usr/bin/git 가짜를 건드리지 않고 확인
clt_ready() {
    local p
    p="$(/usr/bin/xcode-select -p 2>/dev/null)" || return 1
    [ -n "$p" ] && [ -d "$p" ] || return 1
    [ -x "$p/usr/bin/git" ] || [ -x "/Library/Developer/CommandLineTools/usr/bin/git" ]
}

# 진짜 git 경로(없으면 빈 값). /usr/bin/git 은 개발자 도구가 있을 때만 진짜다.
find_git() {
    local d
    local IFS=':'
    for d in $PATH; do
        [ -x "$d/git" ] || continue
        if [ "$d" = "/usr/bin" ]; then clt_ready && { echo "/usr/bin/git"; return; }; continue; fi
        echo "$d/git"; return
    done
}

is_admin() { /usr/bin/id -Gn 2>/dev/null | tr ' ' '\n' | grep -qx admin; }

json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\000-\037'; }

# 오토프로그 설치 키트(맥) — 공식 배포처에서 최신 안정판을 받아 검증한다 (setup.sh 가 불러 쓴다)
#
# 최신 버전은 깃허브 API(인터넷 주소 하나당 시간당 60회 제한) 대신 releases/latest 주소가 넘겨 주는
# 이동(redirect) 주소에서 읽는다 → 한 교실이 같은 인터넷을 써도 제한에 안 걸린다(윈도우판과 같은 방식).
# 검증: Node.js · GitHub CLI · Supabase CLI · VS Code = 공식 체크섬(SHA-256), VS Code 는 마이크로소프트 서명도 확인
#       클로드 코드 · 코덱스 = 각 회사의 공식 설치 스크립트가 체크섬을 확인한다

NODE_MAJOR=24   # 수업 기간 동안 고정(윈도우판 build.py 와 같은 값)
DL_DIR="$KIT_HOME/downloads"
UA='autofrog-installkit'

# 맥 칩 종류: arm64(애플 실리콘 M1~) 또는 x64(인텔). 로제타로 돌고 있어도 실제 칩을 본다.
mac_arch() {
    if [ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null)" = "1" ]; then echo arm64; else echo x64; fi
}

web_text() { /usr/bin/curl -fsSL --retry 3 --connect-timeout 20 --max-time 120 -A "$UA" "$1"; }

latest_tag() {
    # https://github.com/<repo>/releases/latest → .../releases/tag/<태그> 로 넘겨 준다. 그 태그만 읽는다.
    local loc
    loc="$(/usr/bin/curl -fsSI --retry 3 --connect-timeout 20 -A "$UA" "https://github.com/$1/releases/latest" \
        | tr -d '\r' | awk 'tolower($1) == "location:" { print $2 }' | tail -n 1)"
    case "$loc" in
        */releases/tag/*) echo "${loc##*/releases/tag/}" ;;
        *) echo "$1 최신 버전을 알아내지 못했습니다(이동 주소: '$loc')." >&2; return 1 ;;
    esac
}

save_download() {
    # $1 주소 $2 저장 이름 → 저장 경로 출력. 끊기면 3번까지 다시 받는다.
    local dest="$DL_DIR/$2" i
    mkdir -p "$DL_DIR"
    for i in 1 2 3; do
        if /usr/bin/curl -fL --retry 2 --connect-timeout 20 --max-time 1800 -A "$UA" -o "$dest.part" -sS "$1"; then
            mv -f "$dest.part" "$dest"; echo "$dest"; return 0
        fi
        rm -f "$dest.part"
        [ "$i" = 3 ] && { echo "내려받기 실패: $2" >&2; return 1; }
        warn "내려받기가 끊겼습니다. 다시 시도합니다($i/3)…" >&2
        sleep $((5 * i))
    done
}

find_sum() {
    # "체크섬  파일이름" 줄들($1)에서 파일($2)의 값을 찾는다
    printf '%s\n' "$1" | awk -v n="$2" '{ f = $NF; sub(/^\*/, "", f) } f == n { print tolower($1); exit }'
}

assert_sha256() {
    local got
    got="$(/usr/bin/shasum -a 256 "$1" | awk '{ print $1 }')"
    if [ -z "$2" ] || [ "$got" != "$2" ]; then
        rm -f "$1"
        echo "받은 파일이 공식 체크섬과 다릅니다(중간에 깨졌거나 바뀐 파일): ${1##*/}" >&2
        return 1
    fi
}

# get_installer <이름> → 전역 변수 INST_PATH · INST_VER 를 채운다
get_installer() {
    local arch tag ver name base sums p j url sha a
    arch="$(mac_arch)"
    INST_PATH=''; INST_VER=''
    case "$1" in
        node)
            sums="$(web_text "https://nodejs.org/dist/latest-v$NODE_MAJOR.x/SHASUMS256.txt")" || return 1
            name="$(printf '%s\n' "$sums" | awk -v a="darwin-$arch.tar.gz" '$2 ~ ("^node-v[0-9.]+-" a "$") { print $2; exit }')"
            [ -n "$name" ] || { echo "Node.js $NODE_MAJOR 맥용 파일을 찾지 못했습니다." >&2; return 1; }
            ver="${name#node-v}"; ver="${ver%%-darwin*}"
            p="$(save_download "https://nodejs.org/dist/v$ver/$name" "$name")" || return 1
            assert_sha256 "$p" "$(find_sum "$sums" "$name")" || return 1
            ;;
        gh)
            tag="$(latest_tag cli/cli)" || return 1; ver="${tag#v}"
            [ "$arch" = x64 ] && name="gh_${ver}_macOS_amd64.zip" || name="gh_${ver}_macOS_arm64.zip"
            base="https://github.com/cli/cli/releases/download/$tag"
            sums="$(web_text "$base/gh_${ver}_checksums.txt")" || return 1
            p="$(save_download "$base/$name" "$name")" || return 1
            assert_sha256 "$p" "$(find_sum "$sums" "$name")" || return 1
            ;;
        supabase)
            tag="$(latest_tag supabase/cli)" || return 1; ver="${tag#v}"
            [ "$arch" = x64 ] && name="supabase_${ver}_darwin_amd64.tar.gz" || name="supabase_${ver}_darwin_arm64.tar.gz"
            base="https://github.com/supabase/cli/releases/download/$tag"
            sums="$(web_text "$base/checksums.txt")" || return 1
            p="$(save_download "$base/$name" "$name")" || return 1
            assert_sha256 "$p" "$(find_sum "$sums" "$name")" || return 1
            ;;
        vscode)
            # 공식 업데이트 서버가 최신 주소와 체크섬을 같이 준다(JSON 은 맥 기본 plutil 로 읽는다)
            [ "$arch" = x64 ] && a=darwin || a=darwin-arm64
            j="$DL_DIR/vscode-latest.json"; mkdir -p "$DL_DIR"
            web_text "https://update.code.visualstudio.com/api/update/$a/stable/latest" > "$j" || return 1
            url="$(/usr/bin/plutil -extract url raw -o - "$j")"
            sha="$(/usr/bin/plutil -extract sha256hash raw -o - "$j")"
            ver="$(/usr/bin/plutil -extract productVersion raw -o - "$j")"
            [ -n "$url" ] && [ -n "$sha" ] || { echo 'VS Code 최신판 정보를 읽지 못했습니다.' >&2; return 1; }
            name="VSCode-$ver-$a.zip"
            p="$(save_download "$url" "$name")" || return 1
            assert_sha256 "$p" "$sha" || return 1
            ;;
        *) echo "모르는 설치 항목: $1" >&2; return 1 ;;
    esac
    INST_PATH="$p"; INST_VER="$ver"
}

clear_downloads() {
    # 다 쓴 설치 파일(수백 MB)은 지운다. 다시 실행하면 그때 새로 받는다.
    [ -d "$DL_DIR" ] && rm -rf "$DL_DIR"
    return 0
}

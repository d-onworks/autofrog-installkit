#!/bin/bash
# 오토프로그 설치 키트(맥) — 터미널 한 줄 설치
#   터미널에 붙여넣기:  curl -fsSL https://autofrog.kr/kit.sh | bash
#   (autofrog.kr/kit.sh 는 이 저장소 최신 릴리즈의 install.sh 로 넘겨준다)
#
# 왜 zip + 1-install.command 대신 한 줄인가 (2026-10-21 대표 지시):
#   브라우저로 받은 zip 의 파일에는 격리 표시(com.apple.quarantine)가 붙어 더블클릭하면 "열지 않음" 창이 뜨고,
#   다운로드 폴더에서 실행하면 "터미널이 다운로드 폴더에 접근" 허용 창도 뜬다. curl 로 받은 파일에는 표시가 없다.
#
# 하는 일: 최신 맥 키트 zip 을 받아 ~/.autofrog-kit/kit 에 풀고 → scripts/setup.sh --oneliner 를 이 창에서 돌린다
#          (setup.sh 가 끝에 이어서 로그인할지 묻고, 나중에 쓸 autofrog-login 명령을 만든다). 여러 번 실행해도 안전하다.
# 시험용 환경변수: AUTOFROG_KIT_ZIP(zip 주소·경로) · AUTOFROG_AUTO=1(묻지 않고 끝까지, E2E 용)
#
# ★맥 기본 bash 3.2 문법만. 전체를 함수로 감싸 맨 끝에서 부른다 — 받다가 끊겨도 반쪽 스크립트가 실행되지 않는다.
# ★curl | bash 는 bash 의 입력이 파이프라서 read 가 키보드를 못 읽는다 → setup.sh 는 /dev/tty 를 입력으로 준다.

autofrog_kit_main() {
    local zip_url="${AUTOFROG_KIT_ZIP:-https://github.com/d-onworks/autofrog-installkit/releases/latest/download/autofrog-setup-kit-mac.zip}"
    local kit_home="$HOME/.autofrog-kit" dest tmp src rc
    dest="$kit_home/kit"

    echo
    echo '  오토프로그 설치 키트를 내려받습니다 (인터넷 연결 필요)'
    tmp="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/autofrog-kit.XXXXXX")" || return 1
    if [ -f "$zip_url" ]; then
        /bin/cp "$zip_url" "$tmp/kit.zip"
    else
        /usr/bin/curl -fsSL --retry 3 -o "$tmp/kit.zip" "$zip_url"
    fi
    rc=$?
    if [ $rc -ne 0 ] || ! /usr/bin/ditto -x -k "$tmp/kit.zip" "$tmp/x" 2>/dev/null; then
        echo
        echo '  [실패] 설치 키트를 받지 못했습니다. 인터넷 연결을 확인하고 같은 한 줄을 다시 실행하세요.'
        echo '  계속 안 되면 이 화면을 캡처해(⌘+Shift+4) 강사에게 보여 주세요.'
        /bin/rm -rf "$tmp"
        return 1
    fi
    src="$(/usr/bin/find "$tmp/x" -path '*/scripts/setup.sh' -print | /usr/bin/head -n 1)"
    if [ -z "$src" ]; then
        echo '  [실패] 받은 파일 안에 setup.sh 가 없습니다. 강사에게 알려 주세요.'
        /bin/rm -rf "$tmp"
        return 1
    fi
    /bin/mkdir -p "$kit_home"
    /bin/rm -rf "$dest"
    /bin/mv "$(dirname "$(dirname "$src")")" "$dest"
    /bin/rm -rf "$tmp"
    /usr/bin/xattr -dr com.apple.quarantine "$dest" 2>/dev/null

    if [ "${AUTOFROG_AUTO:-}" = 1 ]; then
        /bin/bash "$dest/scripts/setup.sh" --oneliner --auto </dev/null
    elif [ -r /dev/tty ]; then
        /bin/bash "$dest/scripts/setup.sh" --oneliner </dev/tty
    else
        /bin/bash "$dest/scripts/setup.sh" --oneliner --auto </dev/null
    fi
}

autofrog_kit_main

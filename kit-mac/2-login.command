#!/bin/bash
# 오토프로그 설치 키트(맥) — 로그인 마법사 (브라우저 승인은 사람이 직접 한다)
cd "$(dirname "$0")" || exit 2
if [ ! -f scripts/login.sh ]; then
    echo '  [!] zip 압축을 먼저 풀어 주세요.'
    read -r -p '  Enter 를 누르면 창을 닫습니다 ' _
    exit 2
fi
/bin/bash scripts/login.sh "$@"
rc=$?
case " $* " in *" --check "*) ;; *) echo; read -r -p '  Enter 를 누르면 창을 닫습니다 ' _ ;; esac
exit $rc

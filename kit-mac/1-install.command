#!/bin/bash
# 오토프로그 설치 키트(맥) — 전부 설치. 더블클릭하면 터미널 창에서 실행된다.
cd "$(dirname "$0")" || exit 2
if [ ! -f scripts/setup.sh ]; then
    echo
    echo '  [!] zip 압축을 먼저 풀어 주세요: zip 파일을 더블클릭하면 같은 자리에 폴더가 생깁니다. 그 폴더 안의 이 파일을 다시 실행하세요.'
    echo
    read -r -p '  Enter 를 누르면 창을 닫습니다 ' _
    exit 2
fi
/bin/bash scripts/setup.sh "$@"
rc=$?
case " $* " in *" --auto "*) ;; *) echo; read -r -p '  Enter 를 누르면 창을 닫습니다 ' _ ;; esac
exit $rc

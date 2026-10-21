# 윈도우 한 줄 설치 E2E — 2026-10-21 live-r5 (진짜 주소, PASS)

푸시·릴리즈 v2026.10.21 · 사이트 배포 뒤, 수강생과 똑같은 한 줄 `irm https://autofrog.kr/kit.ps1 | iex` 로 돌렸다
(`-Method OneLiner -Live` → C:\e2e\live.flag, 시험 서버 대신 autofrog.kr 307 → GitHub 최신 릴리즈).

| | S1 관리자(WDAGUtilityAccount) | S2 표준 사용자 '수강생' |
|---|---|---|
| 첫 설치 | 10/10 OK · 136초 | 10/10 OK · 142초 |
| 다시 실행 | OK · 12초 | OK · 12초 |
| 바탕화면 로그인 아이콘 | 생성됨 | 생성됨 |
| 추가 명령(npx·create-next-app·로그인 도움말 등) | 9/9 exit 0 | 9/9 exit 0 |
| 샌드박스 시험 서버 요청 | 0건(진짜 주소만 씀) | 0건 |

한글 화면 정상(irm 으로 받은 install.ps1 은 ASCII, 한글은 setup.ps1).

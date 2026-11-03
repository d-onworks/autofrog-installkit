# 20261103-app-r1 — 클로드 코드 앱용(-Edition app · kosi.ps1) 샌드박스 E2E

- 방법: OneLiner(샌드박스 안 시험 서버 `localhost:8765/kosi.ps1` → install-app.ps1 → 온라인 키트 zip), 집 PC AUTOFROG 윈도우 샌드박스
- S1 = 관리자(WDAGUtilityAccount) · S2 = 표준 사용자 「수강생」(한글 이름) — 둘 다 2회 실행

| 항목 | S1 | S2 |
|---|---|---|
| 1회차 설치 (allOk) | 통과 40.2초 | 통과 38.8초 |
| 2회차 재실행 (전부 SKIP, allOk) | 통과 7.5초 | 통과 8.0초 |
| 버전 표 | git 2.56.0.windows.4 · node v24.22.2 · npm/npx 11.19.1 · gh 2.103.3 · supabase 3.0.0 · vercel 65.10.0 · 앱(Git Bash) 7개 명령 | 같음 |
| 새 PowerShell 창 명령 9개(npx·npm view·create-next-app·로그인 도움말 3종·Git Bash 도구·Git Bash gh) | 9/9 | 9/9 |
| 새 Git Bash(-lc, 레지스트리 PATH)에서 7개 명령 위치 + vercel 실행 | 통과 | 통과 |
| 만들지 않아야 할 것(로그인 아이콘·VS Code·claude CLI·codex) | 모두 없음 | 모두 없음 |
| CLAUDE_CODE_GIT_BASH_PATH | `…\AppData\Local\Programs\Git\bin\bash.exe` | 같음(수강생 경로) |

- 화면 확인: S2 install-1 시작 화면(사전 점검 — 한글 사용자 이름 주의, 「클로드 앱을 찾지 못했습니다」 주의 = 샌드박스엔 앱이 없어 정상), 최종 버전 표 8줄 OK.
- 시험하지 못한 것: 클로드 데스크톱 앱 자체(로그인 필요) 안에서의 실행, 진짜 주소(autofrog.kr/kosi.ps1 — 배포 전), GitHub·Vercel·Supabase 실제 로그인.

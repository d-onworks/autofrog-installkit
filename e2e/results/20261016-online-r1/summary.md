# 온라인판 E2E — 20261016-online-r1

- 대상: `dist/autofrog-setup-kit.zip`(온라인판, 설치 파일 없이 스크립트만 49KB) — `build.py --online`
- 환경: 집 PC 윈도우 샌드박스(매번 새 PC). S1 = 기본 관리자 계정(WDAGUtilityAccount), S2 = 관리자 아닌 한글 이름 계정(수강생)
- 시각: 2026-10-16 22:02~22:12 KST

| 항목 | S1 | S2 |
|---|---|---|
| 1차 설치(`1-install.bat /auto`) | exit 0 · 145초 | exit 0 · 146초 |
| 온라인 내려받기·검증 | Git 2.56.0.2(서명) · Node 24.22.0 · gh 2.102.0 · Supabase 2.121.0 · 코덱스 0.163.0 · VS Code 1.142.0(체크섬) | 같음 |
| 버전 표 10줄 | 전부 OK | 전부 OK |
| 설치 끝에 VS Code 열림 | openedCode=true (캡처에 창 뜨는 장면) | openedCode=true |
| 새 PowerShell(우회 없음) 9개 명령 | npx·npm·npm view·create-next-app·gh/vercel/supabase login --help·claude·codex 전부 exit 0 | 같음 |
| 2차 실행(멱등) | 8초, 전부 건너뜀 | 9초, 전부 건너뜀 |
| `2-login.bat /check` | exit 0 | exit 0 |

- 온라인판 내려받은 설치 파일(약 560MB)은 설치 끝에 지운다(`Clear-OnlineDownloads`).
- 확인 못 한 것: 실제 로그인, 회사 보안 정책 PC, 느린 인터넷에서의 시간. S2 탐색기 PATH 확인은 하네스 한계(다른 사용자로 탐색기 실행 불가)로 미완 — 이전 회차와 같음.

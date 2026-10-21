# 윈도우 한 줄 설치 E2E — 2026-10-21 r3 (PASS)

방식: 샌드박스 안 시험 서버가 실제 배포처처럼 `application/octet-stream` 으로 내보내고, `kit.ps1` → 302 → `install.ps1` → 키트 zip 순서로 받는다.
창에서 실제 명령 `powershell -ExecutionPolicy Bypass -c "irm …/kit.ps1 | iex"` 를 그대로 실행(AUTOFROG_AUTO=1 만 추가).

| 항목 | S1 (관리자 WDAGUtilityAccount) | S2 (표준 사용자 '수강생', 한글 이름) |
|---|---|---|
| 첫 설치 → 버전 표 | 10/10 OK (150초) | 10/10 OK |
| 다시 실행 | 10/10 OK (11초) | 10/10 OK (10.6초) |
| 키트 폴더 인터넷 표시(Zone.Identifier) | 0개 | 0개 |
| 바탕화면 [오토프로그 로그인] 바로가기 | 생성 · 표시 없음 · login.ps1 -CheckOnly exit 0 | 같음 |
| 추가 명령(npx·claude·codex·create-next-app 등) | 9/9 | 9/9 |
| 첫 줄 오류·한글 깨짐 | 없음 (부트스트랩 ASCII) | 없음 |

이전 회차: r1 — S1 통과했으나 부트스트랩 한글이 ISO-8859-1 로 깨지고 BOM 이 첫 줄 오류(`'﻿#' 인식 안 됨`)를 냄 → 부트스트랩을 ASCII 로 바꾸고 한글 안내는 setup.ps1 로 옮김. S2 는 하네스 따옴표 버그로 미실행. r2 는 중단.

스마트 앱 컨트롤 실기(대표 집 PC, SAC 켜짐, 탐색기 경유 실행): 표시 없는 .bat 실행됨 · 표시 있는 .bat 막힘(CI 3033) · .ps1 -File 실행됨(표시 유무 무관, FullLanguage) · 내 PC 에서 만든 바로가기→PowerShell 실행됨. 블로그 도구를 PowerShell 로 받아 푼 시작.bat 도 실행됨(CI 이벤트 0).

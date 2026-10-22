# 2026-10-22 샌드박스 Git 멈춤 — 원인: 샌드박스의 스마트 앱 컨트롤 켜짐 → 키트가 먼저 묻고 끄게 고침

## 원인 (진단 샌드박스 gitprobe, 보안 기록으로 확정)
- 샌드박스 안 `HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy` `VerifiedAndReputablePolicyState` = **1(켜짐·막음)**, SAC_EnforcementReason=1.
- CodeIntegrity 3077/3033, 정책 `{0283ac0f-fff1-49ae-ada1-8a933130cad6}`: git.exe 가 `ucrt64\bin\zlib1.dll`·libiconv-2.dll·libpcre2-8-0.dll·libintl-8.dll(서명 없음)을 못 읽음 → "잘못된 이미지"(0xc0e90002) 창 → Git 설치 프로그램이 그 뒤에서 끝나지 않음.
- Git 2.55.0.5(mingw64): git 은 되지만 `usr\bin\bash.exe`(클로드 코드가 쓰는 Git Bash)가 같은 정책에 막힘 → **버전으로는 못 피함**.
- 관리자 권한으로 값 0 + `CiTool --refresh --json` → 재부팅 없이 git·bash 모두 실행됨. (`--json` 없으면 CiTool 이 끝에서 Enter 를 기다려 멈춤)
- 어제(live-r5)는 같은 Git 2.56.0.2 로 통과 → 그 뒤 샌드박스가 켜짐 상태로 뜨기 시작함(집 PC 본체는 Off).

## 고친 것
- setup.ps1 0-1단계: 켜짐(1)이면 "지금 끌까요?" → 관리자 확인 → 끄고 이어서 설치. 거절·-Auto 면 끄는 법 안내 후 코드 3.
- Git 설치 대기 10분 제한(막혀서 안 끝나면 끊고 원인 안내).
- build.py: 원본 BOM 을 한 번만(utf-8-sig) — 편집 중 setup.ps1 에 BOM 이 붙어 zip 에서 두 겹 → PowerShell 5.1 이 첫 줄·param 을 못 읽어 -Auto/-OneLiner 가 무시되던 것(zip-r2 에서 발견, 올라간 zip 은 영향 없음).
- 하네스: 부팅 때 샌드박스 스마트 앱 컨트롤을 끈다(보통 PC 흉내). C:\e2e\sac-on.flag 면 켠 채.

## 결과
| 회차 | 내용 | 결과 |
|---|---|---|
| gitprobe A | 켜짐 + setup -Auto | 5초 만에 안내, exit 3, 파싱 오류 0 |
| gitprobe C·D | 끄는 명령(setup 과 같은 문자열) → 전체 설치 | 1→0, 11단계 OK 152초 |
| zip-r3 S1 | zip → 1-install.bat, 관리자 | 첫 설치 134초 allOk · 재실행 9초 · 로그인 확인 · 추가 명령 9/9 |
| zip-r3 S2 | 같은 것, 표준 사용자 '수강생' | 첫 설치 129초 allOk · 재실행 9초 · 로그인 확인 OK · 추가 명령 중 create-next-app 내려받기 150초 초과 1건(네트워크) |
| two-r2 S2 | 2번 명령(cmd, Win+R 과 같음), 표준 사용자 | 첫 설치 allOk · 재실행 13초 · 로그인 · 추가 명령 전부 exit 0 |

# 2026-10-22 zip 판(1-install.bat) · 2번 명령 E2E — 설치 시작까지 확인, 전체 설치는 샌드박스 환경 문제로 미완

| 회차 | 방식 | 결과 |
|---|---|---|
| zip-r1 S1 | zip 을 바탕화면에 두고 인터넷 표시(ZoneId=3) → 압축 풀기 → `1-install.bat /auto` | setup.ps1 시작 · 0단계 통과 · Git 내려받기 OK → **Git 설치 중 git.exe "잘못된 이미지"(zlib1.dll, 0xc0e90002) 창에서 멈춤** |
| two-r1 S1 | 2번 명령을 cmd 로(Win+R 과 같음), 진짜 주소 autofrog.kr | 같은 지점에서 같은 오류로 멈춤 → **어제 통과한 경로(install.ps1·setup.ps1 변경 없음)도 똑같이 막힘** |

- 0xc0e90002 = 코드 무결성 정책 위반. 집 PC 는 10/21 20:31 에 CI 정책 새로고침이 있었고 지금 스마트 앱 컨트롤은 Off. 어제 오후 live-r5 는 같은 Git 2.56.0.2 로 통과 → 샌드박스 쪽 환경 변화로 판단(키트 변경과 무관). 원인은 별도 조사.
- 2번 명령 따옴표 점검(집 PC 본체, 받은 파일 첫 줄 확인만): 열린 PowerShell 창에 붙여 넣은 경우 · cmd(Win+R) 경우 모두 install.ps1 을 받아 -File 로 넘김 OK.
- 화면: S1-git-zlib1-error.png

# 3회차 최종 결과 — 추가 검사 S1·S2 모두 PASS

지정한 ZIP을 그대로 사용했다. SHA256 `f137649461287c8ccf16065da6623ed402557dd225c734d67b7dd080d5d79b37`. 키트 추가 수정·재빌드 없음. 실제 로그인 없음. 캡처 하네스 문제를 고쳐 같은 ZIP으로 재검증 1회 수행했다.

| 실행 | S1 첫 설치 / 재실행 | S2 첫 설치 / 재실행 | 추가 명령 JSON | 추가 명령 화면 |
|---|---|---|---|---|
| 3회차 최초 | 126.04초 / 9.53초 | 136.46초 / 10.52초 | 양쪽 9/9 PASS | 바탕화면·빈 창으로 불충분(③) |
| 캡처 수정 후 재검증 | 122초 / 8.11초 | 129.91초 / 8.91초 | 양쪽 9/9 PASS | 실제 명령 출력 직접 확인 PASS |

양 실행 모두 설치·재실행 exit=0. 재검증은 정리→S1→정리→S2 순서로 깨끗한 샌드박스에서 수행했다.

| 추가 명령 | S1 exit | S2 exit | 실제 출력 요약 |
|---|---:|---:|---|
| `npx --version` | 0 | 0 | 11.19.1 |
| `npm --version` | 0 | 0 | 11.19.1 |
| `npm view vercel version` | 0 | 0 | 64.3.1 |
| `npx -y create-next-app@latest --version` | 0 | 0 | 16.4.2 |
| `gh auth login --help` | 0 | 0 | Authenticate with a GitHub host. (도움말) |
| `vercel login --help` | 0 | 0 | Vercel CLI 64.3.1, login 도움말 |
| `supabase login --help` | 0 | 0 | DESCRIPTION / Authenticate using an access token. (도움말) |
| `claude --version` | 0 | 0 | 2.1.301 (Claude Code) |
| `codex --version` | 0 | 0 | codex-cli 0.163.0 |

각 명령의 **실제 자식 PowerShell context**에서 HKCU/HKLM 레지스트리로 갱신한 PATH, `RemoteSigned`, `processPolicy=null`, 올바른 사용자·프로필을 확인했다. parent 검사 창도 `powershell -NoProfile -File ...`로 열어 ExecutionPolicy 옵션을 주지 않았다. 각 명령은 최대 150초로 제한했다. 정책 오류·cmdlet 인식 오류·타임아웃은 0건.

원본 stdout·stderr·초·종료코드·실행 컨텍스트: [S1 command-checks.json](S1/command-checks.json), [S2 command-checks.json](S2/command-checks.json). stderr의 PS5.1 모듈 초기화 CLIXML progress는 원본에 남겼으며, 명령 오류로 분류하지 않았다.

| 기존 검사 | S1 | S2 |
|---|---|---|
| 첫 설치·재실행 | exit=0, allOk=true | exit=0, allOk=true |
| 마지막 표 10줄(npx 포함) | 전부 [ OK ], PNG 직접 확인 | 전부 [ OK ], PNG 직접 확인 |
| 레지스트리 PATH 새 PowerShell | npx 포함 명령·위치 12개 정상 | 한글 경로에서 12개 정상 |
| 요구 확장 4개·설정·Codex 설정 | 정상, 재실행 중복 없음 | 정상, 재실행 중복 없음 |
| 주요 9단계 멱등성 | 전부 SKIP | 전부 SKIP |
| 2-login.bat /check | exit=0, 5개 false | exit=0, 5개 false |
| Explorer 경유 | PASS, 같은 사용자·3개 where exit=0 | 미검증(②, 기존 한계 유지) |

이번 추가 요청은 S1·S2 모두 PASS. 전체 기존 시나리오는 S1 PASS, S2는 Explorer 경유만 미검증이므로 완전 PASS로 확대 해석하지 않는다. S2는 같은 세션에서 대체 자격으로 표준 사용자 프로세스를 실행한 방식이며 실제 별도 데스크톱 로그인은 아니다. `explorer.json`의 completed=false를 보존했다.

직접 열어 확인한 최종 화면:
- [S1 10줄 버전 표](S1/screens/131903_083_final-version-table.png)
- [S2 10줄 버전 표](S2/screens/132303_552_final-version-table.png)
- [S1 create-next-app 다운로드·실행](S1/screens/131935_001_check-create-next-app-pass.png)
- [S2 create-next-app 다운로드·실행](S2/screens/132337_043_check-create-next-app-pass.png)
- [S1 추가 명령 9개 결과](S1/screens/131948_260_check-all-results.png)
- [S2 추가 명령 9개 결과](S2/screens/132349_509_check-all-results.png)
- [S2 vercel login --help](S2/screens/132342_762_check-vercel-login-help-pass.png)

③ 발견·수정한 하네스 문제:
1. 이전 상태 조회 `C:\AutoFrogE2E\status.ps1 -RunId 20261016-1030-r1b` PID 9036이 약 11GB를 점유한 채 남아 호스트 PowerShell 생성·전송이 리소스 부족으로 실패했다. 명령줄·생성 시각 확인 후 해당 E2E PID만 종료했다. 원문 일부는 [최초 실행 host-resource-error.txt](../20261016-r3-npx/host-resource-error.txt). 이후 구문 검사·전송·SHA 일치 확인 정상. final-cleanup.ps1에 같은 전용 status.ps1 잔류 검사·정리를 추가했다.
2. 추가 검사 parent의 ProcessStartInfo/EncodedCommand 실행에서는 JSON은 정상이었지만 화면이 바탕화면 또는 빈 콘솔이었다. [S1 바탕화면 캡처](../20261016-r3-npx/S1/screens/130955_197_check-create-next-app-pass.png), [S2 빈 콘솔](../20261016-r3-npx/S2/screens/131418_905_check-all-results.png)을 직접 확인했다. `inside.ps1`의 Run-VisibleChecks를 새 최대화 창에서 `-File` 실행으로 바꾸고, Bypass 환경변수 제거·레지스트리 PATH 갱신 조건을 유지했다. 재검증 후 실제 출력이 보이는 위 PNG들로 해소 확인.
3. 추가 파일은 e2e/command-check.ps1이며 명령별 JSON·캡처·타임아웃을 담당한다. e2e/probe.ps1에는 npx 버전 검사를, visible-install.ps1에는 정확한 [ OK ] 표기를 반영했다. 키트 파일·build.py는 이번 작업에서 수정하지 않았다.

② 기존 환경 한계: 게스트 빌드 26100, winget 없음, S1 관리자, S2 대체 자격 표준 계정. S2 Explorer 미검증 이외 이번 추가 명령의 환경 차이 문제는 없었다. ① 수강생 PC에서도 발생할 새로운 키트 결함은 발견되지 않았다.

상세 기계 판정: [assessment.json](assessment.json). 각 시나리오 cleanup.json에서 clean=true 확인. 최종 final-cleanup.json에서 제어부 예약 작업 2개 제거, 잔여 E2E 예약 작업·Sandbox 프로세스 없음 확인. 별도 status.ps1 잔류도 검사했고 발견된 잔류 PID는 없었다. C:\AutoFrogE2E 자료는 보존했다.

최종 ZIP: `autofrog-setup-kit-20261016.zip` — **589,958,454 bytes (약 589.958 MB)**. 원본·호스트 검증 ZIP·현재 setup.ps1 일치 확인. 커밋·푸시 없음.

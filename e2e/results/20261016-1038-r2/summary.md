# 2회차 결과 — S1 PASS / S2 FAIL(② 탐색기 미검증)

설치 키트의 발견된 결함은 수정 후 재검증했다. S2는 표준·한글 계정에서 설치와 독립 명령 검사를 통과했지만 Explorer 경유 검사가 기술적으로 막혀 완전 PASS로 판정하지 않는다. 최초 지시의 “S2가 기술적으로 막히면 지점·시도 방법을 보고하고 S1 결과로 마무리” 예외에 따라 종료한다.

| 회차 | S1 | S2 | 첫 설치 S1 / S2 | 남은 문제 |
|---|---|---|---|---|
| 1회차 하네스 시도(1028-r1) | 설치 전 중단 | 미실행 | 없음 | ③ ADS 읽기·VM ID 자동변수 충돌, 수정 후 해소 |
| 1회차 재시도(1030-r1b) | FAIL | FAIL | 131.77초 / 126.26초 | ① 정책·버전 표 오판, ③ S2 한글 출력 디코딩 |
| 2회차(1038-r2) | PASS | FAIL(② 탐색기만 미검증) | 137.65초 / 145.58초 | S2 Explorer 결과 파일 미생성 |

| 검사 | S1 | S2 |
|---|---|---|
| 설치 / 재실행 종료코드 | 0 / 0 | 0 / 0 |
| 재실행 시간 | 8.75초 | 11.35초 |
| result-first·second allOk | true / true | true / true |
| 새 PowerShell 명령·위치 11개 | 모두 정상 | 모두 정상 |
| 새 PowerShell 정책 | RemoteSigned, Process 우회 없음 | RemoteSigned, Process 우회 없음 |
| Explorer where claude/codex/vercel | 3개 exit=0, 같은 사용자 확인 | 결과 파일 없음(60초) |
| Codex 설정·파싱 | 최초/재실행 모두 정상·중복 없음 | 최초/재실행 모두 정상·중복 없음 |
| 요구 확장 4개·settings·argv | 모두 정상 | 모두 정상 |
| 로그인 /check | exit=0, 5개 false | exit=0, 5개 false |
| 주요 설치 9단계 재실행 | 모두 SKIP | 모두 SKIP |
| MOTW ZoneId=3·ZIP 해시 | 확인 | 확인 |
| 화면 시작·매 60초·버전 표·재실행 | 수집 | 수집 |

`precheck`와 `extras`는 재실행에도 OK이며, 주요 도구 설치와 정책 단계 9개가 SKIP이다. extras는 기존 설계대로 설정·확장을 재확인한다. 상세 기계 판정은 [assessment.json](assessment.json).

① 수정한 키트 결함과 재검증:
- `kit/scripts/setup.ps1` 정책: CurrentUser 저장 성공 후 Process=Bypass 우선순위로 던지는 `ExecutionPolicyOverride`만 저장값 확인 후 처리. 다른 오류는 다시 던진다. 1회차 원문: `[실패] 5. PowerShell 실행 정책 — Security error.` / `Windows PowerShell updated your execution policy successfully, but the setting is overridden by a policy defined at a more specific scope.` 2회차 양쪽 policy=OK, 새 창 RemoteSigned.
- 같은 파일 버전 검사: `Select-Object -First 1`로 출력을 조기 종료하던 부분을 전체 소비→종료코드 저장→첫 줄 표시로 수정. 검증 자식의 Process Bypass 환경변수도 제거. 1회차 `[실패] 코덱스 codex-cli 0.163.0`처럼 정상 버전이 실패로 표시됐으나 2회차 버전 9개 전부 OK, 설치·재실행 모두 exit=0.
- Marketplace 사전점검: HEAD=404, GET=200 확인 후 이 호스트만 GET 사용. 1회차의 “회사 방화벽” 오진이 2회차에 사라짐.
- 단계 FAIL이 있으면 전체 allOk=false로 집계하도록 보완. Git은 관리자 샌드박스에서도 사용자 폴더에 설치되도록 `/DIR` 명시. Git→Node 순서, 관리자 권한 없는 사용자 폴더 설치, Claude 공식 서버 다운로드·미동봉, Codex 상단 두 설정 설계는 유지했다.
- 정확한 변경은 [1회차 패치](../20261016-1030-r1b/kit-fixes.patch). build.py 변경 없음.

③ 수정한 하네스 문제:
- ADS 읽기 `.NET ReadAllText`의 `The given path’s format is not supported.` → `Get-Content -Stream`과 메타데이터 없는 문자열 결합.
- `$matches`/자동변수 `$Matches` 충돌로 VM ID=null → `$vmMatches`. 실제 kill exit=0·잔여 VM 없음으로 재검증.
- SSH 종료에 따른 제어부 소멸 → SYSTEM 예약 작업. Sandbox 창은 오토프로그 Interactive 예약 작업 유지.
- 화면 스크립트 복사 누락, 경고 캡처 반복, 상태 로그 직렬화, S2 UTF-8 stdout 디코딩을 보완. S2 fresh.json의 사용자·모든 경로 한글이 정확하고 11개 명령 정상으로 재검증.
- 마지막 표의 화면 하단 잘림을 발견해 visible-install.ps1 마지막 화면에 전체 표를 다시 표시. S2 재실행 캡처에서 9개 OK와 SKIP을 직접 확인했다.

② 남은 환경 한계:
- S2는 WDAGUtilityAccount의 세션 1에서 `Start-Process -Credential -LoadUserProfile`로 표준 사용자 프로세스를 실행했다. `admin=false`, `C:\Users\수강생`은 확인했지만 수강생의 실제 대화형 데스크톱 로그인은 아니다.
- 1회차 `explorer.exe "...explorer-check.cmd"`, 2회차 `/separate,"...explorer-check.cmd"` 모두 60초 내 결과 파일 미생성. [explorer.json](S2/explorer.json)의 `completed=false`. 따라서 실제 수강생 데스크톱에서 Explorer/VS Code를 새로 여는 확인은 미검증이다. 오류 UI가 없어 이 문제의 에러 장면은 없으며, 당시 설치 원문과 전후 캡처를 보존했다.
- 샌드박스 게스트는 빌드 26100, 호스트는 26200이며 winget이 없다. S1 관리자·S2 표준 계정 특성이 실제 회사 정책 PC와 다를 수 있다.

직접 열어 확인한 화면:
- [1회차 S1 실패 표](../20261016-1030-r1b/S1/screens/103049_983_final-version-table.png), [1회차 S2 실패 표](../20261016-1030-r1b/S2/screens/103428_338_final-version-table.png).
- [2회차 S1 버전 표](S1/screens/104033_468_final-version-table.png): 화면 하단 두 줄은 잘려 있어 전체 9개 성공 판정은 JSON에 근거한다.
- [2회차 S2 전체 버전 표·SKIP](S2/screens/104612_050_idempotent-end.png): 9개 버전 OK, 주요 9단계 SKIP, exit=0 확인.
- 원문은 각 시나리오의 `autofrog-kit-logs/setup-*.log`, `result-first.json`, `result-second.json`, `fresh.json`에 있다.

| 첫 설치 단계 | S1 초 | S2 초 |
|---|---:|---:|
| precheck | 1.5 | 1.2 |
| git | 12.8 | 14.1 |
| node | 1.9 | 1.8 |
| gh | 0.2 | 0.2 |
| supabase | 0.7 | 0.6 |
| vscode | 28.9 | 28.7 |
| policy | 0 | 0 |
| vercel | 10.5 | 9.3 |
| claude | 15.9 | 16.7 |
| codex | 1.5 | 1.5 |
| extras | 49.5 | 57.8 |

최종 ZIP: `autofrog-setup-kit-20261016.zip` — **589,958,448 bytes (589.958 MB)**, 빌드 2026-10-16 10:34 KST.

SHA-256: `7d73b84f72b620811209917f02e5a0fd3c42d9b43ed1a328588c2a93349c747e`. 윈도우에서 테스트한 ZIP과 해시 일치, ZIP 안 setup.ps1과 현재 소스 일치 확인. Windows Vercel CLI는 64.3.1로 설치·검증됐다.

각 시나리오 cleanup.json의 clean=true 확인. 최종 `final-cleanup.json`과 `final-cleanup-vm.json`에서 E2E 예약 작업 3개 제거, 잔여 예약 작업·Sandbox 프로세스 없음·clean=true 확인. C:\AutoFrogE2E 자료는 남겼다. 커밋·푸시는 하지 않았다.

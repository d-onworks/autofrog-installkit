# 1회차 — S1 FAIL / S2 FAIL (키트 검증 로직 결함)

| 시나리오 | 첫 설치 | 재실행 | 독립 검사 | 탐색기 |
|---|---:|---:|---|---|
| S1 | 131.77초 / exit=1 | 9.35초 / exit=1 | 명령 11개 정상 | claude/codex/vercel 위치 정상 |
| S2 | 126.26초 / exit=1 | 8.49초 / exit=1 | stdout 한글 디코딩 오류(③) | 대체 사용자 explorer 미완료(②) |

① 실행 정책: `Set-ExecutionPolicy`는 CurrentUser=RemoteSigned를 저장했지만 Process=Bypass 우선순위로 예외. `setup.ps1`에서 ExecutionPolicyOverride인 경우 실제 저장값을 확인하고 성공 처리하도록 수정.

① 마지막 버전 표: 정상인 Node/npm/Supabase/Codex/Code(한글 계정에서는 Claude도)를 실패 표시. `Select-Object -First 1`이 네이티브 출력 파이프를 조기 종료하여 `$LASTEXITCODE`가 설정되지 않는 원인. 전체 출력을 먼저 받고 종료코드 저장 후 첫 줄 선택으로 수정. 검증용 PowerShell에도 Process Bypass 환경변수를 상속하지 않도록 보완. 실패 단계가 있으면 allOk=false로 집계한다.

① Marketplace 사전점검: HEAD=404, GET=200. HEAD 미지원 응답을 방화벽 차단으로 오진하여 GET 사용으로 변경. 확장 4개는 실제로 설치됨.

② 관리자 샌드박스의 Git 기본 설치 위치가 Program Files. 사용자 폴더 설치 설계 유지를 위해 `/DIR=%LOCALAPPDATA%\Programs\Git` 명시. S2 표준 계정에서는 기존에도 사용자 폴더에 설치됨.

③ S2 독립 검사 UTF-8 출력을 기본 코드페이지로 읽어 JSON 파손. `inside.ps1`의 새 PowerShell 프로세스 stdout 디코더를 UTF-8로 지정. S2 `fresh.stdout.log`에는 모든 명령 ok=true지만 한글 경로가 깨졌으므로 독립 검사 PASS로 판정하지 않음.

② S2 탐색기: `Start-Process explorer.exe <cmd>`가 표준 사용자 결과 파일을 만들지 않음(60초). 다음 회차에서 `/separate` 시도. 별도 대화형 로그온의 탐색기 환경과 다를 수 있음.

화면 직접 확인: `S1/screens/103049_983_final-version-table.png`, `S2/screens/103428_338_final-version-table.png`. 보이는 최대화 콘솔에서 정상 버전에 실패가 표시된 것을 확인. 정책 예외 원문은 각 `autofrog-kit-logs/setup-*.log`. `S1/screens/102926_739_install-1-warning.png`도 직접 확인.

Codex 상단 두 설정은 최초·재실행 모두 각 1개, topLevelCorrect=true. settings.json·argv.json 존재. 로그인 점검은 양쪽 exit=0이며 로그인 정보 없는 상태.

| 첫 설치 단계 | S1 초 | S2 초 |
|---|---:|---:|
| precheck | 1 | 1.3 |
| git | 12.8 | 12.8 |
| node | 1.8 | 1.8 |
| gh | 0.2 | 0.2 |
| supabase | 0.6 | 0.6 |
| vscode | 28.7 | 28.7 |
| policy | 0 | 0 |
| vercel | 10.1 | 8.9 |
| claude | 16.2 | 15.3 |
| codex | 1.3 | 1.2 |
| extras | 49.5 | 46.1 |

수정 파일: `kit/scripts/setup.ps1`, `e2e/inside.ps1`, `e2e/screen-monitor.ps1`. build.py 변경 없음. 수정 후 빌드된 ZIP으로 2회차 실행 예정.

샌드박스 차이: OS 게스트 빌드 26100(호스트 26200), winget 없음, S1은 관리자, S2는 같은 세션에 다른 사용자 프로세스만 띄우는 방식. VM·예약 작업 정리 결과는 cleanup JSON에 보존.

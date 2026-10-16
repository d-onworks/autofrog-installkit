# 3회차 — 진행 중

지정 ZIP SHA256 f137649461287c8ccf16065da6623ed402557dd225c734d67b7dd080d5d79b37. S1→VM 정리→S2. 추가 명령 9개를 명령당 150초 제한, 새 레지스트리 PATH·프로세스 우회 없음 조건으로 JSON+캡처 검증한다. 실제 로그인은 하지 않는다.

실행 전 ③ 하네스 잔류 프로세스: 이전 status.ps1(1030-r1b) PID 9036이 약 11GB 사용, PowerShell 생성이 0x800705AF(페이지 파일/리소스 부족)로 실패. 명령줄과 생성 시각을 확인한 뒤 해당 E2E PID만 종료. ZIP 부분 전송은 다시 전송하고 SHA256 확인 후 진행.

실행 전 확인: 오토프로그 Active, 잔여 샌드박스 없음, PowerShell 5.1 스크립트 27개 파싱 오류 0. 호스트 ZIP SHA256 일치. 3회차 S1 시작.

S1 최초 설치: exit=0、126.04초. `S1/screens/130921_444_final-version-table.png` 직접 열어 npx 포함 10줄 전부 [ OK ] 확인. 추가 명령 검사 진행 예정.

S1 추가 명령 9개 전부 exit=0, completed=true/allOk=true. 모든 자식 PowerShell context에서 RemoteSigned·processPolicy=null 확인. npm 인터넷 조회·create-next-app 인터넷 다운로드 실행 성공. 원본은 S1/command-checks.json, 명령별 PNG에 보존.

③ 추가 검사 캡처 결함: S1 명령별 PNG와 all-results PNG를 직접 열었으나 바탕화면뿐임. ProcessStartInfo 실행이 기존 숨은 콘솔을 상속한 원인. 기존 설치 창과 같은 Start-Process -WindowStyle Maximized로 바꾸되 환경의 Process Bypass는 제거하고 PATH는 레지스트리에서 갱신. JSON 검사는 통과했지만 S1 추가 캡처는 재검증 필요.

S2 최초 설치 exit=0, 136.46초. 최초 확인 표 PNG 직접 열어 npx 포함 10줄 [ OK ] 확인. S2 추가 명령 9개 exit=0/allOk=true이나 명령 캡처가 빈 콘솔로 확인되어 화면 증거는 미통과. -File 방식 재실행 예정.

| 시나리오 | 첫 설치 | 재실행 | 추가 명령 | 10줄 버전 표 | 추가 명령 캡처 |
|---|---|---|---|---|---|
| S1 | exit=0, 126.04초 | exit=0, 9.53초 | 9/9 PASS | 직접 확인 PASS | FAIL(③) |
| S2 | exit=0, 136.46초 | exit=0, 10.52초 | 9/9 PASS | 직접 확인 PASS | FAIL(③) |

키트 결함은 발견되지 않았다. 요구된 화면 증거가 불충분하므로 완전 PASS로 판정하지 않고 `20261016-r3-capture-retry`에서 같은 ZIP으로 S1·S2를 재실행한다. S2 Explorer 경유는 이전과 같은 ② 한계로 미검증. 양 시나리오 cleanup.json의 clean=true 확인.

후속 캡처 재검증 완료: [최종 보고서](../20261016-r3-capture-retry/summary.md). 같은 ZIP으로 명령 출력이 보이는 캡처를 확보했고 추가 검사 S1·S2 모두 PASS.

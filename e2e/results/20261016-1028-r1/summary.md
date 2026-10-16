# 1회차 — 설치 전 하네스 실패

| S1 | S2 | 설치 시간 |
|---|---|---|
| 미도달(③) | 미실행 | 없음 |

- ③ `inside.ps1:120`: `ReadAllText(zip + ':Zone.Identifier')` → `The given path’s format is not supported.` ADS 읽기를 `Get-Content -Stream`으로 바꾸고 문자열 결합으로 메타데이터를 제거했다.
- ③ `cleanup.ps1`: `$matches`가 `-match`의 자동변수 `$Matches`와 충돌하여 VM ID=null로 `hcsdiag kill` 호출. 별도 `$vmMatches`로 수정. 실제 VM 종료는 후속 정리에서 확인한다.
- ③ SSH에서 Start-Process로 분리한 제어부는 SSH 종료 시 함께 사라짐. SYSTEM 예약 작업으로 제어부 유지, 샌드박스 GUI는 오토프로그 Interactive 예약 작업으로 실행.
- 화면: `S1/screens/102625_093_monitor-end.png` 직접 열어 확인. 설치 전 실패하여 바탕화면만 보임. 오류 원문은 `S1/error-Worker.json`, `cleanup-S1.json`에 보존.
- 키트 변경 없음. 하네스 수정 뒤 새 실행 폴더로 재실행 예정.

정리 재검증: `cleanup-corrected.json`에서 WindowsSandbox VM 종료 코드 0, `clean=true`, 잔여 프로세스 없음. SavedAsTemplate CmService VM은 건드리지 않았다.

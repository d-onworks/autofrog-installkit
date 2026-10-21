# Windows 설치 키트 E2E — 최신 결과

[2026-10-21 한 줄 설치(PowerShell) r4 최종 — S1·S2 PASS](20261021-oneliner-r4/summary.md) · [r3 상세](20261021-oneliner-r3/summary.md)

이전(zip·1-install.bat 방식):


[3회차 최종 상세 보고서](20261016-r3-capture-retry/summary.md)

지정 SHA256 f137649461287c8ccf16065da6623ed402557dd225c734d67b7dd080d5d79b37 ZIP으로 추가 검사 S1·S2 모두 PASS. 첫 실행에서 화면 캡처가 불충분해 하네스만 수정하고 같은 ZIP으로 재검증 1회 수행했다. 키트 추가 수정·재빌드 없음.

| 항목 | S1 | S2 |
|---|---|---|
| 추가 명령 | 9/9 exit=0 | 9/9 exit=0 |
| 정책 우회·명령 인식 오류 | 없음 | 없음 |
| npx 포함 최종 버전 표 | 10/10 OK | 10/10 OK |
| 첫 설치 / 재실행 | 122초 / 8.11초 | 129.91초 / 8.91초 |
| 기존 전체 시나리오 | PASS | Explorer 경유만 미검증 |

최종 ZIP: autofrog-setup-kit-20261016.zip — 589,958,454 bytes. 샌드박스·예약 작업 정리 확인, 커밋·푸시 없음.

이전 기록: [3회차 첫 실행·캡처 결함](20261016-r3-npx/summary.md) · [2회차](20261016-1038-r2/summary.md) · [1회차](20261016-1030-r1b/summary.md) · [최초 하네스 실패](20261016-1028-r1/summary.md)

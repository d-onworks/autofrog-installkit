1. `ssh -o ConnectTimeout=10 winhome`에서 `preflight.ps1`로 오토프로그 활성 세션을 확인한다.
2. 이 폴더 ps1들과 검증할 ZIP을 `C:\AutoFrogE2E`로 복사한다(키트 수정 시에만 build.py 재빌드).
3. `powershell -NoProfile -ExecutionPolicy Bypass -File C:\AutoFrogE2E\launch-host.ps1 -RunId <회차>`로 예약 작업 실행(SSH 종료 후 유지).
4. `current-run.txt` 갱신 후 `python3 ./e2e/fetch-status.py`로 1~2분 간격 확인; S1→VM 정리→S2, 시나리오당 최대 45분.
5. `<회차>/S*/out/S*`와 host/cleanup JSON을 `results/<회차>/`에 회수, PNG 직접 확인·summary.md 저장 후 제어부 예약 작업까지 정리한다.

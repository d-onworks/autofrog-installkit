오토프로그 바이브코딩 설치 키트 (윈도우 10/11 64비트)

설치: 키보드 Win+R → 아래 1번 한 줄을 붙여 넣고 Enter (안내: https://autofrog.kr/kit)

 1번  powershell -ExecutionPolicy Bypass -c "irm https://autofrog.kr/kit.ps1 | iex"

 1번이 막히면 2번 — 백신이 "트로이 목마"로 잡거나 "액세스가 거부되었습니다"로 끝날 때

 2번  powershell -NoProfile -c "irm https://autofrog.kr/kit.ps1 -OutFile $env:TEMP\af.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File $env:TEMP\af.ps1"

 둘 다 막히면 zip: 이 zip 을 마우스 오른쪽 → [압축 풀기] → 풀린 폴더의 [1-install.bat] 더블클릭
   - 파란 "Windows의 PC 보호" 창이 뜨면 [추가 정보] → [실행]
   - "스마트 앱 컨트롤이 차단했습니다" 창이 뜨면 클로드나 코덱스 앱에 "스마트 앱 컨트롤 꺼 줘"라고 하세요
     (한 번 끄면 윈도우를 새로 설치하기 전에는 다시 켤 수 없습니다)

- "스마트 앱 컨트롤을 끌까요?" 라고 물으면 Enter → 관리자 확인 창 [예]. 켜져 있으면 Git 이 막혀 클로드 코드를 못 씁니다.
- 5~15분 뒤 버전 표가 전부 [ OK ] 면 성공. 이어서 로그인할지 묻습니다.
- 나중에 로그인: 바탕화면 [오토프로그 로그인] 아이콘 더블클릭
- 바로가기 명령: cx = 코덱스, cc = 클로드를 확인 없이 바로 실행(연습 폴더에서만)
- 설치 중에 창을 닫았으면 같은 방법으로 다시 실행하세요. 이미 깔린 것은 건너뜁니다.

관리자 권한 없이 내 계정 폴더에만 설치합니다. 기록 파일: 사용자 폴더\autofrog-kit-logs

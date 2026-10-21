오토프로그 바이브코딩 설치 키트 (윈도우 10/11 64비트)

이 폴더는 한 줄 설치가 내려받아 쓰는 스크립트입니다. 직접 실행할 파일은 없습니다.

설치: 키보드 Win+R → 아래 한 줄을 붙여 넣고 Enter (안내: https://autofrog.kr/kit)
  powershell -ExecutionPolicy Bypass -c "irm https://autofrog.kr/kit.ps1 | iex"

- 5~15분 뒤 버전 표가 전부 [ OK ] 면 성공. 이어서 로그인할지 묻습니다.
- 나중에 로그인: 바탕화면 [오토프로그 로그인] 아이콘 더블클릭
- 바로가기 명령: cx = 코덱스, cc = 클로드를 확인 없이 바로 실행(연습 폴더에서만)

왜 zip·.bat 이 아닌가: 새 PC 는 스마트 앱 컨트롤이 켜져, 브라우저로 받아 푼 .bat 을 막습니다.
관리자 권한 없이 내 계정 폴더에만 설치합니다. 기록 파일: 사용자 폴더\autofrog-kit-logs

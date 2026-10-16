# autofrog-installkit — 윈도우 원클릭 설치 키트

오토프로그 바이브 코딩 수업용. zip 을 풀고 `1-install.bat` 하나만 누르면
Git → Node.js 24 → GitHub CLI · Supabase CLI → VS Code(+확장) → Vercel CLI → 클로드 코드 → 코덱스 까지
관리자 권한 없이 내 계정 폴더에 설치하고, 새 PowerShell 창에서 바로 쓰이도록 PATH·실행 정책까지 맞춘다.
로그인만 사람이 직접 한다(`2-login.bat` 또는 PowerShell 에서 한 줄씩).

| 폴더 | 내용 |
|---|---|
| `kit/` | 수강생에게 가는 파일(bat 2개 · README.txt · scripts/*.ps1) |
| `build.py` | 최신 안정판을 공식 배포처에서 받아(체크섬 확인) `dist/autofrog-setup-kit-YYYYMMDD.zip` 생성 |
| `manual/` | A4 한 장 매뉴얼(HTML → PDF) |
| `e2e/` | 집 윈도우 PC 윈도우 샌드박스 E2E 하네스 · `results/*/summary.md` |

- 빌드: `python3 build.py` (클로드 코드는 재배포 불가라 zip 에 넣지 않고 설치 때 공식 서버에서 받는다)
- 배포: zip·매뉴얼 PDF 는 구글 드라이브(ceo@d-onworks.com 「오토프로그 수업자료」)에 같은 파일 ID 로 덮어써 링크를 유지한다
- E2E: `e2e/README.md` — 샌드박스는 오토프로그 계정이 로그인돼 있어야 뜬다
- 2026-10-16 3회차 E2E: 기본 계정·관리자 아닌 한글 계정 모두 설치 + npx/npm/로그인 명령 9개 통과

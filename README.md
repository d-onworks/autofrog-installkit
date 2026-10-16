# autofrog-installkit — 원클릭 설치 패키지 (윈도우)

**코딩을 처음 하는 분이 클로드 코드(Claude Code)나 코덱스(Codex)를 쓰기 위해 필요한 프로그램을 한 번에 설치하는 패키지입니다.**

압축을 풀고 `1-install.bat` 하나만 더블클릭하면 아래 프로그램의 **최신 안정판을 공식 배포처에서 내려받아** 순서대로 깔고,
마지막에 VS Code 까지 열어 줍니다. 새 PowerShell 창이나 VS Code 터미널에서 `claude` · `codex` 명령이 바로 실행됩니다.
관리자 권한 없이 내 계정 폴더에만 설치합니다. 로그인만 직접 하면 됩니다.

| 순서 | 설치되는 것 | 용도 |
|---|---|---|
| 1 | Git | 만든 것을 저장하고 되돌리기 |
| 2 | Node.js 24 (npm · npx 포함) | 웹 프로젝트를 돌리는 엔진 |
| 3 | GitHub CLI · Supabase CLI | 깃허브 · 데이터베이스를 명령으로 다루기 |
| 4 | VS Code (+한국어 · 코덱스 · 클로드 확장) | 코드를 보고 고치는 편집기 |
| 5 | Vercel CLI | 만든 것을 인터넷에 올리기 |
| 6 | 클로드 코드 | AI 코딩 도구 (설치할 때 공식 서버에서 받음) |
| 7 | 코덱스 | AI 코딩 도구 (그냥 `codex` 만 쳐도 확인 없이 바로 실행되게 설정) |

윈도우 10 · 11 (64비트) 대상입니다.

## 쓰는 법

1. **[설치 파일 받기 (autofrog-setup-kit.zip)](https://github.com/d-onworks/autofrog-installkit/releases/latest/download/autofrog-setup-kit.zip)** — 50KB 남짓
   - 이 페이지의 초록색 `Code` → `Download ZIP` 으로 받은 것은 쓰지 마세요(윈도우용 글자 형식으로 묶이지 않아 한글이 깨집니다)
2. 받은 zip 을 마우스 오른쪽 클릭 → **모두 압축 풀기** (zip 안에서 바로 실행하지 마세요)
3. **`1-install.bat`** 더블클릭 → 기다리기 (인터넷 속도에 따라 5~15분, 인터넷 연결 필요)
   - 파란 "Windows의 PC 보호" 창이 뜨면 **추가 정보 → 실행**
   - 끝나면 버전 표가 나오고 VS Code 가 열립니다. **10줄 모두 `[ OK ]`** 면 성공
4. **PowerShell 창에서 한 줄씩 로그인** — `claude`(또는 `codex`) · `gh auth login` · `vercel login` · `supabase login`
   - `2-login.bat` 을 더블클릭해도 같은 순서로 물어봅니다
5. VS Code 에서 작업 폴더를 열고 터미널에 `cx`(코덱스) 또는 `cc`(클로드) — 확인 창 없이 바로 시작합니다.
   확인 없이 파일을 고치므로 연습 폴더에서 쓰세요.

**에러가 나면** — PC마다 보안 설정이 달라 에러가 날 수 있습니다. 에러 화면을 그대로 캡처해(`Win`+`Shift`+`S`)
클로드 대화창에 붙여 넣고 "이거 해결해 줘" 하면 대부분 해결됩니다. 기록 파일은 `C:\Users\내 이름\autofrog-kit-logs` 에 남습니다.

A4 한 장 매뉴얼: [`manual/`](manual/)

## 왜 만들었나

수업에서 수강생 PC마다 설치가 다르게 깨져 설치에만 3시간이 걸렸습니다.
`claude` 명령을 못 찾는 문제(VS Code 가 옛 PATH 를 계속 씀), npm 으로 깐 명령이 실행 정책에 막히는 문제,
Supabase CLI 를 npm 으로 깔다 실패하는 문제를 한 번에 막도록 짰습니다.

- 설치 후 PATH 를 사용자 환경변수에 직접 등록하고 윈도우에 변경 신호를 보냅니다
- 켜져 있는 VS Code 를 닫게 한 뒤, 마지막에 새 PATH 를 물려받은 VS Code 를 직접 띄웁니다
- PowerShell 실행 정책을 내 계정에 한해 `RemoteSigned` 로 맞춥니다(회사 정책으로 고정돼 있으면 건드리지 않음)
- 여러 번 실행해도 안전합니다(이미 설치된 것은 건너뜀)

## 직접 zip 만들기

```bash
python3 build.py --online   # → dist/autofrog-setup-kit.zip            온라인판(공개 배포용, 스크립트만)
python3 build.py            # → dist/autofrog-setup-kit-YYYYMMDD.zip   설치 파일 동봉판(수업용, 약 590MB)
```

- **온라인판**: 설치하는 그 자리에서 `kit/scripts/online.ps1` 이 최신판을 받습니다. Node.js · GitHub CLI · Supabase CLI · 코덱스 · VS Code 는 공식 체크섬(SHA-256), Git 은 디지털 서명으로 확인합니다. 최신 버전은 GitHub API 대신 `releases/latest` 주소로 알아내 교실 여러 대가 같은 인터넷을 써도 횟수 제한에 걸리지 않습니다.
- **동봉판**: `build.py` 가 같은 파일을 미리 받아 체크섬을 확인한 뒤 `payload/` 에 넣습니다. 설치 중 다운로드가 줄어 수업 현장용입니다.
- 이 저장소에는 설치 파일이 들어 있지 않습니다. 클로드 코드는 두 판 모두 설치할 때 공식 서버(downloads.claude.ai)에서 받습니다.

## 검증

윈도우 샌드박스(매번 새로 설치한 PC와 같은 상태)에서 E2E 로 확인했습니다 — [`e2e/results/summary.md`](e2e/results/summary.md)

- 기본 계정 · **관리자 아닌 + 한글 이름 계정** 둘 다 설치 성공(약 2분), 다시 실행 시 전부 건너뜀
- 새 PowerShell 창(실행 정책 우회 없음)에서 `npx create-next-app` · `npm view` · `gh/vercel/supabase login` · `claude` · `codex` 모두 정상

검증하지 못한 것: 실제 로그인(사람이 브라우저로 승인), 회사 보안 정책이 걸린 PC.

## 폴더

| 폴더 | 내용 |
|---|---|
| `kit/` | 사용자에게 가는 파일 — `1-install.bat` · `2-login.bat` · `README.txt` · `scripts/*.ps1` |
| `build.py` | 최신판 내려받기 + zip 만들기 |
| `manual/` | A4 한 장 매뉴얼 (HTML · PDF) |
| `e2e/` | 윈도우 샌드박스 E2E 테스트 도구와 회차별 결과 요약 |

---

만든 곳: [오토프로그](https://autofrog.kr) · (주)디온웍스 — 바이브 코딩 수업용으로 만들어 공개합니다.

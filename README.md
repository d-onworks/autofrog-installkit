# autofrog-installkit — 원클릭 설치 패키지 (윈도우 · 맥)

**코딩을 처음 하는 분이 클로드 코드(Claude Code)나 코덱스(Codex)를 쓰기 위해 필요한 프로그램을 한 번에 설치하는 패키지입니다.**

**PowerShell 한 줄**을 붙여 넣으면 아래 프로그램의 **최신 안정판을 공식 배포처에서 내려받아** 순서대로 깔고,
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

## 쓰는 법 (윈도우)

1. 키보드 `Win` + `R` → 아래 한 줄을 붙여 넣고 Enter (안내 페이지: [autofrog.kr/kit](https://autofrog.kr/kit))

   ```text
   powershell -ExecutionPolicy Bypass -c "irm https://autofrog.kr/kit.ps1 | iex"
   ```

   - **1번이 막히면 2번** — 어떤 PC 는 백신(Defender 포함)이 `irm … | iex` 한 줄을 "트로이 목마"로 보고 막습니다
     (파란 창이 "액세스가 거부되었습니다"로 끝남). 2번은 받은 스크립트를 파일로 저장한 뒤 `-File` 로 실행해
     같은 설치를 합니다(2026-10-22 대표 노트북에서 확인). Win+R 에도, 이미 열린 PowerShell 창에도 그대로 붙여 넣을 수 있습니다.

     ```text
     powershell -NoProfile -c "irm https://autofrog.kr/kit.ps1 -OutFile $env:TEMP\af.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File $env:TEMP\af.ps1"
     ```

   - `autofrog.kr/kit.ps1` 은 이 저장소 최신 릴리즈의 `install.ps1` 로 넘겨줍니다. 같은 것을 직접 쓰려면
     `irm https://github.com/d-onworks/autofrog-installkit/releases/latest/download/install.ps1 | iex`
2. 기다리기 (인터넷 속도에 따라 5~15분). 끝나면 버전 표가 나오고 VS Code 가 열립니다. **10줄 모두 `[ OK ]`** 면 성공
3. "이어서 로그인할까요?" → Enter — 코덱스 · 클로드 · GitHub · Vercel · Supabase 순서로 물어봅니다
   - 나중에 하려면 바탕화면 **[오토프로그 로그인]** 아이콘을 두 번 누르면 남은 것만 다시 묻습니다
4. VS Code 에서 작업 폴더를 열고 터미널에 `cx`(코덱스) 또는 `cc`(클로드) — 확인 창 없이 바로 시작합니다.
   확인 없이 파일을 고치므로 연습 폴더에서 쓰세요.

**에러가 나면** — PC마다 보안 설정이 달라 에러가 날 수 있습니다. 에러 화면을 그대로 캡처해(`Win`+`Shift`+`S`)
클로드 대화창에 붙여 넣고 "이거 해결해 줘" 하면 대부분 해결됩니다. 기록 파일은 `C:\Users\내 이름\autofrog-kit-logs` 에 남습니다.

### 왜 zip 이 아니라 한 줄인가 (2026-10-21)

예전에는 zip 을 받아 `1-install.bat` 을 더블클릭했습니다. 그런데 새로 산 PC · 포맷한 PC 는 윈도우 11 의
**스마트 앱 컨트롤**이 몇 주 지켜본 뒤 저절로 켜지고, 켜지면 **브라우저로 받은 파일(인터넷 표시가 붙은 파일)** 중
`.bat` 을 더블클릭할 때 막습니다. 끄는 것 말고는 "그래도 실행" 버튼이 없습니다.

스마트 앱 컨트롤이 켜진 실제 PC 에서 시험한 결과(2026-10-21):

| 띄운 것 | 결과 |
|---|---|
| 인터넷 표시가 **없는** `.bat` 더블클릭 | 실행됨 |
| 인터넷 표시가 **있는** `.bat` 더블클릭 | **막힘** (CodeIntegrity 3033) |
| `.ps1` 을 `powershell -File` 로 실행 (표시 있음·없음 둘 다) | 실행됨 (FullLanguage) |
| 내 PC 에서 만든 바로가기 → PowerShell | 실행됨 |

PowerShell 이 직접 받은 파일에는 인터넷 표시가 붙지 않습니다. 그래서 한 줄 설치는 설정을 하나도 바꾸지 않고
스마트 앱 컨트롤을 지나갑니다. zip(`autofrog-setup-kit.zip`)은 한 줄 설치가 안에서 받아 쓰는 꾸러미라 같은 릴리즈에 계속 올립니다.
`2-login.bat` 은 없앴습니다(로그인은 바탕화면 [오토프로그 로그인] 아이콘).

### 스마트 앱 컨트롤이 켜진 PC — 설치가 먼저 끌지 묻는다 (2026-10-22)

스마트 앱 컨트롤이 **켜짐(강제)** 이면 Git 의 서명 없는 부품이 막힌다(샌드박스 실측, 보안 기록 3077 · 정책 `{0283ac0f-…}`).
Git 2.56 은 `ucrt64\bin\zlib1.dll` 등이 막혀 git 자체가 "잘못된 이미지" 창을 띄우고, 2.55 는 git 은 돌지만 클로드 코드가 쓰는
`usr\bin\bash.exe` 가 막힌다 — 버전으로는 못 피한다. 그래서 `setup.ps1` 이 0단계 뒤에 상태를 보고(`HKLM\...\CI\Policy`
`VerifiedAndReputablePolicyState` = 1) **"지금 끌까요?"** 를 묻는다. Enter → 관리자 확인 [예] → 값 0 + `CiTool --refresh --json`(재부팅 없이 바로 꺼짐 · `--json` 이 없으면 끝에서 Enter 를 기다려 멈춘다)
→ 그대로 설치를 이어 간다. 거절하거나 `-Auto` 면 끄는 법을 보여 주고 코드 3 으로 끝난다. 한 번 끄면 윈도우를 새로 깔기 전엔 다시 못 켠다.
그래도 막힌 채로 설치되면 Git 설치 프로그램이 오류 창 뒤에서 끝나지 않으므로, 10분이 지나면 끊고 원인을 알린다.

### 한 줄이 백신에 막히면 — zip 설치 (2026-10-22)

1번·2번 한 줄이 모두 막히는 PC 를 위해 zip 에 `1-install.bat` 을 다시 넣었습니다. 한 줄 설치와 같은 `setup.ps1 -OneLiner` 를 부릅니다.

1. [autofrog.kr/kit.zip](https://autofrog.kr/kit.zip) 받기 (= 최신 릴리즈의 `autofrog-setup-kit.zip`)
2. 마우스 오른쪽 → [압축 풀기] → 풀린 폴더의 `1-install.bat` 더블클릭

스마트 앱 컨트롤이 켜진 PC 는 이 `.bat` 을 막으니 한 줄 설치로 하세요 — 두 방법이 서로의 빈자리를 메웁니다.
그래도 스마트 앱 컨트롤 때문에 막히면 클로드·코덱스 앱에 "스마트 앱 컨트롤 꺼 줘"라고 하면 됩니다(한 번 끄면 윈도우 재설치 전에는 다시 못 켭니다).

A4 한 장 매뉴얼: [`manual/`](manual/)

## 맥(macOS)판

`kit-mac/` — 같은 8가지를 맥에 설치합니다. macOS 13.5 이상, 애플 실리콘·인텔.

1. ⌘+Space → "터미널" → 아래 한 줄을 붙여 넣고 Enter (안내 페이지: [autofrog.kr/kit](https://autofrog.kr/kit#mac))

   ```text
   curl -fsSL https://autofrog.kr/kit.sh | bash
   ```

   - `autofrog.kr/kit.sh` 는 최신 릴리즈의 `install.sh` 로 넘겨줍니다
   - Git 이 없으면 맥이 "명령어 라인 개발자 도구" 설치 창을 띄웁니다 → **설치 → 동의**
2. 끝나면 버전 표 10줄이 `[ OK ]` 이고 VS Code 가 열립니다. "이어서 로그인할까요?" → Enter. 나중에는 터미널에 `autofrog-login`.

브라우저로 받은 zip 의 `.command` 는 격리 표시 때문에 "열지 않음" 창에 막히고, 다운로드 폴더 접근 허용 창도 떴습니다.
`curl` 로 받은 파일에는 그 표시가 없어 두 창 모두 뜨지 않습니다(2026-10-21 전환).

- 내 계정 폴더에만 설치합니다(`~/.autofrog-kit` · `~/.npm-global` · `~/Applications/Visual Studio Code.app`). 애플 개발자 도구만 맥이 직접 설치합니다.
- 클로드 코드 · 코덱스는 각 회사의 공식 설치 스크립트(체크섬 확인 포함)로 깔고, 나머지는 공식 체크섬(VS Code 는 마이크로소프트 서명까지) 확인 후 설치합니다.
- PATH 와 바로가기는 `~/.zprofile` · `~/.zshrc` 의 표시된 블록 하나에만 씁니다. `cc` 는 맥의 C 컴파일러 이름이라 **파일이 아니라 별칭(alias)** 으로 넣어, 터미널에서 칠 때만 클로드가 열리고 npm 의 컴파일은 그대로 둡니다.
- zip 만들기: `python3 build.py --mac` → `dist/autofrog-setup-kit-mac.zip` + `dist/install.sh` (릴리즈에 둘 다 올린다)
- A4 매뉴얼: [`manual/mac.html`](manual/mac.html) · PDF

검증(UTM 맥 가상머신, macOS 26.5 · 애플 실리콘): 개발자 도구 없는 관리자 계정 · 아무것도 없는 **관리자 아닌 계정** 모두 10줄 `[ OK ]`,
다시 실행 시 전부 건너뜀, 새 터미널에서 `npx create-next-app` → `npm run build` 성공 —
[`e2e-mac/results/summary.md`](e2e-mac/results/summary.md)

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
python3 build.py --online   # → dist/autofrog-setup-kit.zip + dist/install.ps1  온라인판 + 한 줄 설치(공개 배포용, 릴리즈에 둘 다 올린다)
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
| `bootstrap/install.ps1` · `install.sh` | 한 줄 설치(윈도우 · 맥) — 릴리즈의 zip 을 받아 `%LOCALAPPDATA%\AutoFrogKit\kit` 에 풀고 설치·로그인까지 이어 준다 |
| `kit/` | 한 줄 설치가 받아 쓰는 윈도우 스크립트 — `README.txt` · `scripts/*.ps1` |
| `kit-mac/` | 한 줄 설치가 받아 쓰는 맥 스크립트 — `README.txt` · `scripts/*.sh` (맥 기본 bash 3.2) |
| `build.py` | 최신판 내려받기 + zip 만들기 |
| `manual/` | A4 한 장 매뉴얼 (HTML · PDF) |
| `e2e/` | 윈도우 샌드박스 E2E 테스트 도구와 회차별 결과 요약 |
| `e2e-mac/` | 맥 가상머신 E2E 결과 요약 |

---

만든 곳: [오토프로그](https://autofrog.kr) · (주)디온웍스 — 바이브 코딩 수업용으로 만들어 공개합니다.

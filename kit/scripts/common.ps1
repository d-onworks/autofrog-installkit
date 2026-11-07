# 오토프로그 설치 키트 — 공통 함수 (setup.ps1 · login.ps1 가 같이 쓴다)
# PowerShell 5.1 호환. 이 파일은 UTF-8(BOM) 으로 저장해야 한글이 안 깨진다.

$script:KitHome = Join-Path $env:LOCALAPPDATA 'AutoFrogKit'
$script:KitBin  = Join-Path $script:KitHome 'bin'
$script:LogDir  = Join-Path $env:USERPROFILE 'autofrog-kit-logs'

function Write-Title([string]$text) {
    Write-Host ''
    Write-Host ('=' * 60) -ForegroundColor DarkGreen
    Write-Host "  $text" -ForegroundColor Green
    Write-Host ('=' * 60) -ForegroundColor DarkGreen
}
function Write-Step([string]$text) { Write-Host "  > $text" -ForegroundColor Cyan }
function Write-Ok([string]$text)   { Write-Host "  [완료] $text" -ForegroundColor Green }
function Write-Skip([string]$text) { Write-Host "  [건너뜀] $text" -ForegroundColor DarkGray }
function Write-Warn2([string]$text){ Write-Host "  [주의] $text" -ForegroundColor Yellow }
function Write-Fail([string]$text) { Write-Host "  [실패] $text" -ForegroundColor Red }

# ── 환경변수(PATH) ───────────────────────────────────────────
# 레지스트리를 직접 다룬다. [Environment]::SetEnvironmentVariable 은 PS 5.1 에서
# REG_SZ 로 써서 %USERPROFILE% 같은 항목이 안 풀리는 일이 생긴다.

function Get-UserPathRaw {
    $key = Get-Item 'HKCU:\Environment'
    return [string]$key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
}

function Send-EnvChanged {
    # 탐색기에 "환경변수 바뀜" 신호 → 이후 탐색기에서 여는 프로그램이 새 PATH 를 받는다
    if (-not ('AutoFrog.NativeEnv' -as [type])) {
        Add-Type -Namespace AutoFrog -Name NativeEnv -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
    }
    $r = [UIntPtr]::Zero
    [void][AutoFrog.NativeEnv]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$r)
}

function Test-PathListHas([string]$list, [string]$dir) {
    $want = [Environment]::ExpandEnvironmentVariables($dir).TrimEnd('\')
    foreach ($p in ($list -split ';')) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if ([Environment]::ExpandEnvironmentVariables($p).TrimEnd('\') -ieq $want) { return $true }
    }
    return $false
}

function Add-UserPath([string[]]$dirs) {
    # 사용자 PATH 앞쪽에 붙인다(중복이면 그대로). 시스템 PATH 는 건드리지 않는다.
    $raw = Get-UserPathRaw
    $add = @()
    foreach ($d in $dirs) {
        if (-not (Test-PathListHas $raw $d) -and -not ($add -contains $d)) { $add += $d }
    }
    if ($add.Count -eq 0) { return $false }
    $parts = @($add) + @(($raw -split ';') | Where-Object { $_ -ne '' })
    Set-ItemProperty -Path 'HKCU:\Environment' -Name Path -Value ($parts -join ';') -Type ExpandString
    Send-EnvChanged
    return $true
}

function Set-UserEnv([string]$name, [string]$value) {
    Set-ItemProperty -Path 'HKCU:\Environment' -Name $name -Value $value -Type String
    Send-EnvChanged
}

function Update-SessionPath {
    # 지금 창(이 프로세스)의 PATH 를 레지스트리 기준으로 다시 만든다
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::ExpandEnvironmentVariables((Get-UserPathRaw))
    $env:Path = (@($u, $m) | Where-Object { $_ }) -join ';'
}

# ── 기타 ──────────────────────────────────────────────────
function Find-Exe([string]$name) {
    $c = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return $c.Source }
    return $null
}

function Invoke-Native([string]$exe, [string[]]$argList) {
    # 외부 프로그램 실행 → 출력·종료코드. 표준오류도 같이 받는다(경고 때문에 멈추지 않게).
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # 키보드 입력은 빈 것으로 넘긴다 — 외부 프로그램(tar·code.cmd 등)이 입력을 기다려 Enter 를 쳐야 넘어가는 일이 없게(2026-11-07)
        $out = $null | & $exe @argList 2>&1 | ForEach-Object { "$_" }
        return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
    } finally { $ErrorActionPreference = $old }
}

# 빠른 편집(QuickEdit) 끄기 — 옛 명령창(conhost)은 창을 한 번 클릭하면 「선택」 상태가 돼 출력이 멈추고,
# 설치도 같이 멈춘다(Enter 를 쳐야 풀림). 2026-10-28 시험 하네스에서 실측, 2026-11-07 대표 촬영 중 VS Code 단계에서 재발.
# 설치 동안만 끄고 끝나면 원래대로 돌린다(설치 뒤엔 마우스로 글자 복사가 되게). 실패해도 설치는 계속한다.
$script:OrigConsoleMode = $null
function Disable-QuickEdit {
    if ($null -ne $script:OrigConsoleMode) { return }
    try {
        if (-not ('AutoFrog.AfConsole' -as [type])) {
            Add-Type -Namespace AutoFrog -Name AfConsole -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);
'@
        }
        $h = [AutoFrog.AfConsole]::GetStdHandle(-10)
        [uint32]$m = 0
        if (-not [AutoFrog.AfConsole]::GetConsoleMode($h, [ref]$m)) { return }
        $n = ([int64]$m -band 0xFFFFFFBF) -bor 0x80   # QUICK_EDIT(0x40) 끄고 EXTENDED_FLAGS(0x80) 켬
        if ([AutoFrog.AfConsole]::SetConsoleMode($h, [uint32]$n)) { $script:OrigConsoleMode = $m }
    } catch {}
}
function Restore-QuickEdit {
    if ($null -eq $script:OrigConsoleMode) { return }
    try { [void][AutoFrog.AfConsole]::SetConsoleMode([AutoFrog.AfConsole]::GetStdHandle(-10), [uint32]$script:OrigConsoleMode) } catch {}
    $script:OrigConsoleMode = $null
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

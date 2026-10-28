# 실행 방식 시험(2026-10-28) — PowerShell 창을 띄우거나(Launch) 이미 뜬 창에 붙어서(Attach)
# 화면 글자를 파일로 내보내고, 사람이 치듯 명령 한 줄과 키트의 질문 답(로그인 n, 마지막 Enter)을 키 입력으로 넣는다.
param([ValidateSet('Launch','Attach')][string]$Mode='Launch',[int]$TargetPid=0,[string]$Out,[int]$TimeoutSec=2400)
$ErrorActionPreference='Continue'
New-Item -ItemType Directory -Force $Out | Out-Null
$utf8=New-Object Text.UTF8Encoding $false
$sw=[Diagnostics.Stopwatch]::StartNew()
function Log([string]$m) { [IO.File]::AppendAllText((Join-Path $Out 'bridge.log'),((Get-Date).ToString('HH:mm:ss.fff')+' '+$m+"`r`n"),$utf8) }
function Ev([string]$Name,$Extra=@{}) {
  $o=[ordered]@{ms=[int]$sw.Elapsed.TotalMilliseconds;time=(Get-Date).ToString('o');ev=$Name}; foreach($k in $Extra.Keys){$o[$k]=$Extra[$k]}
  [IO.File]::AppendAllText((Join-Path $Out 'events.jsonl'),(($o|ConvertTo-Json -Compress -Depth 5)+"`r`n"),$utf8); Log $Name
}
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text; using System.Collections.Generic;
public static class MB {
  [DllImport("kernel32.dll")] public static extern bool FreeConsole();
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool AttachConsole(uint pid);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern IntPtr CreateFileW(string n, uint a, uint s, IntPtr sa, uint d, uint f, IntPtr t);
  [StructLayout(LayoutKind.Sequential)] public struct COORD { public short X; public short Y; }
  [StructLayout(LayoutKind.Sequential)] public struct SMALL_RECT { public short L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct CSBI { public COORD Size; public COORD Cursor; public ushort Attr; public SMALL_RECT Win; public COORD Max; }
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleScreenBufferInfo(IntPtr h, out CSBI i);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool ReadConsoleOutputCharacterW(IntPtr h, StringBuilder sb, uint len, COORD c, out uint read);
  [StructLayout(LayoutKind.Explicit, CharSet=CharSet.Unicode)] public struct IR {
    [FieldOffset(0)] public ushort Type; [FieldOffset(4)] public int Down; [FieldOffset(8)] public ushort Rep;
    [FieldOffset(10)] public ushort Vk; [FieldOffset(12)] public ushort Scan; [FieldOffset(14)] public char Ch; [FieldOffset(16)] public uint Ctrl; }
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool WriteConsoleInputW(IntPtr h, IR[] r, uint n, out uint w);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern short VkKeyScanW(char c);
  [DllImport("user32.dll")] public static extern uint MapVirtualKeyW(uint code, uint type);
  [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m);
  [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);
  // 빠른 편집(QuickEdit) 끄기 — 창을 누가 클릭해 「선택」 상태가 되면 출력이 멈춰 설치가 멈춘 것처럼 보인다(2026-10-28 실측)
  public static uint NoQuickEdit() { uint m; if (!GetConsoleMode(In, out m)) return 0xFFFFFFFF; uint n = (m & ~0x40u) | 0x80u; SetConsoleMode(In, n); uint a; GetConsoleMode(In, out a); return a; }
  public static IntPtr Out, In;
  public static bool Attach(uint pid) {
    FreeConsole();
    if (!AttachConsole(pid)) return false;
    Out = CreateFileW("CONOUT$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
    In  = CreateFileW("CONIN$",  0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
    return Out != new IntPtr(-1) && In != new IntPtr(-1);
  }
  public static string Dump(int maxLines) {
    CSBI i; if (!GetConsoleScreenBufferInfo(Out, out i)) return null;
    int w = i.Size.X; int end = Math.Max(i.Cursor.Y, (int)i.Win.B); int start = Math.Max(0, end - maxLines + 1);
    var sb = new StringBuilder();
    for (int y = start; y <= end; y++) {
      var line = new StringBuilder(w + 1); uint r; COORD c; c.X = 0; c.Y = (short)y;
      ReadConsoleOutputCharacterW(Out, line, (uint)w, c, out r);
      // 버퍼가 꽉 차면 끝에 널이 없어 뒤에 쓰레기 글자가 붙는다 — 실제로 읽은 글자 수(r)만 쓴다
      string s = line.ToString(); if (s.Length > (int)r) s = s.Substring(0, (int)r);
      sb.AppendLine(s.TrimEnd());
    }
    return sb.ToString();
  }
  public static uint Send(string s) {
    var list = new List<IR>();
    foreach (char c0 in s) {
      if (c0 == '\r') continue;
      char ch = c0 == '\n' ? '\r' : c0;
      ushort vk = ch == '\r' ? (ushort)0x0D : (ushort)(VkKeyScanW(ch) & 0xFF);
      ushort sc = (ushort)MapVirtualKeyW(vk, 0);
      for (int d = 1; d >= 0; d--) { IR r = new IR(); r.Type = 1; r.Down = d; r.Rep = 1; r.Vk = vk; r.Scan = sc; r.Ch = ch; list.Add(r); }
    }
    uint w; WriteConsoleInputW(In, list.ToArray(), (uint)list.Count, out w); return w;
  }
}
'@
$id=[Security.Principal.WindowsIdentity]::GetCurrent()
$elev=(New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
[IO.File]::WriteAllText((Join-Path $Out 'identity.json'),(([ordered]@{mode=$Mode;user=$id.Name;elevated=$elev;profile=$env:USERPROFILE;temp=$env:TEMP;localappdata=$env:LOCALAPPDATA}|ConvertTo-Json)),$utf8)
$typeFile=Join-Path $Out 'type.txt'
$typeText=if(Test-Path $typeFile){ ([IO.File]::ReadAllText($typeFile)).Trim() } else { '' }
if ($Mode -eq 'Launch') {
  # 사람이 시작 메뉴에서 연 창처럼 — 하네스의 Bypass 정책이 새 창으로 새지 않게 지운다.
  Remove-Item Env:\PSExecutionPolicyPreference -ErrorAction SilentlyContinue
  $p=Start-Process "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -PassThru -WindowStyle Normal -WorkingDirectory $env:USERPROFILE
  $TargetPid=$p.Id
  Ev 'launched' @{pid=$TargetPid}
}
$target=Get-Process -Id $TargetPid -ErrorAction SilentlyContinue
if ($target) { $null=$target.Handle }
$ok=$false
for ($i=0; $i -lt 60 -and -not $ok; $i++) { $ok=[MB]::Attach([uint32]$TargetPid); if (-not $ok) { Start-Sleep -Milliseconds 100 } }
Ev 'attach' @{pid=$TargetPid;ok=$ok;err=[Runtime.InteropServices.Marshal]::GetLastWin32Error()}
if ($ok) { $qm=[MB]::NoQuickEdit(); Ev 'quickedit-off' @{mode=$qm} }
function Code-Count { @(Get-Process Code -ErrorAction SilentlyContinue).Count }
function Burst([string]$Tag,[int]$Sec) {
  # 화면 찍기(m-shots)를 잠깐 0.5초 간격으로 — 질문 시점 캡처용. 부모 out 폴더의 tag/burst 파일을 쓴다
  try { $p=Split-Path $Out -Parent; [IO.File]::WriteAllText((Join-Path $p 'tag.txt'),$Tag); [IO.File]::WriteAllText((Join-Path $p 'burst.txt'),[string](Get-Date).AddSeconds($Sec).Ticks) } catch {}
}
$lastCode=-1
$typed=$false; $ansLogin=$false; $ansFinal=$false; $ansCode=$false; $ansSac=$false; $last=''; $promptBack=$false
$deadline=(Get-Date).AddSeconds($TimeoutSec)
function Save-Snap([string]$Name,[string]$Text) { if ($Text) { [IO.File]::WriteAllText((Join-Path $Out $Name),$Text,$utf8) } }
while ($ok -and $target -and -not $target.HasExited -and (Get-Date) -lt $deadline) {
  $t=[MB]::Dump(900)
  if ($null -ne $t -and $t -ne $last) { Save-Snap 'console.txt' $t; $last=$t }
  if ($null -eq $t) { $t='' }
  # 넓은 글자(한글)가 칸마다 두 번 읽히는 콘솔이 있어 겹친 글자를 접어서도 본다
  $n=[regex]::Replace($t,'([가-힣])\1','$1')
  $lines=@($t -split "`r?`n" | Where-Object { $_.Trim() })
  $tail=if ($lines.Count) { $lines[-1] } else { '' }
  $prompt=($tail.TrimEnd() -match '^PS [^>]*>$')
  if ($Mode -eq 'Launch' -and -not $typed -and $prompt) {
    Start-Sleep -Milliseconds 600
    $c=[MB]::Send($typeText+"`n"); $typed=$true; Ev 'typed' @{text=$typeText;events=$c}
  }
  if (-not $ansCode -and $n -match 'VS Code 에서 작업을 저장한 뒤') { Start-Sleep 1; [void][MB]::Send("`n"); $ansCode=$true; Ev 'answer-vscode-running' }
  if (-not $ansSac -and $n -match '지금 끌까요') { Save-Snap 'console-at-sac.txt' $t; Start-Sleep 1; [void][MB]::Send("n`n"); $ansSac=$true; Ev 'answer-sac-no' }
  $cc=Code-Count; if ($cc -ne $lastCode) { Ev 'code-procs' @{count=$cc}; $lastCode=$cc }
  if (-not $ansLogin -and $n -match '이어서 로그인할까요') { Save-Snap 'console-at-login-question.txt' $t; Burst 'loginq' 15; Ev 'login-question' @{codeCount=(Code-Count)}; Start-Sleep 6; Ev 'login-question-after-6s' @{codeCount=(Code-Count)}; [void][MB]::Send("n`n"); $ansLogin=$true; Ev 'answer-login-no' }
  if (-not $ansFinal -and $n -match 'Enter 를 누르면 (VS Code 를 열고 )?(창이 닫힙니다|끝납니다)') { Save-Snap 'console-at-final.txt' $t; Burst 'final' 15; Ev 'final-question' @{codeCount=(Code-Count);vscodePhrase=($n -match 'VS Code 를 열고 끝납니다')}; Start-Sleep 5; Ev 'final-before-enter' @{codeCount=(Code-Count)}; [void][MB]::Send("`n"); $ansFinal=$true; Ev 'answer-final-enter' }
  if ($ansFinal -and $prompt) {
    Burst 'after-enter' 20
    $d0=(Get-Date).AddSeconds(30); while ((Code-Count) -eq 0 -and (Get-Date) -lt $d0) { Start-Sleep -Milliseconds 300 }
    Ev 'after-enter-code' @{codeCount=(Code-Count)}; Start-Sleep 2
    $t2=[MB]::Dump(900); Save-Snap 'console-end.txt' $t2; $promptBack=$true; Ev 'prompt-back'; break }
  if ($sw.Elapsed.TotalSeconds -lt 20) { Start-Sleep -Milliseconds 150 } else { Start-Sleep -Milliseconds 1000 }
}
$exited=($target -and $target.HasExited)
$code=$null; if ($exited) { try { $code=$target.ExitCode } catch {} }
if ($last) { Save-Snap 'console-last.txt' $last }
Ev 'end' @{targetExited=$exited;exitCode=$code;promptBack=$promptBack;timeout=((Get-Date) -ge $deadline)}
[IO.File]::WriteAllText((Join-Path $Out 'bridge-done.json'),(([ordered]@{typed=$typed;answeredLogin=$ansLogin;answeredFinal=$ansFinal;promptBack=$promptBack;targetExited=$exited;exitCode=$code;sec=[math]::Round($sw.Elapsed.TotalSeconds,1)}|ConvertTo-Json)),$utf8)
[void][MB]::FreeConsole()

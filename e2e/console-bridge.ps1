# 로그인 마법사 콘솔에 붙어서 화면 글자를 파일로 내보내고, in\*.txt 로 들어온 글자를 키 입력으로 넣는다.
# 사람 대신 키보드를 누르는 역할만 한다 — 브라우저 승인은 바깥(맥)에서 사람이 하듯 처리한다.
param([int]$TargetPid,[string]$Out)
$ErrorActionPreference='Continue'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text; using System.Collections.Generic;
public static class CB {
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
      sb.AppendLine(line.ToString().TrimEnd());
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
$log=Join-Path $Out 'bridge.log'
$inDir=Join-Path $Out 'in'; New-Item -ItemType Directory -Force $inDir | Out-Null
$shots=Join-Path $Out 'screens'; New-Item -ItemType Directory -Force $shots | Out-Null
function Log([string]$m) { [IO.File]::AppendAllText($log, ((Get-Date).ToString('HH:mm:ss')+' '+$m+"`r`n"), (New-Object Text.UTF8Encoding $false)) }
function Shot([string]$Tag) {
  try {
    $r=[Windows.Forms.SystemInformation]::VirtualScreen
    $b=New-Object Drawing.Bitmap($r.Width,$r.Height); $g=[Drawing.Graphics]::FromImage($b)
    $g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size)
    $b.Save((Join-Path $shots ((Get-Date -Format 'HHmmss')+'_'+$Tag+'.png')),[Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $b.Dispose()
  } catch { Log ('shot error: '+$_.Exception.Message) }
}
$ok=[CB]::Attach([uint32]$TargetPid)
Log "attach pid=$TargetPid ok=$ok"
$target=Get-Process -Id $TargetPid -ErrorAction SilentlyContinue
while ($target -and -not $target.HasExited) {
  $t=[CB]::Dump(400)
  if ($null -ne $t) { [IO.File]::WriteAllText((Join-Path $Out 'console.txt'),$t,(New-Object Text.UTF8Encoding $false)) }
  foreach ($f in @(Get-ChildItem $inDir -Filter '*.txt' -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $s=[IO.File]::ReadAllText($f.FullName)
    $n=[CB]::Send($s)
    Log ("sent {0} events from {1}" -f $n,$f.Name)
    Rename-Item $f.FullName ($f.Name+'.sent') -Force
  }
  foreach ($q in @(Get-ChildItem $Out -Filter 'shot-*.req' -ErrorAction SilentlyContinue)) { Shot $q.BaseName; Remove-Item $q.FullName -Force }
  Start-Sleep -Milliseconds 1200
}
Log 'target exited'
[CB]::FreeConsole() | Out-Null

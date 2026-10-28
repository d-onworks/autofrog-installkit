# 실행 방식 시험(2026-10-28) — 화면을 계속 찍는다. burst.txt 시각까지는 0.5초 간격, 그 밖에는 10초 간격.
# 보이는 창 제목 목록이 바뀔 때마다 windows.jsonl 에 남긴다(관리자 경고 창 같은 막힘을 잡으려고).
param([string]$Out='C:\e2e\out')
$ErrorActionPreference='Continue'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public static class WE {
  public delegate bool EP(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EP cb, IntPtr l);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public static List<string> List() {
    var r = new List<string>();
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      if (IsWindowVisible(h)) {
        var t = new StringBuilder(512); GetWindowTextW(h, t, 512);
        if (t.Length > 0) { var c = new StringBuilder(256); GetClassNameW(h, c, 256); uint p; GetWindowThreadProcessId(h, out p); r.Add(p + "|" + c + "|" + t); }
      }
      return true; }, IntPtr.Zero);
    return r;
  }
}
'@
$utf8=New-Object Text.UTF8Encoding $false
$screens=Join-Path $Out 'screens'; New-Item -ItemType Directory -Force $screens | Out-Null
$lastWin=''
while (-not (Test-Path (Join-Path $Out 'shots-stop.txt'))) {
  $tag='idle'; try { $tag=([IO.File]::ReadAllText((Join-Path $Out 'tag.txt'))).Trim() } catch {}
  $burst=$false; try { $burst=((Get-Date).Ticks -lt [long]([IO.File]::ReadAllText((Join-Path $Out 'burst.txt')).Trim())) } catch {}
  try {
    $r=[Windows.Forms.SystemInformation]::VirtualScreen
    $b=New-Object Drawing.Bitmap($r.Width,$r.Height); $g=[Drawing.Graphics]::FromImage($b)
    $g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size)
    $b.Save((Join-Path $screens ($tag+'_'+(Get-Date -Format 'HHmmss_fff')+'.png')),[Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $b.Dispose()
  } catch { [IO.File]::AppendAllText((Join-Path $Out 'shots-errors.log'),((Get-Date).ToString('HH:mm:ss ')+$_.Exception.Message+"`r`n"),$utf8) }
  try {
    $w=@([WE]::List() | Sort-Object)
    $joined=$w -join "`n"
    if ($joined -ne $lastWin) {
      $rows=foreach ($x in $w) { $parts=$x.Split('|',3); $pn=''; try { $pn=(Get-Process -Id ([int]$parts[0]) -ErrorAction Stop).ProcessName } catch {}; [ordered]@{pid=[int]$parts[0];proc=$pn;cls=$parts[1];title=$parts[2]} }
      [IO.File]::AppendAllText((Join-Path $Out 'windows.jsonl'),(([ordered]@{time=(Get-Date).ToString('o');tag=$tag;windows=@($rows)}|ConvertTo-Json -Compress -Depth 4)+"`r`n"),$utf8)
      $lastWin=$joined
    }
  } catch {}
  if ($burst) { Start-Sleep -Milliseconds 500 } else { Start-Sleep -Seconds 10 }
}

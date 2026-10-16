$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class E2EWindow {
 [StructLayout(LayoutKind.Sequential)] public struct Rect {public int Left,Top,Right,Bottom;}
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
}
'@
$p=Get-Process WindowsSandboxRemoteSession -ErrorAction Stop | Where-Object MainWindowHandle -ne 0 | Select-Object -First 1
if (-not $p) { throw 'No sandbox window' }
$r=New-Object E2EWindow+Rect
[void][E2EWindow]::GetWindowRect($p.MainWindowHandle,[ref]$r)
$b=New-Object Drawing.Bitmap(($r.Right-$r.Left),($r.Bottom-$r.Top))
$g=[Drawing.Graphics]::FromImage($b);$dc=$g.GetHdc()
try { $ok=[E2EWindow]::PrintWindow($p.MainWindowHandle,$dc,2) } finally { $g.ReleaseHdc($dc) }
$b.Save('C:\AutoFrogE2E\20261016-092855\sandbox-window.png',[Drawing.Imaging.ImageFormat]::Png)
$g.Dispose();$b.Dispose()
@{pid=$p.Id;title=$p.MainWindowTitle;ok=$ok;rect=$r} | ConvertTo-Json -Depth 5 | Set-Content C:\AutoFrogE2E\20261016-092855\sandbox-window.json -Encoding UTF8

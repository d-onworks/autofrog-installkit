param([string]$Scenario='S1')
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object Text.UTF8Encoding $false
$out="C:\e2e\out\$Scenario"
$screens=Join-Path $out 'screens'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public class CheckConsole {
 [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
'@
$window=[CheckConsole]::GetConsoleWindow()
[void][CheckConsole]::ShowWindow($window,3)
$host.UI.RawUI.WindowTitle="AutoFrog $Scenario - fresh PowerShell commands"
function Save($value,$path) { [IO.File]::WriteAllText($path,(ConvertTo-Json -InputObject $value -Depth 8),(New-Object Text.UTF8Encoding $false)) }
function Shot($tag) {
 [void][CheckConsole]::SetForegroundWindow($window);Start-Sleep -Milliseconds 500
 $r=[Windows.Forms.SystemInformation]::VirtualScreen
 $b=New-Object Drawing.Bitmap($r.Width,$r.Height);$g=[Drawing.Graphics]::FromImage($b)
 try { $g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size);$b.Save((Join-Path $screens ((Get-Date -Format 'HHmmss_fff')+'_check-'+$tag+'.png')),[Drawing.Imaging.ImageFormat]::Png) }
 finally { $g.Dispose();$b.Dispose() }
}
$tests=@(
 @{id='npx-version';command='npx --version'},
 @{id='npm-version';command='npm --version'},
 @{id='npm-view';command='npm view vercel version'},
 @{id='create-next-app';command='npx -y create-next-app@latest --version'},
 @{id='gh-login-help';command='gh auth login --help'},
 @{id='vercel-login-help';command='vercel login --help'},
 @{id='supabase-login-help';command='supabase login --help'},
 @{id='claude-version';command='claude --version'},
 @{id='codex-version';command='codex --version'}
)
$report=[ordered]@{identity=[Security.Principal.WindowsIdentity]::GetCurrent().Name;userProfile=$env:USERPROFILE;policy=[string](Get-ExecutionPolicy);processPolicy=$env:PSExecutionPolicyPreference;path=$env:PATH;completed=$false;current='';tests=@()}
foreach($test in $tests) {
 $report.current=$test.id;Save $report "$out\command-checks.json"
 Clear-Host;Write-Host "[$Scenario] $($test.command)" -ForegroundColor Cyan
 Write-Host "User: $($report.identity) | policy=$($report.policy) | Process=$($report.processPolicy)"
 $contextPath="$out\check-context-$($test.id).json"
 $body=@'
[Console]::OutputEncoding=New-Object Text.UTF8Encoding $false
$ErrorActionPreference='Continue';$ProgressPreference='SilentlyContinue'
$ctx=@{identity=[Security.Principal.WindowsIdentity]::GetCurrent().Name;userProfile=$env:USERPROFILE;path=$env:PATH;policy=[string](Get-ExecutionPolicy);processPolicy=$env:PSExecutionPolicyPreference}
[IO.File]::WriteAllText('__CONTEXT__',($ctx | ConvertTo-Json -Compress),(New-Object Text.UTF8Encoding $false))
$LASTEXITCODE=-999
try { & __COMMAND__ 2>&1 | ForEach-Object { [Console]::WriteLine($_.ToString()) };exit $LASTEXITCODE }
catch { [Console]::Error.WriteLine($_.Exception.Message);exit 1 }
'@
 $body=$body.Replace('__CONTEXT__',$contextPath).Replace('__COMMAND__',$test.command)
 $pi=New-Object Diagnostics.ProcessStartInfo
 $pi.FileName='powershell.exe';$pi.Arguments='-NoProfile -EncodedCommand '+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($body))
 $pi.UseShellExecute=$false;$pi.CreateNoWindow=$true;$pi.RedirectStandardOutput=$true;$pi.RedirectStandardError=$true
 $pi.StandardOutputEncoding=New-Object Text.UTF8Encoding $false;$pi.StandardErrorEncoding=New-Object Text.UTF8Encoding $false
 $pi.EnvironmentVariables.Remove('PSExecutionPolicyPreference')
 $machine=[Environment]::GetEnvironmentVariable('Path','Machine')
 $user=[Environment]::ExpandEnvironmentVariables([string](Get-Item 'HKCU:\Environment').GetValue('Path','','DoNotExpandEnvironmentNames'))
 $pi.EnvironmentVariables['Path']="$user;$machine";$pi.WorkingDirectory=$env:TEMP
 $p=New-Object Diagnostics.Process;$p.StartInfo=$pi;$sw=[Diagnostics.Stopwatch]::StartNew();[void]$p.Start()
 $stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync();$lastShot=Get-Date
 while(-not $p.WaitForExit(1000) -and $sw.Elapsed.TotalSeconds -lt 150) {
  if(((Get-Date)-$lastShot).TotalSeconds -ge 60){Shot ($test.id+'-running');$lastShot=Get-Date}
 }
 $timedOut=-not $p.HasExited
 if($timedOut){ & taskkill.exe /PID $p.Id /T /F 2>&1 | Out-Null;[void]$p.WaitForExit(5000) }
 $sw.Stop();$text=$stdout.Result;$err=$stderr.Result
 $context=[IO.File]::ReadAllText($contextPath) | ConvertFrom-Json
 $blocked=($text+"`n"+$err) -match 'cannot be loaded because running scripts is disabled|not recognized as the name of a cmdlet|스크립트를 실행할 수 없으므로|용어.*cmdlet.*인식되지'
 $ok=-not $timedOut -and $p.ExitCode -eq 0 -and -not $blocked -and $context.policy -eq 'RemoteSigned' -and -not $context.processPolicy
 $row=[ordered]@{id=$test.id;command=$test.command;exit=$p.ExitCode;sec=[math]::Round($sw.Elapsed.TotalSeconds,2);timeout=$timedOut;policyOrPathError=$blocked;ok=$ok;stdout=$text;stderr=$err;context=$context}
 $report.tests+=@($row);Save $report "$out\command-checks.json"
 @($text -split "`r?`n" | Select-Object -First 26) | ForEach-Object {Write-Host $_}
 if($err -and $err -notmatch '^#< CLIXML'){@($err -split "`r?`n" | Select-Object -First 26) | ForEach-Object {Write-Host $_ -ForegroundColor Yellow}}
 Write-Host "exit=$($p.ExitCode) | ok=$ok | seconds=$($row.sec)"
 $tag=if($ok){'pass'}else{'fail'};Shot ($test.id+'-'+$tag)
}
$report.completed=$true;$report.current='';$report.allOk=(@($report.tests | Where-Object {-not $_.ok}).Count -eq 0)
Save $report "$out\command-checks.json"
Clear-Host;Write-Host "AutoFrog $Scenario - fresh PowerShell command results" -ForegroundColor Cyan
foreach($row in $report.tests){Write-Host ('{0,-48} exit={1} OK={2}' -f $row.command,$row.exit,$row.ok)}
Write-Host "Policy=$($report.policy); Process=$($report.processPolicy); allOk=$($report.allOk)"
Shot 'all-results';Start-Sleep 5
if($report.allOk){exit 0}else{exit 1}

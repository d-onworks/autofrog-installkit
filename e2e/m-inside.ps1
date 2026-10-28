# 실행 방식 시험(2026-10-28) — 샌드박스 안에서 시험 하나(T1·T2a·T2b·T3·T4)를 돌린다.
#   T1  : 표준 사용자(수강생)가 일반 PowerShell 창을 열고 1번 한 줄(irm | iex)을 직접 친다
#   T2a : 같은 계정을 관리자 권한으로 승격한 PowerShell 창에 같은 한 줄 (집 PC: 내 계정이 관리자)
#   T2b : 표준 사용자 PC 에서 관리자 계정(pcadmin)을 넣어 승격한 창에 같은 한 줄
#   T3  : Win+R(실행 창)에 2번 명령을 진짜로 붙여 넣는다 + 1번 Win+R + 실패 상황 흉내(쓰기 막힘·백신 탐지)
#   T4  : Win+R 에 개선안(-NoExit, powershell 한 번)을 붙여 넣는다 + 같은 실패 흉내 + 경로에 빈칸·한글
param([string]$Test='T1')
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$Base='C:\e2e'; $Out=Join-Path $Base 'out'
New-Item -ItemType Directory -Force $Out | Out-Null
$utf8=New-Object Text.UTF8Encoding $false
$PSExe="$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
function Save-Json($o,[string]$p) { [IO.File]::WriteAllText($p,($o | ConvertTo-Json -Depth 10),$utf8) }
function Log([string]$m) { [IO.File]::AppendAllText((Join-Path $Out 'inside.log'),((Get-Date).ToString('HH:mm:ss.fff')+' '+$m+"`r`n"),$utf8) }
function Phase([string]$p) { Save-Json ([ordered]@{test=$Test;phase=$p;time=(Get-Date).ToString('o')}) (Join-Path $Out 'progress.json'); Log "phase $p" }
function Set-Tag([string]$t,[int]$BurstSec=0) {
  [IO.File]::WriteAllText((Join-Path $Out 'tag.txt'),$t)
  [IO.File]::WriteAllText((Join-Path $Out 'burst.txt'),[string](Get-Date).AddSeconds($BurstSec).Ticks)
}
function Wait-File([string]$Path,[int]$Sec) { $d=(Get-Date).AddSeconds($Sec); while (-not (Test-Path $Path) -and (Get-Date) -lt $d) { Start-Sleep 2 }; return (Test-Path $Path) }
function Stop-Code { Get-Process Code -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
function Kill-Tree([int]$ProcId) {
  if ($ProcId -le 0) { return }
  & taskkill.exe /PID $ProcId /T /F 2>&1 | Out-Null
}
function Copy-KitLogs([string]$Profile,[string]$Dest) {
  $l=Join-Path $Profile 'autofrog-kit-logs'
  if (Test-Path $l) { Copy-Item $l $Dest -Recurse -Force -ErrorAction SilentlyContinue }
}
function New-Pw { [Guid]::NewGuid().ToString('N')+'aA!9' }
function Run-Replay([string]$Arguments,[string]$Prefix,[int]$Timeout=90) {
  # Win+R 과 똑같은 인자 문자열로 다시 띄우되, 출력과 오류를 받아 둔다(창이 너무 빨리 닫혀 화면으로 못 읽을 때)
  $pi=New-Object Diagnostics.ProcessStartInfo
  $pi.FileName=$PSExe; $pi.Arguments=$Arguments; $pi.UseShellExecute=$false; $pi.CreateNoWindow=$true
  $pi.RedirectStandardOutput=$true; $pi.RedirectStandardError=$true; $pi.RedirectStandardInput=$true
  $pi.EnvironmentVariables.Remove('PSExecutionPolicyPreference')
  $sw=[Diagnostics.Stopwatch]::StartNew(); $p=[Diagnostics.Process]::Start($pi); $p.StandardInput.Close()
  $so=$p.StandardOutput.ReadToEndAsync(); $se=$p.StandardError.ReadToEndAsync()
  $done=$p.WaitForExit($Timeout*1000); if (-not $done) { Kill-Tree $p.Id; $p.WaitForExit() }
  $sw.Stop()
  [IO.File]::WriteAllText("$Prefix.stdout.txt",$so.Result,$utf8); [IO.File]::WriteAllText("$Prefix.stderr.txt",$se.Result,$utf8)
  $r=[ordered]@{args=$Arguments;exit=$p.ExitCode;sec=[math]::Round($sw.Elapsed.TotalSeconds,2);timeout=(-not $done)}
  Save-Json $r "$Prefix.json"; return $r
}
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class KB {
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  public static void Down(byte vk) { keybd_event(vk, 0, 0, UIntPtr.Zero); }
  public static void Up(byte vk) { keybd_event(vk, 0, 2, UIntPtr.Zero); }
}
'@
function Invoke-WinR([string]$Cmd,[string]$Tag,[int]$WaitSec,[switch]$Answer,[switch]$CloseAtEnd) {
  # 진짜 Win+R: 실행 창을 열고 Ctrl+V 로 붙여 넣고 Enter. 그 뒤 탐색기가 띄운 powershell 과 그 자식들의 시작·종료·종료 코드를 잰다.
  $d=Join-Path $Out $Tag; New-Item -ItemType Directory -Force $d | Out-Null
  Set-Tag $Tag ([Math]::Min($WaitSec,90)+5)
  $explorer=@(Get-Process explorer -ErrorAction SilentlyContinue | ForEach-Object Id)
  foreach ($s in "st-$Tag","sp-$Tag") { Unregister-Event -SourceIdentifier $s -ErrorAction SilentlyContinue }
  Register-CimIndicationEvent -Query "SELECT * FROM Win32_ProcessStartTrace WHERE ProcessName='powershell.exe' OR ProcessName='cmd.exe'" -SourceIdentifier "st-$Tag" | Out-Null
  Register-CimIndicationEvent -Query "SELECT * FROM Win32_ProcessStopTrace WHERE ProcessName='powershell.exe' OR ProcessName='cmd.exe'" -SourceIdentifier "sp-$Tag" | Out-Null
  Set-Clipboard -Value $Cmd
  Start-Sleep -Milliseconds 800
  [KB]::Down(0x5B); [KB]::Down(0x52); Start-Sleep -Milliseconds 80; [KB]::Up(0x52); [KB]::Up(0x5B)
  Start-Sleep -Milliseconds 1500
  $run=@(Get-Process explorer -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle } | Select-Object Id,MainWindowTitle)
  [KB]::Down(0x11); [KB]::Down(0x56); Start-Sleep -Milliseconds 60; [KB]::Up(0x56); [KB]::Up(0x11)
  Start-Sleep -Milliseconds 700
  $t0=Get-Date
  [KB]::Down(0x0D); Start-Sleep -Milliseconds 40; [KB]::Up(0x0D)
  Log "winr $Tag enter"
  $tree=[ordered]@{}; $outer=0; $bridge=$null; $deadline=$t0.AddSeconds($WaitSec); $why='deadline'
  while ((Get-Date) -lt $deadline) {
    foreach ($e in @(Get-Event -SourceIdentifier "st-$Tag" -ErrorAction SilentlyContinue)) {
      $n=$e.SourceEventArgs.NewEvent; $procId=[int]$n.ProcessID; $pp=[int]$n.ParentProcessID
      $isOuter=($outer -eq 0 -and $explorer -contains $pp)
      if ($isOuter -or $tree.Contains([string]$pp)) {
        $at=[DateTime]::FromFileTime([long]$n.TIME_CREATED)
        $cmdline=$null; try { $cmdline=(Get-CimInstance Win32_Process -Filter "ProcessId=$procId").CommandLine } catch {}
        $tree[[string]$procId]=[ordered]@{pid=$procId;ppid=$pp;name=$n.ProcessName;startMs=[int]($at-$t0).TotalMilliseconds;stopMs=$null;exit=$null;cmd=$cmdline}
        if ($isOuter) { $outer=$procId }
      }
      Remove-Event -EventIdentifier $e.EventIdentifier
    }
    foreach ($e in @(Get-Event -SourceIdentifier "sp-$Tag" -ErrorAction SilentlyContinue)) {
      $n=$e.SourceEventArgs.NewEvent; $k=[string][int]$n.ProcessID
      if ($tree.Contains($k)) { $tree[$k].stopMs=[int]([DateTime]::FromFileTime([long]$n.TIME_CREATED)-$t0).TotalMilliseconds; $tree[$k].exit=[long]$n.ExitStatus }
      Remove-Event -EventIdentifier $e.EventIdentifier
    }
    if ($outer -and $Answer -and -not $bridge) {
      $bridge=Start-Process $PSExe -PassThru -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File C:\e2e\m-bridge.ps1 -Mode Attach -TargetPid $outer -Out $d -TimeoutSec $WaitSec"
    }
    $alive=@($tree.Values | Where-Object { $null -eq $_.stopMs -and $_.name -eq 'powershell.exe' })
    if ($outer -and $alive.Count -eq 0) { $why='all-exited'; break }
    $bd=Join-Path $d 'bridge-done.json'
    if ($outer -and (Test-Path $bd)) { $pb=$false; try { $pb=([IO.File]::ReadAllText($bd) | ConvertFrom-Json).promptBack } catch {}; if ($pb) { $why='bridge-done'; break } }
    Start-Sleep -Milliseconds 100
  }
  $aliveAtEnd=@($tree.Values | Where-Object { $null -eq $_.stopMs } | ForEach-Object { $_.pid })
  if ($aliveAtEnd.Count) { Start-Sleep 3 }   # 브리지가 마지막 화면 글자를 한 번 더 받도록
  if ($CloseAtEnd -and $outer -and $aliveAtEnd.Count) { Kill-Tree $outer; Start-Sleep 2 }
  foreach ($s in "st-$Tag","sp-$Tag") { Unregister-Event -SourceIdentifier $s -ErrorAction SilentlyContinue; Get-Event -SourceIdentifier $s -ErrorAction SilentlyContinue | Remove-Event }
  if ($bridge) { [void]$bridge.WaitForExit(15000); if (-not $bridge.HasExited) { Kill-Tree $bridge.Id } }
  $r=[ordered]@{tag=$Tag;cmd=$Cmd;enterAt=$t0.ToString('o');runDialog=$run;outerPid=$outer;ended=$why;aliveAtEndPids=$aliveAtEnd;closedByHarness=([bool]($CloseAtEnd -and $aliveAtEnd.Count));tree=@($tree.Values)}
  Save-Json $r (Join-Path $d 'winr.json')
  Set-Tag "$Tag-after" 0
  return $r
}
function Result-Of([string]$Profile,[datetime]$Since) {
  $f=Join-Path $Profile 'autofrog-kit-logs\result-latest.json'
  if (-not (Test-Path $f)) { return @{exists=$false} }
  $j=[IO.File]::ReadAllText($f) | ConvertFrom-Json
  return [ordered]@{exists=$true;fresh=((Get-Item $f).LastWriteTime -gt $Since);allOk=$j.allOk;user=$j.user;steps=$j.steps;verify=$j.verify}
}

$shots=$null; $server=$null
try {
  Phase 'boot'
  $sacKey='HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'; $sacBefore=(Get-ItemProperty $sacKey -ErrorAction SilentlyContinue).VerifiedAndReputablePolicyState
  # 보통 PC(스마트 앱 컨트롤 꺼짐)를 흉내 — 기존 하네스(inside.ps1)와 같은 처리
  if ($sacBefore -eq 1) { Set-ItemProperty $sacKey VerifiedAndReputablePolicyState 0 -Type DWord; & "$env:windir\System32\CiTool.exe" --refresh --json | Out-Null }
  $uac=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue
  $mp=$null; try { $mp=Get-MpComputerStatus | Select-Object AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,BehaviorMonitorEnabled,IoavProtectionEnabled,IsTamperProtected,AMProductVersion,AntivirusSignatureVersion } catch { $mp=$_.Exception.Message }
  $env0=[ordered]@{test=$Test;user=[Security.Principal.WindowsIdentity]::GetCurrent().Name;whoamiGroups=(& whoami.exe /groups /fo csv 2>&1 | Out-String);sacBefore=$sacBefore;sacAfter=(Get-ItemProperty $sacKey -ErrorAction SilentlyContinue).VerifiedAndReputablePolicyState;EnableLUA=$uac.EnableLUA;ConsentPromptBehaviorAdmin=$uac.ConsentPromptBehaviorAdmin;ConsentPromptBehaviorUser=$uac.ConsentPromptBehaviorUser;defender=$mp;os=(Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber);ps=$PSVersionTable.PSVersion.ToString();executionPolicies=@(Get-ExecutionPolicy -List | ForEach-Object { "$($_.Scope)=$($_.ExecutionPolicy)" })}
  Save-Json $env0 (Join-Path $Out 'env.json')
  & icacls.exe C:\e2e /grant '*S-1-5-32-545:(OI)(CI)M' /T /Q | Out-Null
  Set-Tag "$Test-boot" 0
  $shots=Start-Process $PSExe -PassThru -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File C:\e2e\m-shots.ps1 -Out $Out"
  $server=Start-Process $PSExe -PassThru -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File C:\e2e\m-serve.ps1 -Out $Out"
  Start-Sleep 3
  $summary=[ordered]@{test=$Test}

  if ($Test -eq 'T1') {
    Phase 'create-standard-user'
    $pw=New-Pw; $sec=ConvertTo-SecureString $pw -AsPlainText -Force
    $u=New-LocalUser -Name '수강생' -Password $sec -AccountNeverExpires
    Add-LocalGroupMember -Group (Get-LocalGroup -SID 'S-1-5-32-545') -Member $u
    $cred=New-Object Management.Automation.PSCredential("$env:COMPUTERNAME\수강생",$sec)
    $d=Join-Path $Out 'T1'; New-Item -ItemType Directory -Force $d | Out-Null
    [IO.File]::WriteAllText((Join-Path $d 'type.txt'),'irm https://autofrog.kr/kit.ps1 | iex')
    Phase 'T1-install'; Set-Tag 'T1' 20; $since=Get-Date
    Start-Process $PSExe -Credential $cred -LoadUserProfile -WindowStyle Hidden -WorkingDirectory C:\e2e -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File C:\e2e\m-bridge.ps1 -Mode Launch -Out $d" | Out-Null
    $fin=Wait-File (Join-Path $d 'bridge-done.json') 2700
    Set-Tag 'T1-after' 0
    Phase 'T1-probe'
    Start-Process $PSExe -Credential $cred -LoadUserProfile -WindowStyle Hidden -Wait -WorkingDirectory C:\e2e -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File C:\e2e\m-probe.ps1 -OutFile $d\probe-수강생.json"
    $summary.bridgeFinished=$fin
    $summary.result=Result-Of 'C:\Users\수강생' $since
    Copy-KitLogs 'C:\Users\수강생' (Join-Path $d 'kit-logs')
  }
  elseif ($Test -eq 'T2a') {
    Phase 'T2a-install'
    Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' ConsentPromptBehaviorAdmin 0 -Type DWord
    $d=Join-Path $Out 'T2a'; New-Item -ItemType Directory -Force $d | Out-Null
    [IO.File]::WriteAllText((Join-Path $d 'type.txt'),'irm https://autofrog.kr/kit.ps1 | iex')
    Set-Tag 'T2a' 20; $since=Get-Date
    Start-Process $PSExe -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File C:\e2e\m-bridge.ps1 -Mode Launch -Out $d" | Out-Null
    $fin=Wait-File (Join-Path $d 'bridge-done.json') 2700
    Set-Tag 'T2a-after' 0
    Phase 'T2a-probe'
    Start-Process $PSExe -WindowStyle Hidden -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File C:\e2e\m-probe.ps1 -OutFile $d\probe-self.json"
    $summary.bridgeFinished=$fin
    $summary.result=Result-Of $env:USERPROFILE $since
    $acl=[ordered]@{}
    foreach ($p in @("$env:USERPROFILE\.codex\config.toml","$env:APPDATA\npm","$env:LOCALAPPDATA\AutoFrogKit","$env:LOCALAPPDATA\Programs\Microsoft VS Code","$env:LOCALAPPDATA\Programs\Git","$env:APPDATA\Code\User\settings.json")) {
      if (Test-Path $p) { $a=Get-Acl $p; $acl[$p]=[ordered]@{owner=$a.Owner;access=@($a.Access | ForEach-Object { "$($_.IdentityReference) $($_.FileSystemRights) $($_.AccessControlType)" })} } else { $acl[$p]='missing' }
    }
    $summary.acl=$acl
    $summary.codeProcs=@(Get-CimInstance Win32_Process -Filter "Name='Code.exe'" | Select-Object -First 3 ProcessId,ParentProcessId,CommandLine)
    Copy-KitLogs $env:USERPROFILE (Join-Path $d 'kit-logs')
  }
  elseif ($Test -eq 'T2b') {
    Phase 'create-users'
    Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' ConsentPromptBehaviorAdmin 0 -Type DWord
    $pw=New-Pw; $sec=ConvertTo-SecureString $pw -AsPlainText -Force
    $u=New-LocalUser -Name '수강생' -Password $sec -AccountNeverExpires
    Add-LocalGroupMember -Group (Get-LocalGroup -SID 'S-1-5-32-545') -Member $u
    $scred=New-Object Management.Automation.PSCredential("$env:COMPUTERNAME\수강생",$sec)
    $apw=New-Pw; $asec=ConvertTo-SecureString $apw -AsPlainText -Force
    $a=New-LocalUser -Name 'pcadmin' -Password $asec -AccountNeverExpires
    Add-LocalGroupMember -Group (Get-LocalGroup -SID 'S-1-5-32-544') -Member $a
    $acred=New-Object Management.Automation.PSCredential("$env:COMPUTERNAME\pcadmin",$asec)
    # 수강생 프로필을 먼저 만들어 둔다(수강생이 로그인해 있는 PC 라는 전제)
    Start-Process $PSExe -Credential $scred -LoadUserProfile -WindowStyle Hidden -Wait -WorkingDirectory C:\e2e -ArgumentList '-NoProfile -Command exit'
    $d=Join-Path $Out 'T2b'; New-Item -ItemType Directory -Force $d | Out-Null
    [IO.File]::WriteAllText((Join-Path $d 'type.txt'),'irm https://autofrog.kr/kit.ps1 | iex')
    Phase 'T2b-install'; Set-Tag 'T2b' 20; $since=Get-Date
    Start-Process $PSExe -Credential $acred -LoadUserProfile -WindowStyle Hidden -WorkingDirectory C:\e2e -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File C:\e2e\m-elevate.ps1 -Out $d" | Out-Null
    $fin=Wait-File (Join-Path $d 'bridge-done.json') 2700
    Set-Tag 'T2b-after' 0
    Phase 'T2b-probe'
    Start-Process $PSExe -Credential $scred -LoadUserProfile -WindowStyle Hidden -Wait -WorkingDirectory C:\e2e -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File C:\e2e\m-probe.ps1 -OutFile $d\probe-수강생.json"
    Start-Process $PSExe -Credential $acred -LoadUserProfile -WindowStyle Hidden -Wait -WorkingDirectory C:\e2e -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File C:\e2e\m-probe.ps1 -OutFile $d\probe-pcadmin.json"
    $summary.bridgeFinished=$fin
    $summary.resultStudent=Result-Of 'C:\Users\수강생' $since
    $summary.resultAdmin=Result-Of 'C:\Users\pcadmin' $since
    $summary.where=[ordered]@{}
    foreach ($who in '수강생','pcadmin') { foreach ($rel in 'AppData\Local\AutoFrogKit','AppData\Local\Programs\Microsoft VS Code','AppData\Local\Programs\Git','AppData\Roaming\npm','.codex','Desktop\오토프로그 로그인.lnk') { $summary.where["$who\$rel"]=(Test-Path (Join-Path "C:\Users\$who" $rel)) } }
    Copy-KitLogs 'C:\Users\pcadmin' (Join-Path $d 'kit-logs-pcadmin')
  }
  elseif ($Test -eq 'T3' -or $Test -eq 'T3x') {
    $cmd2='powershell -NoProfile -c "irm https://autofrog.kr/kit.ps1 -OutFile $env:TEMP\af.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File $env:TEMP\af.ps1"'
    $cmd1='powershell -ExecutionPolicy Bypass -c "irm https://autofrog.kr/kit.ps1 | iex"'
    if ($Test -eq 'T3') {
    Phase 'T3-whoami'
    $w=Invoke-WinR ('cmd /c whoami /groups /fo csv > C:\e2e\out\winr-whoami.txt') 'T3-whoami' 15
    $summary.winrWhoami=$w
    Phase 'T3a-cmd2-live'; $since=Get-Date
    $summary.T3a=Invoke-WinR $cmd2 'T3a' 2700 -Answer
    $summary.T3a_result=Result-Of $env:USERPROFILE $since
    Stop-Code
    Phase 'T3d-cmd1-live'; $since=Get-Date
    $summary.T3d=Invoke-WinR $cmd1 'T3d' 1500 -Answer
    $summary.T3d_result=Result-Of $env:USERPROFILE $since
    Stop-Code
    }
    Phase 'T3c-cmd2-write-blocked'
    # 백신이 받은 파일을 잡아 둔(쓰기 거부) 상황 흉내: af.ps1 자리에 같은 이름의 폴더를 만든다
    Remove-Item "$env:TEMP\af.ps1" -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory "$env:TEMP\af.ps1" | Out-Null
    $summary.T3c=Invoke-WinR $cmd2 'T3c' 40 -Answer -CloseAtEnd
    $summary.T3c_replay=Run-Replay ($cmd2.Substring(11)) (Join-Path $Out 'T3c\replay') 60
    Remove-Item "$env:TEMP\af.ps1" -Recurse -Force -ErrorAction SilentlyContinue
    Phase 'T3b-cmd2-amsi'
    $a2=$cmd2.Replace('https://autofrog.kr/kit.ps1','http://localhost:8765/amsi.ps1')
    $summary.T3b=Invoke-WinR $a2 'T3b' 40 -Answer -CloseAtEnd
    $summary.T3b_replay=Run-Replay ($a2.Substring(11)) (Join-Path $Out 'T3b\replay') 60
    Remove-Item "$env:TEMP\af.ps1" -Force -ErrorAction SilentlyContinue
    Phase 'T3e-cmd1-amsi'
    $a1=$cmd1.Replace('https://autofrog.kr/kit.ps1','http://localhost:8765/amsi.ps1')
    $summary.T3e=Invoke-WinR $a1 'T3e' 40 -Answer -CloseAtEnd
    $summary.T3e_replay=Run-Replay ($a1.Substring(11)) (Join-Path $Out 'T3e\replay') 60
  }
  elseif ($Test -eq 'T4') {
    $c1='powershell -NoProfile -ExecutionPolicy Bypass -NoExit -c "irm https://autofrog.kr/kit.ps1 -OutFile $env:TEMP\af.ps1; & $env:TEMP\af.ps1"'
    $cmd2='powershell -NoProfile -c "irm https://autofrog.kr/kit.ps1 -OutFile $env:TEMP\af.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File $env:TEMP\af.ps1"'
    $c3='powershell -NoExit -ExecutionPolicy Bypass -c "irm https://autofrog.kr/kit.ps1 | iex"'
    Phase 'T4a-c1-live'; $since=Get-Date
    $summary.T4a=Invoke-WinR $c1 'T4a' 2700 -Answer -CloseAtEnd
    $summary.T4a_result=Result-Of $env:USERPROFILE $since
    Stop-Code
    Phase 'T4c-c1-write-blocked'
    Remove-Item "$env:TEMP\af.ps1" -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory "$env:TEMP\af.ps1" | Out-Null
    $summary.T4c=Invoke-WinR $c1 'T4c' 30 -Answer -CloseAtEnd
    Remove-Item "$env:TEMP\af.ps1" -Recurse -Force -ErrorAction SilentlyContinue
    Phase 'T4b-c1-amsi'
    $summary.T4b=Invoke-WinR ($c1.Replace('https://autofrog.kr/kit.ps1','http://localhost:8765/amsi.ps1')) 'T4b' 30 -Answer -CloseAtEnd
    Remove-Item "$env:TEMP\af.ps1" -Force -ErrorAction SilentlyContinue
    Phase 'T4f-c3-amsi'
    $summary.T4f=Invoke-WinR ($c3.Replace('https://autofrog.kr/kit.ps1','http://localhost:8765/amsi.ps1')) 'T4f' 30 -Answer -CloseAtEnd
    Phase 'T4e-space-path'
    # 사용자 이름에 빈칸·한글이 있어 TEMP 경로에 빈칸이 들어간 PC 흉내 — 명령줄 해석만 본다(시험 서버의 echo.ps1)
    $sp='C:\임시 폴더 공백'; New-Item -ItemType Directory -Force $sp | Out-Null
    $oldT=$env:TEMP; $oldTmp=$env:TMP; $env:TEMP=$sp; $env:TMP=$sp
    try {
      $e=[ordered]@{}
      $i=0
      foreach ($c in @($cmd2,$c1)) {
        $i++; Remove-Item "$sp\af.ps1" -Force -ErrorAction SilentlyContinue
        $x=$c.Replace('https://autofrog.kr/kit.ps1','http://localhost:8765/echo.ps1').Replace(' -NoExit','')
        $e["form$i"]=Run-Replay ($x.Substring(11)) (Join-Path $Out "T4e-form$i") 60
        $e["form$i"].saved=(Test-Path "$sp\af.ps1")
      }
      $summary.T4e=$e
    } finally { $env:TEMP=$oldT; $env:TMP=$oldTmp }
  }
  Save-Json $summary (Join-Path $Out 'summary.json')
  Phase 'complete'
} catch {
  Save-Json @{message=$_.Exception.Message;position=$_.InvocationInfo.PositionMessage;stack=$_.ScriptStackTrace;time=(Get-Date).ToString('o')} (Join-Path $Out 'error.json')
} finally {
  [IO.File]::WriteAllText((Join-Path $Out 'shots-stop.txt'),'stop'); Start-Sleep 12
  if ($server) { Kill-Tree $server.Id }
  Save-Json @{completed=$true;time=(Get-Date).ToString('o')} (Join-Path $Out 'done.json')
}

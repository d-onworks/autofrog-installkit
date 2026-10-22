param([string]$RunId=(Get-Date -Format 'yyyyMMdd-HHmmss'),[string]$ZipPath='C:\AutoFrogE2E\autofrog-setup-kit-20261016.zip',[ValidateSet('S1','S2','Both')][string]$Scenario='Both',[int]$TimeoutMinutes=45,[ValidateSet('Zip','OneLiner')][string]$Method='Zip',[switch]$Live,[ValidateSet('','cmd','ps')][string]$TwoLine='')
$ErrorActionPreference='Stop'
$Root='C:\AutoFrogE2E'
if ($ZipPath -notlike "$Root\*") { throw 'Zip must be staged under C:\AutoFrogE2E' }
if ($RunId -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid RunId' }
$RunRoot=Join-Path $Root $RunId
New-Item -ItemType Directory -Force $RunRoot | Out-Null
function Save-Json($Object,[string]$Path) { [IO.File]::WriteAllText($Path,($Object | ConvertTo-Json -Depth 12),(New-Object Text.UTF8Encoding $false)) }
# Host writes are confined to Root; grant only the named desktop account access.
& icacls.exe $Root /grant '오토프로그:(OI)(CI)M' /Q | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Cannot grant mapped-folder access' }
$ready=$false
for ($i=0;$i -le 20;$i++) {
    $old=$ErrorActionPreference; $ErrorActionPreference='Continue'
    $q=(& query.exe user 2>&1 | Out-String); $qc=$LASTEXITCODE; $ErrorActionPreference=$old
    Save-Json @{query=$q;exit=$qc;time=(Get-Date).ToString('o');attempt=$i+1} (Join-Path $RunRoot 'host-session.json')
    if ($q -match '(?m)오토프로그\s+.*\s(Active|활성)\s') { $ready=$true; break }
    if ($i -lt 20) { Start-Sleep 60 }
}
if (-not $ready) { Save-Json @{status='BLOCKED';reason='No active 오토프로그 session within 20 minutes'} (Join-Path $RunRoot 'host-result.json'); exit 2 }
& (Join-Path $PSScriptRoot 'cleanup.ps1') -ReportPath (Join-Path $RunRoot 'cleanup-before.json')
if ($LASTEXITCODE -eq 3) { throw 'Sandbox VM cleanup failed; reboot prohibited' }
$os=Get-CimInstance Win32_OperatingSystem
Save-Json @{method=$Method;os=($os | Select-Object Caption,Version,BuildNumber);zipSHA256=(Get-FileHash $ZipPath -Algorithm SHA256).Hash;zipBytes=(Get-Item $ZipPath).Length} (Join-Path $RunRoot 'host.json')
$scenarios=@($Scenario); if ($Scenario -eq 'Both') { $scenarios=@('S1','S2') }
$results=@()
foreach ($s in $scenarios) {
    $dir=Join-Path $RunRoot $s; New-Item -ItemType Directory -Force $dir | Out-Null
    foreach ($name in @('inside.ps1','probe.ps1','screen-monitor.ps1','visible-install.ps1','visible-oneliner.ps1','serve.ps1','mirror-console.ps1','command-check.ps1')) { Copy-Item (Join-Path $PSScriptRoot $name) (Join-Path $dir $name) -Force }
    if ($Method -eq 'OneLiner') {
        # 한 줄 설치: 시험 서버가 내보낼 install.ps1 + 온라인 키트 zip (C:\AutoFrogE2E\www 에 미리 올려 둔다)
        New-Item -ItemType Directory -Force (Join-Path $dir 'www') | Out-Null
        Copy-Item (Join-Path $Root 'www\install.ps1') (Join-Path $dir 'www\install.ps1') -Force
        Copy-Item $ZipPath (Join-Path $dir 'www\autofrog-setup-kit.zip') -Force
        if ($Live) { Set-Content (Join-Path $dir 'live.flag') 'https://autofrog.kr/kit.ps1' }  # 진짜 주소로 시험
        if ($TwoLine) { Set-Content (Join-Path $dir 'twoline.flag') $TwoLine }  # 2번 명령으로 시험(2026-10-22)
    } else { Copy-Item $ZipPath (Join-Path $dir 'kit.zip') -Force }
    $start="@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\e2e\inside.ps1 -Scenario $s -Method $Method > C:\e2e\boot-console.log 2>&1`r`n"
    [IO.File]::WriteAllText((Join-Path $dir 'start.cmd'),$start,[Text.Encoding]::ASCII)
    $escaped=[Security.SecurityElement]::Escape($dir)
    $wsb=@"
<Configuration>
  <Networking>Enable</Networking><VGpu>Disable</VGpu><MemoryInMB>8192</MemoryInMB>
  <MappedFolders><MappedFolder><HostFolder>$escaped</HostFolder><SandboxFolder>C:\e2e</SandboxFolder><ReadOnly>false</ReadOnly></MappedFolder></MappedFolders>
  <LogonCommand><Command>cmd.exe /d /c C:\e2e\start.cmd</Command></LogonCommand>
</Configuration>
"@
    $wsbPath=Join-Path $dir "$s.wsb"; [IO.File]::WriteAllText($wsbPath,$wsb,(New-Object Text.UTF8Encoding $true))
    $task="AutoFrogE2E-$RunId-$s"
    $started=Get-Date; $sandboxPids=@()
    try {
        $action=New-ScheduledTaskAction -Execute "$env:WINDIR\System32\WindowsSandbox.exe" -Argument ('"'+$wsbPath+'"')
        $principal=New-ScheduledTaskPrincipal -UserId '오토프로그' -LogonType Interactive -RunLevel Highest
        $settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::FromMinutes($TimeoutMinutes+2))
        Register-ScheduledTask -TaskName $task -Action $action -Principal $principal -Settings $settings | Out-Null
        Start-ScheduledTask -TaskName $task
        $deadline=$started.AddMinutes($TimeoutMinutes)
        $marker=Join-Path $dir "out\$s\done.json"
        while ((Get-Date) -lt $deadline -and -not (Test-Path $marker)) {
            $sandboxPids=@(Get-Process WindowsSandbox* -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
            if (((Get-Date)-$started).TotalSeconds -gt 120 -and $sandboxPids.Count -eq 0 -and -not (Test-Path (Join-Path $dir 'out'))) { throw ('Sandbox did not start; task result='+ (Get-ScheduledTaskInfo -TaskName $task).LastTaskResult) }
            Save-Json @{scenario=$s;state='RUNNING';elapsedSec=[int]((Get-Date)-$started).TotalSeconds;pids=$sandboxPids;task=(Get-ScheduledTaskInfo -TaskName $task | Select-Object LastTaskResult,LastRunTime)} (Join-Path $RunRoot 'host-progress.json')
            Start-Sleep 5
        }
        $completion=$null; if (Test-Path $marker) { $completion=Get-Content $marker -Raw -Encoding UTF8 | ConvertFrom-Json }
        $results+=@{scenario=$s;completion=$completion;marker=(Test-Path $marker);sec=[math]::Round(((Get-Date)-$started).TotalSeconds,1);taskResult=(Get-ScheduledTaskInfo -TaskName $task).LastTaskResult}
    } catch { $results+=@{scenario=$s;error=$_.Exception.Message} }
    finally {
        if (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $task -Confirm:$false }
        & (Join-Path $PSScriptRoot 'cleanup.ps1') -ReportPath (Join-Path $dir 'cleanup.json')
        if ($LASTEXITCODE -eq 3) { throw 'Sandbox VM cleanup failed; stopping before next scenario' }
    }
    Save-Json $results (Join-Path $RunRoot 'host-result.json')
}
$lines=@('# Windows Sandbox E2E',"Run: $RunId",'','Raw results are in S1/out/S1 and S2/out/S2. Installer failures and harness limitations must be reviewed separately.')
[IO.File]::WriteAllLines((Join-Path $RunRoot 'summary.md'),$lines,(New-Object Text.UTF8Encoding $false))

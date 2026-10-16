param([ValidateSet('Boot','Worker')][string]$Mode='Boot',[ValidateSet('S1','S2')][string]$Scenario='S1')
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$Base='C:\e2e'
$Out=Join-Path $Base "out\$Scenario"
New-Item -ItemType Directory -Force $Out | Out-Null
function Save-Json($Object,[string]$Path) { [IO.File]::WriteAllText($Path,($Object | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding $false)) }
function Set-Phase([string]$Phase) { Save-Json ([ordered]@{scenario=$Scenario; mode=$Mode; phase=$Phase; time=(Get-Date).ToString('o')}) (Join-Path $Out 'progress.json') }
function Run-Process([string]$Exe,[string]$Arguments,[string]$Prefix,[int]$Timeout=1200,[switch]$Fresh) {
    $pi=New-Object Diagnostics.ProcessStartInfo
    $pi.FileName=$Exe; $pi.Arguments=$Arguments; $pi.UseShellExecute=$false; $pi.CreateNoWindow=$true
    $pi.RedirectStandardOutput=$true; $pi.RedirectStandardError=$true
    if ($Fresh) {
        $pi.StandardOutputEncoding=New-Object Text.UTF8Encoding $false
        $pi.StandardErrorEncoding=New-Object Text.UTF8Encoding $false
    }
    # Never let the harness's Bypass process scope contaminate the installed tools test.
    $pi.EnvironmentVariables.Remove('PSExecutionPolicyPreference')
    if ($Fresh) {
        $machine=[Environment]::GetEnvironmentVariable('Path','Machine')
        $key=Get-Item 'HKCU:\Environment'
        $user=[Environment]::ExpandEnvironmentVariables([string]$key.GetValue('Path','','DoNotExpandEnvironmentNames'))
        $pi.EnvironmentVariables['Path']="$user;$machine"
    }
    $sw=[Diagnostics.Stopwatch]::StartNew(); $p=New-Object Diagnostics.Process; $p.StartInfo=$pi
    [void]$p.Start(); $stdout=$p.StandardOutput.ReadToEndAsync(); $stderr=$p.StandardError.ReadToEndAsync()
    $limit=(Get-Date).AddSeconds($Timeout)
    while (-not $p.WaitForExit(5000) -and (Get-Date) -lt $limit) {
        Save-Json @{pid=$p.Id;exe=$Exe;elapsedSec=[int]$sw.Elapsed.TotalSeconds;time=(Get-Date).ToString('o')} "$Prefix.live.json"
        $logdir=Join-Path $env:USERPROFILE 'autofrog-kit-logs'
        $latest=Get-ChildItem $logdir -Filter 'setup-*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) { try { Copy-Item $latest.FullName "$Prefix.live-setup.log" -Force -ErrorAction Stop } catch {} }
    }
    $timedOut=-not $p.HasExited
    if ($timedOut) { & taskkill.exe /PID $p.Id /T /F 2>&1 | Out-Null; $p.WaitForExit() }
    $sw.Stop()
    [IO.File]::WriteAllText("$Prefix.stdout.log",$stdout.Result,(New-Object Text.UTF8Encoding $false))
    [IO.File]::WriteAllText("$Prefix.stderr.log",$stderr.Result,(New-Object Text.UTF8Encoding $false))
    $r=[ordered]@{exit=$p.ExitCode; sec=[math]::Round($sw.Elapsed.TotalSeconds,2); timeout=$timedOut}
    Save-Json $r "$Prefix.process.json"; return $r
}
function Run-VisibleInstall([string]$Bat,[string]$Label) {
    $prefix=Join-Path $Out $Label
    $args='-NoProfile -ExecutionPolicy Bypass -File C:\e2e\visible-install.ps1 -Bat "'+$Bat+'" -Prefix "'+$prefix+'" -Scenario '+$Scenario+' -Label '+$Label
    $p=Start-Process powershell.exe -WindowStyle Maximized -PassThru -ArgumentList $args
    $deadline=(Get-Date).AddMinutes(25)
    while (-not $p.WaitForExit(2000) -and (Get-Date) -lt $deadline) {
        $logdir=Join-Path $env:USERPROFILE 'autofrog-kit-logs'
        $latest=Get-ChildItem $logdir -Filter 'setup-*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) { try { Copy-Item $latest.FullName "$prefix.live-setup.log" -Force -ErrorAction Stop } catch {} }
        Save-Json @{pid=$p.Id;time=(Get-Date).ToString('o')} "$prefix.live.json"
    }
    if (-not $p.HasExited) { & taskkill.exe /PID $p.Id /T /F 2>&1 | Out-Null; $p.WaitForExit() }
    $result=@{exit=$p.ExitCode;timeout=$true;sec=$null}
    if (Test-Path "$prefix.exit.json") { $result=Get-Content "$prefix.exit.json" -Raw -Encoding UTF8 | ConvertFrom-Json }
    Save-Json $result "$prefix.process.json"
    return $result
}
function Run-VisibleChecks {
    $savedPath=$env:PATH;$savedPolicy=$env:PSExecutionPolicyPreference
    try {
        $machine=[Environment]::GetEnvironmentVariable('Path','Machine')
        $user=[Environment]::ExpandEnvironmentVariables([string](Get-Item 'HKCU:\Environment').GetValue('Path','','DoNotExpandEnvironmentNames'))
        $env:PATH="$user;$machine"
        Remove-Item Env:\PSExecutionPolicyPreference -ErrorAction SilentlyContinue
        $p=Start-Process powershell.exe -WindowStyle Maximized -PassThru -ArgumentList ('-NoProfile -File C:\e2e\command-check.ps1 -Scenario '+$Scenario)
    } finally {
        $env:PATH=$savedPath
        if($null -ne $savedPolicy){$env:PSExecutionPolicyPreference=$savedPolicy}
    }
    $limit=(Get-Date).AddMinutes(25)
    while(-not $p.WaitForExit(1000) -and (Get-Date) -lt $limit) {}
    $timedOut=-not $p.HasExited
    if($timedOut){ & taskkill.exe /PID $p.Id /T /F 2>&1 | Out-Null;[void]$p.WaitForExit(5000) }
    $result=@{exit=$p.ExitCode;timeout=$timedOut}
    Save-Json $result (Join-Path $Out 'command-checks.process.json')
    return $result
}
function Config-Snapshot([string]$Label) {
    $d=Join-Path $Out $Label; New-Item -ItemType Directory -Force $d | Out-Null
    $paths=[ordered]@{codex=(Join-Path $env:USERPROFILE '.codex\config.toml'); settings=(Join-Path $env:APPDATA 'Code\User\settings.json'); argv=(Join-Path $env:USERPROFILE '.vscode\argv.json')}
    $r=[ordered]@{}
    foreach ($k in $paths.Keys) { $r[$k]=[ordered]@{path=$paths[$k]; exists=(Test-Path $paths[$k])}; if ($r[$k].exists) { Copy-Item -LiteralPath $paths[$k] (Join-Path $d (Split-Path $paths[$k] -Leaf)) -Force } }
    if (Test-Path $paths.codex) {
        $lines=@(Get-Content $paths.codex -Encoding UTF8); $meaning=@($lines | Where-Object { $_.Trim() -and $_ -notmatch '^\s*#' })
        $r.codex.approvalCount=@($lines | Where-Object { $_ -match '^\s*approval_policy\s*=' }).Count
        $r.codex.sandboxCount=@($lines | Where-Object { $_ -match '^\s*sandbox_mode\s*=' }).Count
        $r.codex.topLevelCorrect=($meaning.Count -ge 2 -and $meaning[0] -eq 'approval_policy = "never"' -and $meaning[1] -eq 'sandbox_mode = "danger-full-access"')
    }
    Save-Json $r (Join-Path $d 'files.json')
}
try {
    if ($Mode -eq 'Boot') {
        Set-Phase 'sandbox-boot'
        Save-Json ([ordered]@{os=(Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber); memory=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory; winget=([bool](Get-Command winget -ErrorAction SilentlyContinue)); explorer=@(Get-Process explorer -ErrorAction SilentlyContinue | Select-Object Id,SessionId)}) (Join-Path $Out 'sandbox.json')
        $monitor=Start-Process powershell.exe -WindowStyle Hidden -PassThru -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File C:\e2e\screen-monitor.ps1 -Scenario '+$Scenario)
        if ($Scenario -eq 'S2') { $mirror=Start-Process powershell.exe -WindowStyle Maximized -PassThru -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File C:\e2e\mirror-console.ps1 -Scenario S2' }
        if ($Scenario -eq 'S1') { & $PSCommandPath -Mode Worker -Scenario S1 }
        else {
            Set-Phase 'create-standard-user'
            # Random temporary password exists only in this process and the disposable SAM.
            $password=[Guid]::NewGuid().ToString('N')+'aA!9'
            $secure=ConvertTo-SecureString $password -AsPlainText -Force
            $u=New-LocalUser -Name '수강생' -Password $secure -AccountNeverExpires
            $group=Get-LocalGroup -SID 'S-1-5-32-545'; Add-LocalGroupMember -Group $group -Member $u
            & icacls.exe C:\e2e /grant '*S-1-5-32-545:(OI)(CI)M' /T /Q | Out-Null
            $cred=New-Object Management.Automation.PSCredential("$env:COMPUTERNAME\수강생",$secure)
            Set-Phase 'launch-standard-profile'
            $p=Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -Credential $cred -LoadUserProfile -PassThru -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File C:\e2e\inside.ps1 -Mode Worker -Scenario S2'
            $password=$null; $secure=$null; $cred=$null
            if (-not $p.WaitForExit(40*60*1000)) { throw 'Standard-user worker exceeded 40 minutes' }
            Save-Json @{exit=$p.ExitCode} (Join-Path $Out 'standard-launch.json')
            if (-not (Test-Path (Join-Path $Out 'worker-done.json'))) { throw 'Standard-user worker produced no completion marker' }
        }
        if (-not (Test-Path (Join-Path $Out 'worker-done.json'))) { throw 'Worker did not complete; see error-Worker.json' }
        [IO.File]::WriteAllText((Join-Path $Out 'monitor-stop.txt'),'done');Start-Sleep 4
        Save-Json @{completed=$true;time=(Get-Date).ToString('o')} (Join-Path $Out 'done.json')
        return
    }
    if ($Scenario -eq 'S2') {
        $own=[Security.Principal.WindowsIdentity]::GetCurrent();$profileKey='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\'+$own.User.Value
        $proper=[string](Get-ItemProperty $profileKey).ProfileImagePath
        Save-Json @{inheritedProfile=$env:USERPROFILE;properProfile=$proper;identity=$own.Name} (Join-Path $Out 'profile-environment.json')
        $env:USERPROFILE=$proper;$env:USERNAME=($own.Name -split '\\')[-1]
        $env:APPDATA=Join-Path $proper 'AppData\Roaming';$env:LOCALAPPDATA=Join-Path $proper 'AppData\Local'
        $env:TEMP=Join-Path $env:LOCALAPPDATA 'Temp';$env:TMP=$env:TEMP
        New-Item -ItemType Directory -Force $env:TEMP | Out-Null
    }
    Start-Transcript -Path (Join-Path $Out 'harness.log') -Force | Out-Null
    Set-Phase 'profile-check'
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    $admin=(New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $profile=[ordered]@{identity=$id.Name;sid=$id.User.Value;admin=$admin;userProfile=$env:USERPROFILE;appData=$env:APPDATA;localAppData=$env:LOCALAPPDATA;username=$env:USERNAME;sessionId=(Get-Process -Id $PID).SessionId;desktop=[Environment]::GetFolderPath('Desktop');policies=@(Get-ExecutionPolicy -List | Select-Object @{n='scope';e={[string]$_.Scope}},@{n='policy';e={[string]$_.ExecutionPolicy}})}
    Save-Json $profile (Join-Path $Out 'profile.json')
    if ($Scenario -eq 'S2' -and ($admin -or $id.Name -notmatch '수강생$')) { throw 'Standard-user identity/admin prerequisite failed' }
    if ($Scenario -eq 'S2' -and $env:USERPROFILE -match 'WDAGUtilityAccount') { throw 'Alternate credential process inherited WDAG profile; refusing misleading test' }
    Set-Phase 'desktop-extract'
    $desktop=[Environment]::GetFolderPath('Desktop');New-Item -ItemType Directory -Force $desktop | Out-Null
    $zip=Join-Path $desktop 'autofrog-setup-kit-20261016.zip'
    Set-Phase 'copy-zip-to-desktop'
    Copy-Item (Join-Path $Base 'kit.zip') $zip -Force
    Set-Phase 'mark-zip-motw'
    Set-Content -LiteralPath $zip -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3" -Encoding ASCII
    $zone=[string]::Join("`n",[string[]]@(Get-Content -LiteralPath $zip -Stream Zone.Identifier -Encoding ASCII))
    $extract=Join-Path $desktop 'autofrog-e2e-extracted'
    Set-Phase 'expand-desktop-zip'
    $sw=[Diagnostics.Stopwatch]::StartNew(); Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force; $sw.Stop()
    $bat=Get-ChildItem $extract -Recurse -Filter '1-install.bat' | Select-Object -First 1
    if (-not $bat) { throw 'Installer batch absent after extraction' }
    $kit=$bat.Directory.FullName
    Set-Phase 'inspect-extracted-motw'
    $zones=@(Get-ChildItem $kit -Recurse -File | ForEach-Object { if (Get-Item -LiteralPath $_.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue) { $_.FullName } })
    Save-Json @{zipZone=$zone;extractSec=$sw.Elapsed.TotalSeconds;extractedZoneFiles=$zones;kit=$kit;zipSHA256=(Get-FileHash $zip -Algorithm SHA256).Hash} (Join-Path $Out 'extraction.json')
    Set-Phase 'install-1'
    $r1=Run-VisibleInstall $bat.FullName 'install-1'
    $logs=Join-Path $env:USERPROFILE 'autofrog-kit-logs'
    if (Test-Path "$logs\result-latest.json") { Copy-Item "$logs\result-latest.json" (Join-Path $Out 'result-first.json') -Force }
    Config-Snapshot 'after-first'
    Set-Phase 'fresh-powershell'
    $probe=[IO.File]::ReadAllText((Join-Path $Base 'probe.ps1'))
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($probe))
    $fresh=Run-Process 'powershell.exe' ('-NoProfile -EncodedCommand '+$encoded) (Join-Path $Out 'fresh') 600 -Fresh
    try { $j=Get-Content (Join-Path $Out 'fresh.stdout.log') -Raw -Encoding UTF8 | ConvertFrom-Json; Save-Json $j (Join-Path $Out 'fresh.json') } catch {}
    Set-Phase 'command-checks'
    $commandChecks=Run-VisibleChecks
    Set-Phase 'explorer-environment'
    $explorerCmd=Join-Path $Out 'explorer-check.cmd'
    $cmdText="@echo off`r`nchcp 65001 >nul`r`nwhoami > C:\e2e\out\$Scenario\explorer-environment.txt 2>&1`r`nwhere.exe claude >> C:\e2e\out\$Scenario\explorer-environment.txt 2>&1`r`necho claude-exit=%%ERRORLEVEL%% >> C:\e2e\out\$Scenario\explorer-environment.txt`r`nwhere.exe codex >> C:\e2e\out\$Scenario\explorer-environment.txt 2>&1`r`necho codex-exit=%%ERRORLEVEL%% >> C:\e2e\out\$Scenario\explorer-environment.txt`r`nwhere.exe vercel >> C:\e2e\out\$Scenario\explorer-environment.txt 2>&1`r`necho vercel-exit=%%ERRORLEVEL%% >> C:\e2e\out\$Scenario\explorer-environment.txt`r`necho PATH=%%PATH%% >> C:\e2e\out\$Scenario\explorer-environment.txt`r`necho done > C:\e2e\out\$Scenario\explorer-complete.txt`r`n"
    $cmdText=$cmdText.Replace('%%','%'); [IO.File]::WriteAllText($explorerCmd,$cmdText,[Text.Encoding]::ASCII)
    $explorerArgs='"'+$explorerCmd+'"'
    if ($Scenario -eq 'S2') { $explorerArgs='/separate,'+$explorerArgs }
    $exp=Start-Process explorer.exe -ArgumentList $explorerArgs -PassThru
    $deadline=(Get-Date).AddSeconds(60)
    while (-not (Test-Path (Join-Path $Out 'explorer-complete.txt')) -and (Get-Date) -lt $deadline) { Start-Sleep 2 }
    Save-Json @{completed=(Test-Path (Join-Path $Out 'explorer-complete.txt'));requestedIdentity=$id.Name;launcherPid=$exp.Id;arguments=$explorerArgs} (Join-Path $Out 'explorer.json')
    Set-Phase 'login-check'
    $login=Run-Process $env:ComSpec ('/d /c ""'+(Join-Path $kit '2-login.bat')+'" /check"') (Join-Path $Out 'login') 180
    if (Test-Path "$logs\login-latest.json") { Copy-Item "$logs\login-latest.json" (Join-Path $Out 'login-latest.json') -Force }
    Set-Phase 'install-2'
    $r2=Run-VisibleInstall $bat.FullName 'install-2'
    if (Test-Path "$logs\result-latest.json") { Copy-Item "$logs\result-latest.json" (Join-Path $Out 'result-second.json') -Force }
    Config-Snapshot 'after-second'
    if (Test-Path $logs) { Copy-Item $logs (Join-Path $Out 'autofrog-kit-logs') -Recurse -Force }
    Save-Json @{install1=$r1;install2=$r2;fresh=$fresh;commandChecks=$commandChecks;login=$login;complete=$true} (Join-Path $Out 'worker-done.json')
    Set-Phase 'complete'
    Stop-Transcript | Out-Null
} catch {
    Save-Json @{message=$_.Exception.Message;position=$_.InvocationInfo.PositionMessage;stack=$_.ScriptStackTrace;time=(Get-Date).ToString('o');mode=$Mode} (Join-Path $Out ("error-$Mode.json"))
    if ($Mode -eq 'Boot') { [IO.File]::WriteAllText((Join-Path $Out 'monitor-stop.txt'),'error');Start-Sleep 4; Save-Json @{completed=$false;error=$_.Exception.Message} (Join-Path $Out 'done.json') }
    else { try { Stop-Transcript | Out-Null } catch {} }
}

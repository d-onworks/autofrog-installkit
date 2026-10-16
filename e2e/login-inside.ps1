# 로그인 E2E — 샌드박스 안에서: zip 풀기 → 1-install.bat /auto → 2-login.bat 을 진짜 창으로 띄우고 콘솔 다리를 붙인다.
# 키 입력과 브라우저 승인은 바깥(맥)에서 넣는다. 로그인 창이 닫히면 상태표를 다시 찍어 남긴다.
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$Base='C:\e2e'
$Out=Join-Path $Base 'out\L1'
New-Item -ItemType Directory -Force $Out | Out-Null
function Save-Json($Object,[string]$Path) { [IO.File]::WriteAllText($Path,($Object | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding $false)) }
function Set-Phase([string]$Phase) { Save-Json ([ordered]@{phase=$Phase; time=(Get-Date).ToString('o')}) (Join-Path $Out 'progress.json') }
try {
    Set-Phase 'extract'
    $desktop=[Environment]::GetFolderPath('Desktop'); New-Item -ItemType Directory -Force $desktop | Out-Null
    $zip=Join-Path $desktop 'autofrog-setup-kit-20261016.zip'
    Copy-Item (Join-Path $Base 'kit.zip') $zip -Force
    Set-Content -LiteralPath $zip -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3" -Encoding ASCII
    Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $desktop 'kit') -Force
    $bat=Get-ChildItem (Join-Path $desktop 'kit') -Recurse -Filter '1-install.bat' | Select-Object -First 1
    $kit=$bat.Directory.FullName
    Save-Json @{kit=$kit;zipSHA256=(Get-FileHash $zip -Algorithm SHA256).Hash} (Join-Path $Out 'extraction.json')

    Set-Phase 'install'
    $prefix=Join-Path $Out 'install'
    $p=Start-Process powershell.exe -WindowStyle Maximized -PassThru -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File C:\e2e\visible-install.ps1 -Bat "'+$bat.FullName+'" -Prefix "'+$prefix+'" -Scenario L1 -Label install')
    if (-not $p.WaitForExit(30*60*1000)) { throw 'install exceeded 30 minutes' }
    $logs=Join-Path $env:USERPROFILE 'autofrog-kit-logs'
    if (Test-Path "$logs\result-latest.json") { Copy-Item "$logs\result-latest.json" (Join-Path $Out 'install-result.json') -Force }

    Set-Phase 'login'
    # 수강생이 탐색기에서 두 번 누른 것과 같게: 하네스의 Bypass 환경변수는 넘기지 않는다
    Remove-Item Env:\PSExecutionPolicyPreference -ErrorAction SilentlyContinue
    # 승인이 늦어 코드가 만료되면 다시 돌린다: 창이 닫힌 뒤 30분 안에 again.req 가 오면 2-login.bat 을 새로 연다
    $round=0
    do {
        $round++
        Set-Phase "login-$round"
        $login=Start-Process cmd.exe -WindowStyle Maximized -PassThru -WorkingDirectory $kit -ArgumentList ('/d /c ""'+(Join-Path $kit '2-login.bat')+'""')
        Start-Sleep 1
        $bridge=Start-Process powershell.exe -WindowStyle Hidden -PassThru -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File C:\e2e\console-bridge.ps1 -TargetPid '+$login.Id+' -Out '+$Out)
        Save-Json @{round=$round;loginPid=$login.Id;bridgePid=$bridge.Id} (Join-Path $Out 'login-procs.json')
        if (-not $login.WaitForExit(60*60*1000)) { throw 'login window exceeded 60 minutes' }
        Copy-Item (Join-Path $Out 'console.txt') (Join-Path $Out "console-round$round.txt") -Force -ErrorAction SilentlyContinue
        Set-Phase "login-$round-closed"
        $again=Join-Path $Out 'again.req'; $limit=(Get-Date).AddMinutes(30)
        while (-not (Test-Path $again) -and -not (Test-Path (Join-Path $Out 'finish.req')) -and (Get-Date) -lt $limit) { Start-Sleep 3 }
        $retry=Test-Path $again; Remove-Item $again -Force -ErrorAction SilentlyContinue
    } while ($retry)

    Set-Phase 'after-login-check'
    $ErrorActionPreference='Continue'
    $chk=Join-Path $Out 'check'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit 'scripts\login.ps1') -CheckOnly *> "$chk.log"
    if (Test-Path "$logs\login-latest.json") { Copy-Item "$logs\login-latest.json" (Join-Path $Out 'login-latest.json') -Force }
    $machine=[Environment]::GetEnvironmentVariable('Path','Machine'); $user=[Environment]::GetEnvironmentVariable('Path','User'); $env:PATH="$user;$machine"
    $extra=[ordered]@{}
    foreach ($c in @(@('gh',@('auth','status')),@('git',@('config','--global','--get-regexp','^(credential|user)\.')),@('vercel.cmd',@('whoami')),@('supabase',@('projects','list')))) {
        $o=& $c[0] @($c[1]) 2>&1 | ForEach-Object { "$_" }
        $extra[($c[0]+' '+($c[1] -join ' '))]=@{exit=$LASTEXITCODE;out=($o -join "`n")}
    }
    Save-Json $extra (Join-Path $Out 'after-login.json')
    Save-Json @{completed=$true;time=(Get-Date).ToString('o')} (Join-Path $Out 'done.json')
    Set-Phase 'complete'
} catch {
    Save-Json @{message=$_.Exception.Message;position=$_.InvocationInfo.PositionMessage;time=(Get-Date).ToString('o')} (Join-Path $Out 'error.json')
    Set-Phase 'error'
}

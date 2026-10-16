$ErrorActionPreference = 'Stop'
$ErrorActionPreference = 'Continue'
$q = (& query.exe user 2>&1 | Out-String)
$exitCode=$LASTEXITCODE
$active = ($q -match '(?m)오토프로그\s+.*\s(Active|활성)\s')
$o = [ordered]@{time=(Get-Date).ToString('o'); exitCode=$exitCode; regexMatch=($q -match '(?m)오토프로그\s+.*\s(Active|활성)\s'); query=$q; active=$active; sandboxExe=(Test-Path "$env:WINDIR\System32\WindowsSandbox.exe"); wsb=(Get-Command wsb.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source); sandboxProcesses=@(Get-Process WindowsSandbox* -ErrorAction SilentlyContinue | Select-Object Name,Id,SessionId)}
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($o | ConvertTo-Json -Depth 5 -Compress)))

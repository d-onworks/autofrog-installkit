$ErrorActionPreference='Continue'
$o=@{time=(Get-Date).ToString('o');hcs=@(& hcsdiag.exe list 2>&1 | ForEach-Object { "$_" });vm=@(Get-Process vmmemWindowsSandbox -ErrorAction SilentlyContinue | Select-Object Name,Id);sandbox=@(Get-Process WindowsSandbox* -ErrorAction SilentlyContinue | Select-Object Name,Id,SessionId)}
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($o | ConvertTo-Json -Depth 5 -Compress)))

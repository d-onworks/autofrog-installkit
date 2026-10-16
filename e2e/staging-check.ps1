$p=Join-Path $PSScriptRoot 'autofrog-setup-kit-20261016.zip'
$o=@{zipBytes=(Get-Item $p).Length;sha256=(Get-FileHash $p -Algorithm SHA256).Hash;tasks=@(Get-ScheduledTask | Where-Object TaskName -like 'AutoFrogE2E-*' | Select-Object TaskName,State);sandbox=@(Get-Process WindowsSandbox* -ErrorAction SilentlyContinue | Select-Object Name,Id,SessionId)}
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($o | ConvertTo-Json -Depth 6 -Compress)))

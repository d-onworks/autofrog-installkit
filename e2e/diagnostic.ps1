$ErrorActionPreference='Continue'
$o=[ordered]@{time=(Get-Date).ToString('o');processes=@(Get-Process powershell,cmd,tar,Git*,node,Code* -ErrorAction SilentlyContinue | Select-Object Name,Id,CPU,WorkingSet,StartTime);desktop=@(Get-ChildItem C:\Users\WDAGUtilityAccount\Desktop -Recurse -File | Select-Object FullName,Length,LastWriteTime);logs=@(Get-ChildItem C:\Users\WDAGUtilityAccount\autofrog-kit-logs -ErrorAction SilentlyContinue | Select-Object Name,Length,LastWriteTime)}
$latest=Get-ChildItem C:\Users\WDAGUtilityAccount\autofrog-kit-logs -Filter 'setup*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latest) { $o.tail=@(Get-Content $latest.FullName -Tail 20 -Encoding UTF8) }
[IO.File]::WriteAllText('C:\e2e\diagnostic.json',($o | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding $false))

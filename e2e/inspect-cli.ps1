$ErrorActionPreference='Continue'
$app=Get-AppxPackage -AllUsers '*WindowsSandbox*' | Select-Object -First 1
$files=@(Get-ChildItem $app.InstallLocation -Filter '*.exe' | Select-Object Name,FullName)
$cli=Get-ChildItem $app.InstallLocation -Filter 'wsb.exe' -Recurse | Select-Object -First 1
$help=@(); if ($cli) { $help=@(& $cli.FullName --help 2>&1 | ForEach-Object { "$_" }) }
$o=@{files=$files;cli=$cli.FullName;help=$help}
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($o | ConvertTo-Json -Depth 6 -Compress)))

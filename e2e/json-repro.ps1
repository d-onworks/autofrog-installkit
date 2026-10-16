$p='C:\AutoFrogE2E\preflight.ps1'
$rich=Get-Content $p -Raw
$plain=[IO.File]::ReadAllText($p)
$sw=[Diagnostics.Stopwatch]::StartNew();$j=$rich | ConvertTo-Json -Depth 2 -Compress;$sw.Stop()
$o=@{richProperties=@($rich.PSObject.Properties.Name);plainProperties=@($plain.PSObject.Properties.Name);depth2Length=$j.Length;sec=$sw.Elapsed.TotalSeconds;richSerializesObject=$j.StartsWith('{');plainSerializesString=(($plain | ConvertTo-Json -Depth 2 -Compress).StartsWith('"'))}
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($o | ConvertTo-Json -Depth 5 -Compress)))

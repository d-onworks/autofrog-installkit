param([string]$Action='list',[string]$SandboxId='')
$ErrorActionPreference='Stop'
$cli=(Get-AppxPackage '*WindowsSandbox*' | Select-Object -First 1).InstallLocation+'\wsb.exe'
$pi=New-Object Diagnostics.ProcessStartInfo; $pi.FileName=$cli; $pi.UseShellExecute=$false; $pi.RedirectStandardOutput=$true; $pi.RedirectStandardError=$true
if ($Action -eq 'list') { $pi.Arguments='list --raw' }
elseif ($Action -eq 'exec') { $pi.Arguments='exec --id '+$SandboxId+' -r ExistingLogin -c "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\e2e\diagnostic-stack.ps1"' }
else { throw 'Unsupported action' }
$p=New-Object Diagnostics.Process;$p.StartInfo=$pi;[void]$p.Start();$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
$done=$p.WaitForExit(30000)
@{exit=$p.ExitCode;done=$done;stdout=$stdout.Result;stderr=$stderr.Result} | ConvertTo-Json -Depth 6 | Set-Content "C:\AutoFrogE2E\20261016-092855\cli-$Action.json" -Encoding UTF8

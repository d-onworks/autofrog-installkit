$ErrorActionPreference='Stop'
try {
 $ci=New-Object Management.Automation.Runspaces.NamedPipeConnectionInfo(6624)
 $rs=[Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($ci);$rs.Open()
 $ps=[powershell]::Create();$ps.Runspace=$rs
 [void]$ps.AddScript("Get-Runspace | ForEach-Object { [pscustomobject]@{id=`$_.Id;state=[string]`$_.RunspaceAvailability;stack=@(`$_.Debugger.GetCallStack() | Select-Object Command,Location,ScriptName,ScriptLineNumber)} } | ConvertTo-Json -Depth 8")
 $v=$ps.Invoke() | Out-String
 $v | Set-Content C:\e2e\diagnostic-stack.json -Encoding UTF8
 $ps.Dispose();$rs.Dispose()
} catch { $_.Exception.Message | Set-Content C:\e2e\diagnostic-stack-error.txt -Encoding UTF8 }

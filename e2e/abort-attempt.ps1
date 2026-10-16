$ErrorActionPreference='Stop'
$o=@{completed=$false;harnessAbort=$true;reason='PowerShell 5.1 Get-Content Raw string carries provider metadata; ConvertTo-Json Depth 18 traversed metadata. No kit install started. Restart with ReadAllText and Depth 8.';time=(Get-Date).ToString('o')}
$o | ConvertTo-Json | Set-Content C:\AutoFrogE2E\20261016-092855\S1\out\S1\done.json -Encoding UTF8

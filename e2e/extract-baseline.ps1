$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$r='C:\AutoFrogE2E\20261016-1030-r1b'
$z=[IO.Compression.ZipFile]::OpenRead("$r\S1\kit.zip")
try {
 $entry=$z.Entries | Where-Object FullName -like '*/scripts/setup.ps1' | Select-Object -First 1
 $reader=New-Object IO.StreamReader($entry.Open(),[Text.Encoding]::UTF8)
 try { [IO.File]::WriteAllText("$r\setup-before.ps1",$reader.ReadToEnd(),(New-Object Text.UTF8Encoding $false)) } finally { $reader.Dispose() }
} finally { $z.Dispose() }

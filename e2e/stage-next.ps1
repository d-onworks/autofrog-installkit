$ErrorActionPreference='Stop'
$r='C:\AutoFrogE2E'
if(Get-Process WindowsSandbox*,vmmemWindowsSandbox -ErrorAction SilentlyContinue){throw 'Sandbox still running'}
Copy-Item "$r\autofrog-setup-kit-20261016-next.zip" "$r\autofrog-setup-kit-20261016.zip" -Force
(Get-FileHash "$r\autofrog-setup-kit-20261016.zip" -Algorithm SHA256).Hash

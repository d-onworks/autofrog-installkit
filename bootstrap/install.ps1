# AutoFrog setup kit - Windows one-line installer.
#   Open PowerShell (Win key -> powershell -> Enter, NOT as administrator), then paste:
#     irm https://autofrog.kr/kit.ps1 | iex
#   Win+R:  powershell -NoProfile -ExecutionPolicy Bypass -NoExit -c "irm https://autofrog.kr/kit.ps1 -OutFile $env:TEMP\af.ps1; & $env:TEMP\af.ps1"
#   (autofrog.kr/kit.ps1 redirects to releases/latest/download/install.ps1 of this repository)
#
# Why one line instead of zip + 1-install.bat (2026-10-21):
#   Smart App Control turns itself on for new / freshly installed Windows 11 PCs and then blocks
#   double-clicking a .bat that carries the "downloaded from the internet" mark (every file unzipped
#   from a browser download). Files fetched by PowerShell carry no mark, and .ps1 run through
#   powershell -File is not blocked (measured on a Smart App Control PC, 2026-10-21).
#
# What it does: download the latest kit zip -> unpack to %LOCALAPPDATA%\AutoFrogKit\kit -> run
#   scripts\setup.ps1 -OneLiner in this window (setup.ps1 shows the Korean UI, makes the desktop
#   login shortcut and offers to continue with login). Safe to run again.
# Test switches: AUTOFROG_KIT_ZIP (zip URL or path) / AUTOFROG_AUTO=1 (no questions, for E2E).
#
# KEEP THIS FILE ASCII-ONLY. Windows PowerShell 5.1 "irm" decodes a response without a charset
# (GitHub releases and Vercel send application/octet-stream) as ISO-8859-1, so any Korean here
# would turn into garbage, and a UTF-8 BOM becomes a stray first token. Korean text lives in setup.ps1.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ZipUrl = if ($env:AUTOFROG_KIT_ZIP) { $env:AUTOFROG_KIT_ZIP } else { 'https://github.com/d-onworks/autofrog-installkit/releases/latest/download/autofrog-setup-kit.zip' }
$Auto = ($env:AUTOFROG_AUTO -eq '1')
$KitHome = Join-Path $env:LOCALAPPDATA 'AutoFrogKit'
$Dest = Join-Path $KitHome 'kit'
$PS = Join-Path $PSHOME 'powershell.exe'

Write-Host ''
Write-Host '  AutoFrog setup kit - downloading (internet connection needed) ...' -ForegroundColor Green
$tmp = Join-Path $env:TEMP ('autofrog-kit-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
$ok = $false
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $zip = Join-Path $tmp 'kit.zip'
    if (Test-Path -LiteralPath $ZipUrl) { Copy-Item -LiteralPath $ZipUrl $zip }
    else { Invoke-WebRequest -Uri $ZipUrl -OutFile $zip -UseBasicParsing }
    Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $tmp 'x') -Force
    $setup = Get-ChildItem (Join-Path $tmp 'x') -Recurse -Filter 'setup.ps1' | Select-Object -First 1
    if (-not $setup) { throw 'setup.ps1 not found in the downloaded kit' }
    if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
    New-Item -ItemType Directory -Force $KitHome | Out-Null
    Move-Item $setup.Directory.Parent.FullName $Dest
    # Drop the internet mark if one came along (a marked .bat is what Smart App Control blocks).
    Get-ChildItem $Dest -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
    $ok = $true
} catch {
    Write-Host ''
    Write-Host "  [FAIL] Could not download the setup kit: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '  Check the internet connection and run the same line again.' -ForegroundColor Yellow
    Write-Host '  If it keeps failing, capture this window (Win+Shift+S) and show it to the instructor.' -ForegroundColor Yellow
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($ok) {
    $setupArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Dest 'scripts\setup.ps1'), '-OneLiner')
    if ($Auto) { $setupArgs += '-Auto' }
    & $PS @setupArgs
    $global:LASTEXITCODE = $LASTEXITCODE
    # Load the new PATH into this window too, so claude / codex work here right away.
    try {
        $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $u = [Environment]::GetEnvironmentVariable('Path', 'User')
        $env:Path = "$u;$m"
    } catch {}
} elseif (-not $Auto) {
    [void](Read-Host '  Press Enter to finish')
}

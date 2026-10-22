@echo off
setlocal
rem AutoFrog setup kit - zip version (2026-10-22). ASCII only: cmd reads .bat in the local code page.
rem For PCs where the one-line command (irm ... | iex) is stopped by antivirus software.
rem New PCs with Smart App Control may block this file instead - then use the one-line command.
if not exist "%~dp0scripts\setup.ps1" (
  echo.
  echo  [!] Please extract the zip first: right-click the zip ^> Extract All, then run this file again.
  echo.
  pause
  exit /b 2
)
set "PSARGS=-OneLiner"
if /i "%~1"=="/auto" set "PSARGS=-Auto"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup.ps1" %PSARGS%
exit /b %ERRORLEVEL%

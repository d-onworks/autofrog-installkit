@echo off
setlocal
rem AutoFrog setup kit - login wizard (browser approval is done by the person)
if not exist "%~dp0scripts\login.ps1" (
  echo  [!] Please extract the zip first.
  pause
  exit /b 2
)
set "PSARGS="
if /i "%~1"=="/check" set "PSARGS=-CheckOnly"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\login.ps1" %PSARGS%
set "RC=%ERRORLEVEL%"
if not defined PSARGS pause
exit /b %RC%

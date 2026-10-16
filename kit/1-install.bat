@echo off
setlocal
rem AutoFrog setup kit - run everything (ASCII only: cmd reads .bat in the local code page)
if not exist "%~dp0scripts\setup.ps1" (
  echo.
  echo  [!] Please extract the zip first: right-click the zip ^> Extract All, then run this file again.
  echo.
  pause
  exit /b 2
)
set "PSARGS="
if /i "%~1"=="/auto" set "PSARGS=-Auto"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup.ps1" %PSARGS%
set "RC=%ERRORLEVEL%"
if not defined PSARGS pause
exit /b %RC%

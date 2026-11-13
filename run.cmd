@echo off
rem ============================================================
rem  Network Operations Center - mo dashboard nhu mot app tren Windows
rem  Bam dup vao file nay, hoac chay:  run.cmd
rem  Cua so Edge/Chrome che do --app: khong thanh dia chi, khong tab.
rem ============================================================
setlocal enabledelayedexpansion

set "PAGE=%~dp0index.html"
if not exist "%PAGE%" (
  echo Khong tim thay index.html canh file nay.
  pause
  exit /b 1
)

rem duong dan Windows -> URL file:///C:/...
set "URL=file:///!PAGE:\=/!"
rem duong dan co dau cach -> ma hoa thanh %%20
set "URL=!URL: =%%20!"
set "OPTS=--window-size=1480,920"

set "BROWSER="
for %%P in (
  "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
  "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
  "%ProgramFiles%\Google\Chrome\Application\chrome.exe"
  "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
  "%LocalAppData%\Google\Chrome\Application\chrome.exe"
  "%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe"
) do (
  if not defined BROWSER if exist %%P set "BROWSER=%%~P"
)

if defined BROWSER (
  start "" "!BROWSER!" --app="!URL!" %OPTS%
) else (
  echo Khong tim thay Edge/Chrome/Brave - mo bang trinh duyet mac dinh.
  start "" "%PAGE%"
)
exit /b 0

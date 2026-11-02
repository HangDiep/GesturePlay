@echo off
setlocal
node "%~dp0scripts\run-windows.mjs" %*
set "GESTUREPLAY_EXIT=%ERRORLEVEL%"
if not "%GESTUREPLAY_EXIT%"=="0" pause
exit /b %GESTUREPLAY_EXIT%

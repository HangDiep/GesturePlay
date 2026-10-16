@echo off
setlocal
chcp 65001 >nul
set "GESTUREPLAY_PROJECT=%~dp0."
pushd "%~dp0flutter_app"
where flutter >nul 2>nul
if errorlevel 1 (
    echo Chưa tìm thấy Flutter trong PATH. Xem README.md.
    pause
    popd
    exit /b 1
)
call flutter run -d windows "--dart-define=GESTUREPLAY_ROOT=%GESTUREPLAY_PROJECT%" %*
set "GESTUREPLAY_EXIT=%ERRORLEVEL%"
if not "%GESTUREPLAY_EXIT%"=="0" pause
popd
exit /b %GESTUREPLAY_EXIT%

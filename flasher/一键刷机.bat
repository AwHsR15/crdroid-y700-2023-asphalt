@echo off
REM ===========================================================================
REM  One-click flasher launcher for Lenovo Legion Y700 2023 (asphalt)
REM  This file is intentionally ASCII-only so it renders correctly on any
REM  Windows locale. All UI text lives in flash.ps1 (UTF-8 with BOM).
REM ===========================================================================
setlocal
cd /d "%~dp0"

REM Use UTF-8 in the console so the Chinese output in flash.ps1 renders.
chcp 65001 >nul 2>&1

if not exist "%~dp0flash.ps1" (
    echo.
    echo   ERROR: flash.ps1 not found next to this file.
    echo   Please keep the whole folder together and run this again.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0flash.ps1"
set RC=%ERRORLEVEL%

if not "%RC%"=="0" (
    echo.
    echo   Script exited with code %RC%
    echo.
    pause
)

endlocal

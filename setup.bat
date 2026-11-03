@echo off
title mybot setup
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
if errorlevel 1 (
  echo.
  echo Setup stopped because of an error. Read the message above.
)
pause

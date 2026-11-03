@echo off
title mybot cleanup
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0clean-mybot.ps1" %*
pause

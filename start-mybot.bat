@echo off
cd /d "%~dp0"
bun run dev
if errorlevel 1 pause

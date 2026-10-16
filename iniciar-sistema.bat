@echo off
title SCADA - Bancada de Pressao Hidrostatica
cd /d "%~dp0"
echo Iniciando ambiente SCADA no Windows...
powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
pause

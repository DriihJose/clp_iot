@echo off
title SCADA - Bancada de Pressao Hidrostatica
:: Localiza a raiz do projeto (dois niveis acima de scripts\windows)
set "PROJECT_ROOT=%~dp0..\.."
cd /d "%PROJECT_ROOT%"

echo =================================================================
echo   INICIANDO AMBIENTE SCADA NO WINDOWS (100%% OFFLINE)
echo   Diretorio Raiz: %CD%
echo =================================================================
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1"
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] Ocorreu uma falha durante a execucao do setup.
)
echo.
pause

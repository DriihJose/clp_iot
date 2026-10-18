@echo off
title Parar SCADA - Bancada de Pressao Hidrostatica
set "PROJECT_ROOT=%~dp0..\.."
cd /d "%PROJECT_ROOT%"

echo =================================================================
echo   PARANDO CONTEINERES DO DOCKER...
echo   Diretorio Raiz: %CD%
echo =================================================================
echo.
docker compose -f docker-compose.windows.yml down
echo.
echo =================================================================
echo   Todos os servicos SCADA foram finalizados com sucesso!
echo =================================================================
echo.
pause

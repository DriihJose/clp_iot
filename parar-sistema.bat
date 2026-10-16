@echo off
title Parar SCADA - Bancada de Pressao Hidrostatica
cd /d "%~dp0"
echo Parando conteineres do Docker...
docker compose -f docker-compose.windows.yml down
echo.
echo Todos os servicos foram finalizados com sucesso!
pause

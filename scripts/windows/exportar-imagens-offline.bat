@echo off
title Exportar Imagens Docker para Uso 100% Offline
set "PROJECT_ROOT=%~dp0..\.."
cd /d "%PROJECT_ROOT%"

echo =================================================================
echo   EXPORTANDO IMAGENS DOCKER PARA INSTALACAO 100%% OFFLINE
echo   Destino: %CD%\imagens-offline.tar
echo =================================================================
echo.
echo Salvando clp_iot-nodered:latest, influxdb:2.7 e grafana/grafana:latest em imagens-offline.tar...
docker save -o "%CD%\imagens-offline.tar" clp_iot-nodered:latest influxdb:2.7 grafana/grafana:latest
if %errorlevel% equ 0 (
    echo.
    echo =================================================================
    echo   [SUCESSO] Arquivo 'imagens-offline.tar' gerado com sucesso!
    echo   Basta copiar a pasta do projeto junto com 'imagens-offline.tar'
    echo   para qualquer maquina sem internet e executar iniciar-sistema.bat.
    echo =================================================================
) else (
    echo.
    echo =================================================================
    echo   [ERRO] Falha ao exportar as imagens do Docker.
    echo   Verifique se o Docker Desktop esta aberto e as imagens existem.
    echo =================================================================
)
echo.
pause

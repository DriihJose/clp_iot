@echo off
title Exportar Imagens Docker para Uso 100% Offline
cd /d "%~dp0"
if exist clp_iot-main (
    cd clp_iot-main
)
echo =================================================================
echo   EXPORTANDO IMAGENS DOCKER PARA INSTALACAO 100% OFFLINE
echo =================================================================
echo.
echo Salvando clp_iot-nodered:latest, influxdb:2.7 e grafana/grafana:latest em imagens-offline.tar...
docker save -o imagens-offline.tar clp_iot-nodered:latest influxdb:2.7 grafana/grafana:latest
if %errorlevel% equ 0 (
    echo.
    echo [SUCESSO] Arquivo 'imagens-offline.tar' gerado com sucesso!
    echo Basta copiar a pasta do projeto (junto com imagens-offline.tar) para
    echo qualquer maquina Windows/Linux sem internet e executar iniciar-sistema.bat.
) else (
    echo.
    echo [ERRO] Falha ao exportar as imagens do Docker. Verifique se o Docker Desktop esta aberto.
)
echo.
pause

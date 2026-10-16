@echo off
title Enviar alteracoes para o GitHub
cd /d "%~dp0"
echo =================================================================
echo   SINCRONIZANDO COM O GITHUB (https://github.com/DriihJose/clp_iot)
echo =================================================================
echo.
echo Enviando commit para origin main...
git push origin main
if %errorlevel% equ 0 (
    echo.
    echo =================================================================
    echo   [SUCESSO] GitHub atualizado com sucesso na branch main!
    echo =================================================================
) else (
    echo.
    echo =================================================================
    echo   [AUTENTICACAO] Caso uma janela do navegador tenha sido aberta,
    echo   autorize o Git Credential Manager com sua conta do GitHub.
    echo =================================================================
)
echo.
pause

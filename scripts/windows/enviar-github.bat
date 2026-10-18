@echo off
title Enviar alteracoes para o GitHub
set "PROJECT_ROOT=%~dp0..\.."
cd /d "%PROJECT_ROOT%"

echo =================================================================
echo   SINCRONIZANDO COM O GITHUB (https://github.com/DriihJose/clp_iot)
echo   Diretorio Raiz: %CD%
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
    echo   [AUTENTICACAO / ERRO] Verifique sua conexao ou autorize
    echo   o Git Credential Manager com sua conta do GitHub.
    echo =================================================================
)
echo.
pause

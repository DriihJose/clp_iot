@echo off
title Enviar alteracoes para o GitHub
cd /d "%~dp0"
call "%~dp0scripts\windows\enviar-github.bat"

#!/bin/bash
set -e

# Garante a existência do diretório interno de relatórios
mkdir -p /data/relatorios

# Verificação de dependências em ambiente 100% offline
# Assegura que o pacote crítico ethernet-ip está presente sem disparar downloads externos
if [ ! -d "/data/node_modules/ethernet-ip" ] && [ -f "/data/package.json" ]; then
    echo "[auto-install] Pasta node_modules/ethernet-ip não encontrada em /data."
    if [ -d "/data/.npm" ]; then
        echo "[auto-install] Restaurando dependências a partir do cache local (.npm) em modo 100% offline..."
        (cd /data && npm install --offline --no-audit --no-fund --no-update-notifier) || true
    else
        echo "[AVISO OFFLINE] node_modules não encontrado e sem acesso à internet. Mantenha a pasta node_modules existente no projeto."
    fi
fi

# Executa o entrypoint padrão da imagem oficial do Node-RED
exec /usr/src/node-red/entrypoint.sh "${@}"


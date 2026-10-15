#!/bin/bash
set -e

# Garante a existência do diretório interno de relatórios
mkdir -p /data/relatorios

# Auto-instalação de dependências em máquinas novas (cenário de git clone)
# Como a pasta node_modules é ignorada pelo Git, verifica se o pacote crítico ethernet-ip existe;
# se não existir, executa o npm install antes do Node-RED iniciar.
if [ ! -d "/data/node_modules/ethernet-ip" ] && [ -f "/data/package.json" ]; then
    echo "[auto-install] Instalando dependencias do Node-RED em /data..."
    (cd /data && npm install --no-audit --no-fund --no-update-notifier)
fi

# Executa o entrypoint padrão da imagem oficial do Node-RED
exec /usr/src/node-red/entrypoint.sh "${@}"

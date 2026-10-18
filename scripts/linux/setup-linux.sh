#!/bin/bash
set -e

echo "================================================================="
echo "   INICIALIZACAO DO SISTEMA SCADA / IoT - BANCADA DE PRESSAO     "
echo "                      Ambiente: Linux / Ubuntu                   "
echo "================================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../../docker-compose.yml" ]; then
    ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
    ROOT_DIR="$SCRIPT_DIR"
fi
cd "$ROOT_DIR"

echo "Diretorio Raiz do Projeto: $ROOT_DIR"

# 1. Configuracao do arquivo de ambiente (.env)
if [ ! -f ".env" ]; then
    echo "[1/5] Arquivo .env nao encontrado. Criando a partir de .env.example..."
    cp .env.example .env
    echo "       .env criado com sucesso."
else
    echo "[1/5] Arquivo .env ja existe. Mantendo configuracoes atuais."
fi

# 2. Criacao e ajuste de permissoes das pastas locais
echo "[2/5] Verificando e criando pastas locais..."
mkdir -p nodered_data relatorios grafana_data influxdb_data influxdb_config

# Ajuste de permissoes (se executado com sudo ou permissao disponivel)
if command -v sudo >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
    echo "       Ajustando permissoes de pastas via sudo..."
    sudo chown -R 1000:1000 nodered_data relatorios 2>/dev/null || true
    sudo chown -R 472:472 grafana_data 2>/dev/null || true
else
    chown -R 1000:1000 nodered_data relatorios 2>/dev/null || true
    chown -R 472:472 grafana_data 2>/dev/null || true
fi

# 3. Configuracao de Rede Cabeada para o CLP Micro850 (192.168.1.100/24)
echo "[3/5] Verificando configuracao de rede fisica para o CLP..."
if command -v nmcli >/dev/null 2>&1; then
    ETH_CON=$(nmcli -t -f NAME,TYPE con show --active | grep ethernet | head -n1 | cut -d: -f1 || true)
    if [ -z "$ETH_CON" ]; then
        ETH_CON=$(nmcli -t -f NAME,TYPE con show | grep -E 'Perfil 1|netplan-enp|Wired|Cabeada' | head -n1 | cut -d: -f1 || true)
    fi

    if [ -n "$ETH_CON" ]; then
        echo "       Configurando perfil de rede '$ETH_CON' com IP estatico 192.168.1.100/24 sem gateway..."
        nmcli con modify "$ETH_CON" \
            ipv4.method manual \
            ipv4.addresses 192.168.1.100/24 \
            ipv4.gateway "" \
            ipv4.never-default yes \
            ipv4.route-metric 100 \
            connection.autoconnect yes 2>/dev/null || true
        nmcli con up "$ETH_CON" 2>/dev/null || true
    else
        echo "       [AVISO] Nenhuma conexao cabeada especifica encontrada pelo nmcli. Verifique se o cabo esta conectado."
    fi
else
    echo "       [AVISO] nmcli nao disponivel neste ambiente. Certifique-se de que o IP 192.168.1.100/24 esta configurado."
fi

# Teste rapido de ping ao CLP
echo "       Testando conectividade com o CLP Micro850 (192.168.1.33)..."
if ping -c 2 -W 1 192.168.1.33 >/dev/null 2>&1; then
    echo "       [OK] CLP 192.168.1.33 respondeu ao ping com sucesso!"
else
    echo "       [INFO] CLP 192.168.1.33 ainda nao respondeu ao ping (verifique o cabo e se o CLP esta ligado)."
fi

# 4. Inicializacao dos Conteineres Docker (100% Offline)
echo "[4/5] Verificando imagens e iniciando conteineres em modo 100% offline..."
for tar in *.tar; do
    [ -f "$tar" ] && echo "       Carregando imagem offline: $tar..." && docker load -i "$tar"
done

if docker images -q clp_iot-nodered:latest 2>/dev/null | grep -q .; then
    echo "       [MODO OFFLINE] Imagem 'clp_iot-nodered:latest' encontrada no cache local."
    echo "       Subindo servicos sem qualquer consulta a internet..."
    docker compose up -d
else
    echo "       [AVISO] Imagem 'clp_iot-nodered:latest' ausente. Tentando compilacao local..."
    docker compose up -d --build
fi

# 5. Conclusao e Links de Acesso
echo "[5/5] Servicos inicializados com sucesso!"
echo "================================================================="
echo "   PAINEIS DE ACESSO (100% OFFLINE):                             "
echo "   - Supervisorio / IHM Operador : http://localhost:1880/ui      "
echo "   - Editor de Fluxos Node-RED   : http://localhost:1880         "
echo "   - InfluxDB 2.7 (Dados/Auth)   : http://localhost:8086         "
echo "   - Grafana (Graficos Flux)     : http://localhost:3000         "
echo "   - Pasta de Relatorios PDF/HTML: $ROOT_DIR/relatorios          "
echo "================================================================="
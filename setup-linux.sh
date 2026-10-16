#!/bin/bash
set -e

echo "================================================================="
echo "   INICIALIZAÇÃO DO SISTEMA SCADA / IoT - BANCADA DE PRESSÃO     "
echo "                      Ambiente: Linux / Ubuntu                   "
echo "================================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Configuração do arquivo de ambiente (.env)
if [ ! -f ".env" ]; then
    echo "[1/5] Arquivo .env não encontrado. Criando a partir de .env.example..."
    cp .env.example .env
    echo "       .env criado com sucesso."
else
    echo "[1/5] Arquivo .env já existe. Mantendo configurações atuais."
fi

# 2. Criação e ajuste de permissões das pastas locais
echo "[2/5] Verificando e criando pastas locais..."
mkdir -p nodered_data relatorios grafana_data influxdb_data influxdb_config

# Ajuste de permissões (se executado com sudo ou permissão disponível)
if command -v sudo >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
    echo "       Ajustando permissões de pastas via sudo..."
    sudo chown -R 1000:1000 nodered_data relatorios 2>/dev/null || true
    sudo chown -R 472:472 grafana_data 2>/dev/null || true
else
    chown -R 1000:1000 nodered_data relatorios 2>/dev/null || true
    chown -R 472:472 grafana_data 2>/dev/null || true
fi

# 3. Configuração de Rede Cabeada para o CLP Micro850 (192.168.1.100/24)
echo "[3/5] Verificando configuração de rede física para o CLP..."
if command -v nmcli >/dev/null 2>&1; then
    # Procura conexão cabeada existente
    ETH_CON=$(nmcli -t -f NAME,TYPE con show --active | grep ethernet | head -n1 | cut -d: -f1 || true)
    if [ -z "$ETH_CON" ]; then
        ETH_CON=$(nmcli -t -f NAME,TYPE con show | grep -E 'Perfil 1|netplan-enp|Wired|Cabeada' | head -n1 | cut -d: -f1 || true)
    fi

    if [ -n "$ETH_CON" ]; then
        echo "       Configurando perfil de rede '$ETH_CON' com IP estático 192.168.1.100/24 sem gateway..."
        nmcli con modify "$ETH_CON" \
            ipv4.method manual \
            ipv4.addresses 192.168.1.100/24 \
            ipv4.gateway "" \
            ipv4.never-default yes \
            ipv4.route-metric 100 \
            connection.autoconnect yes 2>/dev/null || true
        nmcli con up "$ETH_CON" 2>/dev/null || true
    else
        echo "       [AVISO] Nenhuma conexão cabeada específica encontrada pelo nmcli. Verifique se o cabo está conectado."
    fi
else
    echo "       [AVISO] nmcli não disponível neste ambiente. Certifique-se de que o IP 192.168.1.100/24 está configurado."
fi

# Teste rápido de ping ao CLP
echo "       Testando conectividade com o CLP Micro850 (192.168.1.33)..."
if ping -c 2 -W 1 192.168.1.33 >/dev/null 2>&1; then
    echo "       [OK] CLP 192.168.1.33 respondeu ao ping com sucesso!"
else
    echo "       [INFO] CLP 192.168.1.33 ainda não respondeu ao ping (verifique o cabo e se o CLP está ligado)."
fi

# 4. Inicialização dos Contêineres Docker (100% Offline)
echo "[4/5] Verificando imagens e iniciando contêineres em modo 100% offline..."
# Carrega imagens offline (.tar) se existirem
for tar in *.tar; do
    [ -f "$tar" ] && echo "       Carregando imagem offline: $tar..." && docker load -i "$tar"
done

if docker images -q clp_iot-nodered:latest 2>/dev/null | grep -q .; then
    echo "       [MODO OFFLINE] Imagem 'clp_iot-nodered:latest' encontrada no cache local."
    echo "       Subindo serviços sem qualquer consulta à internet..."
    docker compose up -d
else
    echo "       [AVISO] Imagem 'clp_iot-nodered:latest' ausente. Tentando compilação local..."
    docker compose up -d --build
fi

# 5. Conclusão e Links de Acesso
echo "[5/5] Serviços inicializados com sucesso!"
echo "================================================================="
echo "   PAINÉIS DE ACESSO (100% OFFLINE):                             "
echo "   - Supervisório / IHM Operador : http://localhost:1880/ui      "
echo "   - Editor de Fluxos Node-RED   : http://localhost:1880         "
echo "   - InfluxDB 2.7 (Dados/Auth)   : http://localhost:8086         "
echo "   - Grafana (Gráficos Flux)     : http://localhost:3000         "
echo "   - Pasta de Relatórios PDF/HTML: $SCRIPT_DIR/relatorios        "
echo "================================================================="

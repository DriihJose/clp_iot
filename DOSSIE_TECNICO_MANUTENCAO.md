# DOSSIÊ TÉCNICO DE MANUTENÇÃO E OPERAÇÃO
## Sistema SCADA / IoT - Bancada de Teste de Pressão Hidrostática
**Controlador:** Rockwell Micro850 (2080-L50E) | **Supervisório:** Node-RED 4.x | **Banco:** InfluxDB 2.7 | **Dashboards:** Grafana 11.x  
**Compatibilidade:** Linux (Ubuntu 20.04/22.04/24.04 LTS) e Windows 10/11 (Docker Desktop / WSL2)  
**Ambiente:** 100% Offline (Air-gapped)

---

## SUMÁRIO EXECUTIVO

Este documento é a referência definitiva de engenharia de automação e software para manutenção, calibração, diagnóstico e operação do sistema de teste hidrostático da bancada.

O sistema executa testes de estanqueidade e integridade mecânica com duração padrão de 60 minutos, registrando a curva de pressão em alta resolução, calculando indicadores estatísticos (média, mínima, máxima, erro relativo) e gerando relatórios de ensaio em formato PDF autônomo e assinado digitalmente, além de prover telas de operação em tempo real no Node-RED Dashboard (`/ui`) e análise histórica no Grafana.

---

## 1. ARQUITETURA GERAL E TOPOLOGIA DE REDE

```
                      +----------------------------------------+
                      |       ROCKWELL MICRO850 (CLP)          |
                      |       IP Fixo: 192.168.1.33:44818      |
                      |       Protocolo: EtherNet/IP (CIP)     |
                      +----------------------------------------+
                                          |
                                   (Cabo Ethernet)
                                          |
                     +------------------------------------------+
                     |         PLACA CABEADA DO COMPUTADOR      |
                     |         IP: 192.168.1.100 / 255.255.255.0|
                     |         Gateway: (em branco/nenhum)      |
                     +------------------------------------------+
                                          |
        +---------------------------------+---------------------------------+
        |                                                                   |
[Linux: network_mode: host]                                     [Windows: iot-network bridge]
        |                                                                   |
        v                                                                   v
+-----------------------+                                   +-----------------------+
|  NODE-RED (Port 1880) |                                   |  NODE-RED (Port 1880) |
|  - Driver CIP shim    |                                   |  - Driver CIP shim    |
|  - Chromium Headless  |                                   |  - Chromium Headless  |
+-----------------------+                                   +-----------------------+
        |                                                                   |
        +---------------------------------+---------------------------------+
                                          | (Line Protocol / Flux)
                                          v
                              +-----------------------+
                              | INFLUXDB 2.7 (P:8086) |
                              | Org: vigor            |
                              | Bucket: carrinho      |
                              +-----------------------+
                                          | (Flux Query)
                                          v
                              +-----------------------+
                              |  GRAFANA (Port 3000)  |
                              |  Dashboard Dinâmico   |
                              +-----------------------+
```

### 1.1 Tags Globais do CLP Micro850
Toda a comunicação do CLP foi unificada e homologada para o Micro850 via CIP nativo (Message Router não roteado). **Não existe qualquer resquício de comandos legados PCCC / DF1 (como `F8:0`, `N7:1`, etc.).**

| Tag no CLP | Tipo de Dado | Sentido | Descrição Funcional |
|---|---|---|---|
| `RETORNO_BAR` | `REAL` | CLP -> Node-RED | Pressão instantânea lida pelo transmissor analógico (0 a 10 bar). |
| `_IO_EM_DO_00` | `BOOL` | CLP -> Node-RED | Feedback elétrico da saída digital 00 (Válvula solenoide). |
| `setpoint_node` | `REAL` | Bidirecional | Pressão desejada configurada pelo operador ou lida do CLP. |
| `on_node` | `DINT` | Node-RED -> CLP | Comando de ativação manual do motor hidráulico. |
| `off_node` | `DINT` | Node-RED -> CLP | Comando de desativação manual do motor hidráulico. |
| `onval_node` | `DINT` | Node-RED -> CLP | Comando de abertura manual da válvula solenoide. |
| `offval_node` | `DINT` | Node-RED -> CLP | Comando de fechamento manual da válvula solenoide. |
| `ciclo_node` | `BOOL` | Node-RED -> CLP | **Sinal de Teste em Andamento**: `true` durante o teste, `false` ao parar/finalizar. |

---

## 2. ÁRVORE COMPLETA DE ARQUIVOS DO PROJETO

```
/home/mec/clp_iot/
├── .env.example                       # Modelo de variáveis de ambiente do InfluxDB e Grafana
├── .git/                              # Controle de versão do repositório
├── .gitattributes                     # Configuração de normalização de finais de linha (LF/CRLF)
├── .gitignore                         # Regras de exclusão de dados dinâmicos, senhas e PDFs
├── Dockerfile.nodered                 # Imagem customizada Alpine do Node-RED com Chromium
├── DOSSIE_TECNICO_MANUTENCAO.md       # Este documento técnico completo
├── README.md                          # Guia rápido de introdução e inicialização do projeto
├── RESUMO_EXECUCAO.md                 # Ponteiro permanente para o histórico cronológico de tarefas
├── RESUMO_PROJETO_SCADA.md            # Visão geral de arquitetura e entregáveis
├── docker-compose.windows.yml         # Orquestração de contêineres para Windows 10/11
├── docker-compose.yml                 # Orquestração de contêineres para Linux
├── docker-entrypoint.sh               # Script de inicialização com auto-recuperação de node_modules
├── setup-linux.sh                     # Script de automação total e rede no Ubuntu/Debian
├── setup-windows.ps1                  # Script de automação total e rede no Windows (PowerShell)
├── grafana_provisioning/              # Provisionamento automático de Data Sources e Dashboards
│   ├── dashboards/
│   │   ├── dashboard.json             # Definição visual completa do Dashboard de Pressão
│   │   └── default.yaml               # Provedor que carrega os dashboards automaticamente
│   └── datasources/
│       └── influxdb.yaml              # Conexão automática ao InfluxDB 2.7 (Flux)
├── historico_execucoes/               # Registro imutável de todas as intervenções de bancada
│   ├── 01_RESUMO_EXECUCAO_recuperacao_resgate_bancada.md
│   ├── 02_RESUMO_EXECUCAO_grafana_dashboard_dinamico.md
│   ├── 03_RESUMO_EXECUCAO_intertravamento_pdf_grafana.md
│   ├── 04_RESUMO_EXECUCAO_auditoria_limpeza_dossie.md
│   └── README.md
├── nodered_data/                      # Volume persistente do Node-RED
│   ├── flows.json                     # Fluxo oficial limpo e validado (51 nós)
│   ├── package.json                   # Dependências npm estritas e aprovadas
│   ├── package-lock.json              # Lockfile determinístico
│   ├── settings.js                    # Configurações do Node-RED com shim CIP do Micro800
│   └── relatorios/
│       └── .gitkeep                   # Ponto de montagem interno para os relatórios
└── relatorios/                        # Pasta no host onde os PDFs gerados são salvos
    └── .gitkeep
```

---

## 3. ARQUIVOS DE INFRAESTRUTURA E CONFIGURAÇÃO INTEGRAL

### 3.1 `docker-compose.yml` (Linux)
```yaml
services:
  nodered:
    build:
      context: .
      dockerfile: Dockerfile.nodered
    image: clp_iot-nodered:latest
    container_name: nodered
    # Linux: network_mode: host permite comunicação direta em camada 2/3 com o Micro850 (192.168.1.33)
    # via interface física enp58s0 sem passar pelo NAT do Docker.
    network_mode: host
    volumes:
      - ./nodered_data:/data
      - ./relatorios:/data/relatorios
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
    depends_on:
      - influxdb

  influxdb:
    image: influxdb:2.7
    container_name: influxdb
    ports:
      - "8086:8086"
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=${DOCKER_INFLUXDB_INIT_MODE:-setup}
      - DOCKER_INFLUXDB_INIT_USERNAME=${DOCKER_INFLUXDB_INIT_USERNAME:-admin}
      - DOCKER_INFLUXDB_INIT_PASSWORD=${DOCKER_INFLUXDB_INIT_PASSWORD:-adminpassword123}
      - DOCKER_INFLUXDB_INIT_ORG=${DOCKER_INFLUXDB_INIT_ORG:-vigor}
      - DOCKER_INFLUXDB_INIT_BUCKET=${DOCKER_INFLUXDB_INIT_BUCKET:-carrinho}
      - DOCKER_INFLUXDB_INIT_RETENTION=${DOCKER_INFLUXDB_INIT_RETENTION:-0}
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}
    volumes:
      - ./influxdb_data:/var/lib/influxdb2
      - ./influxdb_config:/etc/influxdb2
    restart: unless-stopped
    networks:
      - iot-network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}
    volumes:
      - ./grafana_data:/var/lib/grafana
      - ./grafana_provisioning:/etc/grafana/provisioning:ro
    restart: unless-stopped
    networks:
      - iot-network
    depends_on:
      - influxdb

networks:
  iot-network:
    driver: bridge
```

### 3.2 `docker-compose.windows.yml` (Windows 10/11)
```yaml
services:
  nodered:
    build:
      context: .
      dockerfile: Dockerfile.nodered
    image: clp_iot-nodered:latest
    container_name: nodered
    # Windows (Docker Desktop via WSL2): expõe a porta 1880 diretamente no Windows
    # e conecta na iot-network. A comunicação com InfluxDB é feita via host.docker.internal.
    ports:
      - "1880:1880"
    networks:
      - iot-network
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ./nodered_data:/data
      - ./relatorios:/data/relatorios
    restart: unless-stopped
    depends_on:
      - influxdb

  influxdb:
    image: influxdb:2.7
    container_name: influxdb
    ports:
      - "8086:8086"
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=${DOCKER_INFLUXDB_INIT_MODE:-setup}
      - DOCKER_INFLUXDB_INIT_USERNAME=${DOCKER_INFLUXDB_INIT_USERNAME:-admin}
      - DOCKER_INFLUXDB_INIT_PASSWORD=${DOCKER_INFLUXDB_INIT_PASSWORD:-adminpassword123}
      - DOCKER_INFLUXDB_INIT_ORG=${DOCKER_INFLUXDB_INIT_ORG:-vigor}
      - DOCKER_INFLUXDB_INIT_BUCKET=${DOCKER_INFLUXDB_INIT_BUCKET:-carrinho}
      - DOCKER_INFLUXDB_INIT_RETENTION=${DOCKER_INFLUXDB_INIT_RETENTION:-0}
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}
    volumes:
      - ./influxdb_data:/var/lib/influxdb2
      - ./influxdb_config:/etc/influxdb2
    restart: unless-stopped
    networks:
      iot-network:
        aliases:
          - influxdb
          - host.docker.internal

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}
    volumes:
      - ./grafana_data:/var/lib/grafana
      - ./grafana_provisioning:/etc/grafana/provisioning:ro
    restart: unless-stopped
    networks:
      - iot-network
    depends_on:
      - influxdb

networks:
  iot-network:
    driver: bridge
```

### 3.3 `Dockerfile.nodered`
```dockerfile
FROM nodered/node-red:latest

USER root

# Instala Chromium headless, fontes e dependências de renderização para geração de relatórios PDF
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont

# Copia script customizado de inicialização
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER node-red

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
```

### 3.4 `docker-entrypoint.sh`
```bash
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
```

### 3.5 O Shim Micro800 em `nodered_data/settings.js`
> **Problema Resolvido:** O pacote `node-red-contrib-cip-ethernet-ip` utiliza por padrão a biblioteca `ethernet-ip`, que empacota todas as mensagens CIP dentro de um `Unconnected Send` roteado para o backplane (Porta 1, Slot 0). No entanto, a família **Micro800 (Micro820, Micro850, Micro870)** é de chassi fixo monolítico, não possui backplane e rejeita o cabeçalho de roteamento, resultando em erro perpétuo de `TIMEOUT occurred while reading Controller Props`.  
> **Solução do Shim:** Interceptamos o protótipo da classe `Controller` no `settings.js` antes da inicialização dos fluxos, forçando o envio direto ao `Message Router` (mesmo algoritmo utilizado pelo `pylogix` com `Micro800=True`).

```javascript
/*******************************************************************************
 * Micro800 (Micro850 2080-L50E @ 192.168.1.33) compatibility shim
 *
 * node-red-contrib-cip-ethernet-ip uses the "ethernet-ip" library, which wraps
 * EVERY CIP request in an Unconnected Send routed through backplane port 1/slot.
 * Micro800 controllers have no backplane and do not accept that routing, so the
 * connection fails with "TIMEOUT occurred while reading Controller Props".
 * Here the Message Router request is sent directly (no route path), the same
 * approach pylogix uses with Micro800=True. The endpoint "slot" is ignored.
 * Remove this block if a ControlLogix/CompactLogix (routed) PLC is ever used.
 ******************************************************************************/
try {
    const { Controller } = require("/data/node_modules/ethernet-ip");
    const ENIP = Object.getPrototypeOf(Controller.prototype);
    Controller.prototype.write_cip = function (data, connected = false, timeout = 10, cb = null) {
        ENIP.write_cip.call(this, data, connected, timeout, cb);
    };
    console.log("[micro800-shim] ethernet-ip patched: direct Message Router (no backplane route)");
} catch (e) {
    console.warn("[micro800-shim] not applied:", e.message);
}
```

### 3.6 `setup-linux.sh`
```bash
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

# 4. Build e Inicialização dos Contêineres Docker
echo "[4/5] Construindo imagem customizada do Node-RED e subindo contêineres..."
docker compose up -d --build

# 5. Conclusão e Links de Acesso
echo "[5/5] Serviços inicializados com sucesso!"
echo "================================================================="
echo "   PAINÉIS DE ACESSO:                                            "
echo "   - Supervisório / IHM Operador : http://localhost:1880/ui      "
echo "   - Editor de Fluxos Node-RED   : http://localhost:1880         "
echo "   - InfluxDB 2.7 (Dados/Auth)   : http://localhost:8086         "
echo "   - Grafana (Gráficos Flux)     : http://localhost:3000         "
echo "   - Pasta de Relatórios PDF/HTML: $SCRIPT_DIR/relatorios        "
echo "================================================================="
```

### 3.7 `setup-windows.ps1`
```powershell
# ==============================================================================
# INICIALIZAÇÃO DO SISTEMA SCADA / IoT - BANCADA DE PRESSÃO HIDROSTÁTICA
# Ambiente: Windows (Docker Desktop com WSL2)
# ==============================================================================

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "   INICIALIZAÇÃO DO SISTEMA SCADA / IoT - BANCADA DE PRESSÃO     " -ForegroundColor Cyan
Write-Host "             Ambiente: Windows (Docker Desktop)                  " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# 1. Configuração do arquivo de variáveis de ambiente (.env)
if (-not (Test-Path ".env")) {
    Write-Host "[1/4] Criando arquivo .env a partir de .env.example..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host "       .env criado com sucesso." -ForegroundColor Green
} else {
    Write-Host "[1/4] Arquivo .env já existe. Mantendo configurações locais." -ForegroundColor Green
}

# 2. Criação das pastas locais necessárias
Write-Host "[2/4] Verificando e criando pastas locais..." -ForegroundColor Yellow
$pastas = @("nodered_data", "relatorios", "grafana_data", "influxdb_data", "influxdb_config")
foreach ($pasta in $pastas) {
    if (-not (Test-Path $pasta)) {
        New-Item -ItemType Directory -Path $pasta | Out-Null
    }
}
Write-Host "       Pastas locais verificadas." -ForegroundColor Green

# 3. Orientação e Verificação da Placa de Rede para o CLP Micro850
Write-Host "[3/4] Verificando adaptadores de rede Ethernet..." -ForegroundColor Yellow
try {
    $adaptadores = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" -and $_.MediaType -eq "802.3" }
    if ($adaptadores) {
        Write-Host "       Adaptador Ethernet ativo detectado: $($adaptadores[0].Name)" -ForegroundColor Cyan
        $ipAtual = Get-NetIPAddress -InterfaceAlias $adaptadores[0].Name -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -like "192.168.1.*" }
        if ($ipAtual) {
            Write-Host "       [OK] Adaptador ja possui IP na sub-rede 192.168.1.x: $($ipAtual.IPAddress)" -ForegroundColor Green
        } else {
            Write-Host "       [AVISO] Configure o IP estatico na placa cabeada do Windows:" -ForegroundColor Yellow
            Write-Host "               IP: 192.168.1.100 | Mascara: 255.255.255.0 | Gateway: (em branco)" -ForegroundColor Yellow
            Write-Host "       Deseja tentar configurar automaticamente agora? (Requer PowerShell como Administrador)" -ForegroundColor Gray
        }
    } else {
        Write-Host "       [INFO] Conecte o cabo Ethernet entre o computador e o CLP Micro850 (IP fixo 192.168.1.33)." -ForegroundColor Yellow
    }
} catch {
    Write-Host "       Não foi possível consultar os adaptadores automaticamente: $($_.Exception.Message)" -ForegroundColor Gray
}

# 4. Inicialização do Docker Compose no Windows
Write-Host "[4/4] Subindo contêineres via docker-compose.windows.yml..." -ForegroundColor Yellow
docker compose -f docker-compose.windows.yml up -d --build

Write-Host "=================================================================" -ForegroundColor Green
Write-Host "   SISTEMA SCADA EM EXECUÇÃO NO WINDOWS:                         " -ForegroundColor Green
Write-Host "   - Supervisório / IHM Operador : http://localhost:1880/ui      " -ForegroundColor Cyan
Write-Host "   - Editor de Fluxos Node-RED   : http://localhost:1880         " -ForegroundColor Cyan
Write-Host "   - InfluxDB 2.7 (Dados/Tokens) : http://localhost:8086         " -ForegroundColor Cyan
Write-Host "   - Grafana (Gráficos Flux)     : http://localhost:3000         " -ForegroundColor Cyan
Write-Host "   - Pasta de Relatórios PDF/HTML: .\relatorios                  " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Green
```

---

## 4. MAPEAMENTO COMPLETO DO FLUXO DO NODE-RED (`flows.json`)

O fluxo do Node-RED é composto por 51 nós funcionais organizados em 7 blocos lógicos operando em harmonia.

### 4.1 Visão Geral dos Blocos Lógicos

```
[IHM: Nome Equipamento] ------> (fn_set_eq: Salvar)
[IHM: Motor Switch] ----------> (fn_cache_motor) ----------+
[IHM: Válvula Switch] --------> (fn_cache_valvula_manual) -+
[IHM: Setpoint Numérico] -----> (fn_cache_setpoint) -------+
[CLP: RETORNO_BAR (200ms)] ---> (7d655f41: Coleta Pressão) -+
                                                           |
[IHM: INICIAR TESTE] ---------> (49589c46: Inicia Teste) --+---> [CLP: ciclo_node = true]
                                        |                   +---> [InfluxDB: Setpoint Travado]
                                        v                   +---> (fn_ui_lock: Bloqueia UI)
                                 (Contagem Ativa)
                                        |
(Inject 1s) ------------------> (5214bd83: Cronômetro) ---> [IHM: Display Tempo & Status]
                                        | (tempo esgotado)
                                        v
[IHM: FINALIZAR TESTE] -------> (6d54da28: Finaliza Teste) ----> [CLP: ciclo_node = false]
                                        |                  ----> (fn_ui_lock: Libera UI)
                                        v
                               [Template HTML/SVG]
                                        v
                              (e32ec29a: Comando Chromium)
                                        v
                              [Gerar PDF via Chromium]
                                        v
                           ./relatorios/<Equip>_<Data>.pdf
```

1. **Leitura CLP:** Nó `eth-ip in` monitora a cada 200 ms a tag `RETORNO_BAR` do Micro850 e envia os pontos para a memória de curto prazo e para o InfluxDB (medição `pressao`). O nó `eth-ip in` de `_IO_EM_DO_00` lê o estado físico da válvula solenoide.
2. **Escrita CLP:** Nós `eth-ip out` controlam os comandos manuais (`on_node`, `off_node`, `onval_node`, `offval_node`), o setpoint analógico (`setpoint_node`) e a tag booleana de ciclo (`ciclo_node`).
3. **Intertravamento e Bloqueio de UI:** O nó `Inicia teste` audita 4 condições de segurança antes de permitir o início. O nó `Habilitar / Bloquear UI` desativa todos os controles durante o teste para impedir interferência humana no ensaio.
4. **Cronômetro:** O nó `Decremento de tempo` decrementa a cada 1 segundo o tempo restante (padrão 60 minutos), calculando a hora final real e disparando automaticamente o encerramento ao atingir zero.
5. **Cálculo de Relatório e Vetor SVG:** O nó `Finaliza _Teste` processa o histórico coletado durante o intervalo `[hora_inicio_date, hora_fim_date]`, calcula média, mínima, máxima, erro e desenha a curva vetorial SVG embutida na grade de tempo.
6. **Renderização PDF Headless:** O nó `template` monta o HTML 100% inline (sem CSS nem fontes remotas). Em seguida, `Comando Chromium` formata os parâmetros e o nó `exec` invoca `chromium-browser` gerando o arquivo `<Equipamento>_<DataHora>.pdf` de forma independente.
7. **Séries Temporais InfluxDB:** Nós `influxdb out` registram a pressão instantânea a cada 200 ms e, durante o teste, o nó `Keepalive InfluxDB` garante que o setpoint travado e o status da válvula permaneçam visíveis em tempo real nas consultas Flux do Grafana.

---

### 4.2 CÓDIGO JAVASCRIPT INTEGRAL DE TODOS OS NÓS `function`

Abaixo está o código JavaScript EXATO e integral contido no arquivo `flows.json`.

---

#### 1. Nó `fn_set_eq` — `Salvar Equipamento`
- **ID:** `fn_set_eq`
- **Tipo:** `function` (1 entrada, 0 saídas)
- **Função:** Captura a identificação digitada no campo de texto da IHM ("NOME DO EQUIPAMENTO") e armazena na memória de contexto do fluxo para uso posterior na montagem do cabeçalho do relatório e nomenclatura do arquivo PDF.

```javascript
flow.set('equipamento', msg.payload);
return null;
```

---

#### 2. Nó `fn_cache_motor` — `Cache Motor Manual`
- **ID:** `fn_cache_motor`
- **Tipo:** `function` (1 entrada, 0 saídas)
- **Função:** Captura o clique no botão/switch de acionamento manual do motor (onde 1 = ligado, 2 = desligado) e atualiza a flag de intertravamento.

```javascript
// 1 = ligado | 2 = desligado (valores do switch). Usado no intertravamento do INICIAR TESTE.
flow.set('motor_on', msg.payload === 1 || msg.payload === true);
return null;
```

---

#### 3. Nó `fn_cache_valvula_manual` — `Cache Válvula Manual`
- **ID:** `fn_cache_valvula_manual`
- **Tipo:** `function` (1 entrada, 0 saídas)
- **Função:** Captura o acionamento manual da válvula solenoide (1 = aberta, 2 = fechada) para proteção de intertravamento.

```javascript
// 1 = aberta | 2 = fechada (valores do switch). Usado no intertravamento do INICIAR TESTE.
flow.set('valvula_manual_on', msg.payload === 1 || msg.payload === true);
return null;
```

---

#### 4. Nó `fn_cache_valvula` — `Cache Válvula` (Retorno Físico do CLP)
- **ID:** `fn_cache_valvula`
- **Tipo:** `function` (1 entrada, 1 saída)
- **Função:** Normaliza a leitura digital da tag `_IO_EM_DO_00` do Micro850 para booleano estrito e atualiza `flow.valvula`.

```javascript
let val = !!msg.payload;
flow.set('valvula', val);
return { payload: val };
```

---

#### 5. Nó `fn_cache_setpoint` — `Cache Setpoint (tela)`
- **ID:** `fn_cache_setpoint`
- **Tipo:** `function` (1 entrada, 0 saídas)
- **Função:** Memoriza o valor digitado no campo numérico da tela (IHM) registrando o carimbo de data/hora da edição (`sp_ui_t`).

```javascript
// Valor digitado na tela (PRESSÃO DESEJADA). Apenas memoriza: o Influx só recebe o setpoint TRAVADO durante o teste.
const sp = Number(msg.payload);
if (!isNaN(sp)) {
    flow.set('sp_ui', sp);
    flow.set('sp_ui_t', Date.now());
}
return null;
```

---

#### 6. Nó `fn_cache_setpoint_plc` — `Cache Setpoint (CLP)`
- **ID:** `fn_cache_setpoint_plc`
- **Tipo:** `function` (1 entrada, 0 saídas)
- **Função:** Memoriza a leitura cíclica da tag `setpoint_node` vinda do CLP com seu carimbo de tempo (`sp_plc_t`), permitindo sincronização bidirecional.

```javascript
// Último setpoint lido do CLP (setpoint_node). Apenas memoriza; não grava no Influx.
const sp = Number(msg.payload);
if (!isNaN(sp)) {
    flow.set('sp_plc', sp);
    flow.set('sp_plc_t', Date.now());
}
return null;
```

---

#### 7. Nó `49589c46b3396a0f` — `Inicia teste`
- **ID:** `49589c46b3396a0f`
- **Tipo:** `function` (1 entrada, 4 saídas)
  - *Saída 0:* Bloqueio da IHM (`payload: 'RODANDO'`)
  - *Saída 1:* Escrita no CLP (`ciclo_node = true`)
  - *Saída 2:* Ponto inicial do setpoint no InfluxDB
  - *Saída 3:* Notificação visual de bloqueio/status
- **Função:** Núcleo de segurança operacional. Verifica:
  1. Se já há teste ativo (`flow.ativo === true`).
  2. Se o nome do equipamento foi preenchido.
  3. Se a bomba/motor está desligada.
  4. Se a válvula está fechada (tanto no switch manual quanto no feedback físico do CLP).
  5. Se há um setpoint numérico válido definido.
  Se qualquer condição falhar, bloqueia a partida e exibe mensagem em vermelho por 8 segundos. Se todas passarem, trava o setpoint e inicializa o ensaio.

```javascript
// Botão INICIAR TESTE: valida o intertravamento, trava o setpoint e inicia o ciclo.
// Saídas: [0] bloqueia a UI ('RODANDO') | [1] ciclo_node = true (CLP) | [2] 1º ponto do setpoint travado (InfluxDB) | [3] texto de STATUS
if (flow.get('ativo') === true) return null;   // já existe um teste em andamento

const valido = (v) => v !== null && v !== undefined && v !== '' && !isNaN(Number(v));

const equipamento   = String(flow.get('equipamento') ?? '').trim();
const motorLigado   = flow.get('motor_on') === true;
const valvulaAberta = flow.get('valvula_manual_on') === true || flow.get('valvula') === true;

// Setpoint vigente = valor mais recente entre o campo da tela e o lido do CLP
const tUi = flow.get('sp_ui_t') || 0;
const tPlc = flow.get('sp_plc_t') || 0;
const primeiro = tUi >= tPlc ? flow.get('sp_ui') : flow.get('sp_plc');
const segundo  = tUi >= tPlc ? flow.get('sp_plc') : flow.get('sp_ui');
const spBruto = valido(primeiro) ? primeiro : segundo;

const motivos = [];
if (!equipamento) motivos.push('PREENCHA O EQUIPAMENTO');
if (motorLigado) motivos.push('DESLIGUE O MOTOR');
if (valvulaAberta) motivos.push('FECHE A VÁLVULA');
if (!valido(spBruto)) motivos.push('DEFINA A PRESSÃO DESEJADA');

if (motivos.length > 0) {
    const aviso = { payload: 'BLOQUEADO - ' + motivos.join(' / '), color: '#C62828' };
    // o aviso fica visível por 8 s (o cronômetro de 1 s reescreve o STATUS)
    flow.set('aviso_status', { payload: aviso.payload, color: aviso.color, ate: Date.now() + 8000 });
    return [null, null, null, aviso];
}

const sp = Math.round(Number(spBruto) * 100) / 100;

flow.set('ativo', true);
flow.set('aviso_status', null);
flow.set('inicio', new Date().toLocaleString('pt-BR'));

flow.set('soma', 0);
flow.set('qtd', 0);
flow.set('min', null);
flow.set('max', null);

// limpa histórico
flow.set('historico', []);

// hora oficial de início
flow.set("hora_inicio_date", Date.now());

// duração padrão (1h)
flow.set("duracao_teste", 3600000);

// IMPORTANTE: limpa fim anterior
flow.set("hora_fim_date", null);

// SETPOINT TRAVADO: capturado uma única vez, no instante do início, e mantido até o fim do teste
flow.set('sp_travado', sp);
flow.set('sp', sp);
flow.set('equipamento_teste', equipamento);

return [
    { payload: 'RODANDO' },
    { payload: true },
    { payload: sp },
    null
];
```

---

#### 8. Nó `fn_ui_lock` — `Habilitar / Bloquear UI`
- **ID:** `fn_ui_lock`
- **Tipo:** `function` (1 entrada, 6 saídas)
  - *Saída 0:* Campo Nome do Equipamento (`msg.enabled`)
  - *Saída 1:* Switch Motor Manual (`msg.enabled`)
  - *Saída 2:* Switch Válvula Manual (`msg.enabled`)
  - *Saída 3:* Campo Pressão Desejada (`msg.enabled` + setpoint travado)
  - *Saída 4:* Botão Iniciar Teste (`msg.enabled`)
  - *Saída 5:* Botão Finalizar Teste (`msg.enabled`)
- **Função:** Controla a propriedade `msg.enabled` nos widgets do painel do operador. Durante o ensaio, desativa todos os botões de ajuste e permite exclusivamente o botão de cancelamento/finalização de emergência.

```javascript
// Entrada: msg.payload = 'RODANDO' | 'PARADO' | 'BOOT'
// Durante o teste: tudo desabilitado (msg.enabled = false), exceto FINALIZAR TESTE.
// Fora do teste:   tudo habilitado, FINALIZAR TESTE desabilitado.
// Saídas: [0] Equipamento | [1] MOTOR MANUAL | [2] VALVULA MANUAL | [3] PRESSÃO DESEJADA | [4] INICIAR TESTE | [5] FINALIZAR TESTE
let estado = msg.payload;
if (estado === 'BOOT') estado = flow.get('ativo') === true ? 'RODANDO' : 'PARADO';
const rodando = estado === 'RODANDO';

const sp = flow.get('sp_travado');
const mostraSp = rodando && sp !== undefined && sp !== null;

return [
    { enabled: !rodando },
    { enabled: !rodando },
    { enabled: !rodando },
    mostraSp ? { enabled: !rodando, payload: Number(sp) } : { enabled: !rodando },
    { enabled: !rodando },
    { enabled: rodando }
];
```

---

#### 9. Nó `7d655f418f1c0085` — `Coleta pressão`
- **ID:** `7d655f418f1c0085`
- **Tipo:** `function` (1 entrada, 1 saída)
- **Função:** Executa a cada leitura recebida do transmissor analógico (200 ms). Acumula a soma para média, encontra a mínima e máxima absoluta e armazena os pontos no array `historico`.

```javascript
let ativo = flow.get('ativo');

//if (!ativo) return null; // só grava quando ativo

let valor = Number(msg.payload);

// ignora valores inválidos (0, null, NaN)
 if (!valor || valor <= 0) return null;

// média
let soma = flow.get('soma') || 0;
let qtd = flow.get('qtd') || 0;

soma += valor;
qtd += 1;

flow.set('soma', soma);
flow.set('qtd', qtd);

// min max
let min = flow.get('min');
let max = flow.get('max');

if (min === null || valor < min) flow.set('min', valor);
if (max === null || valor > max) flow.set('max', valor);

// histórico LIMPO
let historico = flow.get('historico') || [];

historico.push({
    v: valor,
    t: Date.now()
});

//  mantém só últimos 10 minutos (ajustável)
let agora = Date.now();
historico = historico.filter(p => agora - p.t <= 600000);

flow.set('historico', historico);

return msg;
```

---

#### 10. Nó `5214bd83dc5b5467` — `Decremento de tempo`
- **ID:** `5214bd83dc5b5467`
- **Tipo:** `function` (1 entrada, 3 saídas)
  - *Saída 0:* Texto de tempo restante (`MM:SS`)
  - *Saída 1:* Gatilho de fim automático (`payload: "FINALIZAR_AUTO"`)
  - *Saída 2:* Texto e cor de status da bancada
- **Função:** Pulso temporal acionado a cada 1 segundo. Calcula a contagem regressiva em relação ao `hora_inicio_date` + `duracao_teste`. Ao atingir 0, dispara o encerramento automático.

```javascript
// Roda a cada 1 s (inject). Saídas: 1 = tempo restante | 2 = finalização automática | 3 = status do teste
const fmt = (ms) => {
    const total = Math.max(0, Math.ceil(ms / 1000));      // segundos restantes (arredonda p/ cima)
    const mm = String(Math.floor(total / 60)).padStart(2, '0');
    const ss = String(total % 60).padStart(2, '0');
    return `${mm}:${ss}`;
};
const tempo = (ms) => ({ payload: `TEMPO RESTANTE: ${fmt(ms)}` });

const AGUARDANDO = { payload: "AGUARDANDO INÍCIO DO TESTE", color: "#B26A00" };  // âmbar

let ativo   = flow.get('ativo');
let inicio  = flow.get("hora_inicio_date");
let duracao = flow.get("duracao_teste") || 3600000; // 1h

// NUNCA INICIOU / NÃO ESTÁ ATIVO -> contagem parada
if (!inicio || !ativo) {
    let status = AGUARDANDO;
    const aviso = flow.get('aviso_status');          // alerta de intertravamento (INICIAR bloqueado)
    if (aviso && aviso.ate > Date.now()) status = { payload: aviso.payload, color: aviso.color };
    return [tempo(duracao), null, status];
}

let restante = (inicio + duracao) - Date.now();

// CHEGOU EM ZERO -> FINALIZA AUTOMÁTICO
if (restante <= 0 && ativo === true) {
    flow.set('tempo_restante', 0);
    flow.set('ativo', false);

    // FINAL REAL
    flow.set('hora_fim_date', Date.now());

    // chama finalização automática
    return [tempo(0), { payload: "FINALIZAR_AUTO" }, AGUARDANDO];
}

// CONTAGEM NORMAL
flow.set('tempo_restante', Math.ceil(restante / 60000));   // mantido em minutos (compatibilidade)

const sp = flow.get('sp_travado');
const rodando = { payload: `TESTE RODANDO - SETPOINT ${sp !== undefined && sp !== null ? Number(sp).toFixed(2) : '--'} BAR`, color: "#2E7D32" };  // verde
return [tempo(restante), null, rodando];
```

---

#### 11. Nó `6d54da2809aedd4d` — `Finaliza _Teste`
- **ID:** `6d54da2809aedd4d`
- **Tipo:** `function` (1 entrada, 5 saídas)
  - *Saída 0:* Livre
  - *Saída 1:* Dados consolidados para o template do Relatório (HTML/PDF)
  - *Saída 2:* Destravamento da IHM (`payload: 'PARADO'`)
  - *Saída 3:* Desativação no CLP (`ciclo_node = false`)
  - *Saída 4:* Ponto final do setpoint no InfluxDB
- **Função:** Encerra o ciclo, calcula o desvio `erro = sp - min` comparando com a tolerância de 0.5 bar, gera a string de pontos e linhas para o gráfico SVG do relatório e define o nome único do arquivo PDF a ser salvo.

```javascript
// Entradas: botão FINALIZAR TESTE (payload 0) ou cronômetro (payload "FINALIZAR_AUTO").
// Saídas: [0] livre | [1] relatório (HTML -> PDF) | [2] libera a UI ('PARADO') | [3] ciclo_node = false (CLP) | [4] ponto final do setpoint travado (InfluxDB)
const auto = msg.payload === 'FINALIZAR_AUTO';
if (!auto && flow.get('ativo') !== true) return null;   // nenhum teste em andamento

const spTravado = flow.get('sp_travado');
// SEMPRE libera a tela e zera o ciclo_node, mesmo que o relatório não possa ser gerado
const liberar = (rel) => {
    flow.set('ativo', false);
    return [
        null,
        rel,
        { payload: 'PARADO' },
        { payload: false },
        (spTravado !== undefined && spTravado !== null && !isNaN(Number(spTravado))) ? { payload: Number(spTravado) } : null
    ];
};

// Datas/horas SEMPRE no fuso e formato brasileiros (o contêiner roda em UTC)
const BR = 'America/Sao_Paulo';
const partesBR = (d) => {
    const o = {};
    new Intl.DateTimeFormat('pt-BR', {
        timeZone: BR, year: 'numeric', month: '2-digit', day: '2-digit',
        hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23'
    }).formatToParts(new Date(d)).forEach(p => { o[p.type] = p.value; });
    return o;
};
const dataHoraBR = (d) => {
    const o = partesBR(d);
    return `${o.day}/${o.month}/${o.year} ${o.hour}:${o.minute}:${o.second}`;
};

let soma = flow.get('soma') || 0;
let qtd = flow.get('qtd') || 1;
let media = soma / qtd;

let min = flow.get('min');
let max = flow.get('max');
let sp = Number(flow.get('sp_travado') ?? flow.get('sp') ?? 0) || 0;
let historico = flow.get('historico') || [];

// PROTEÇÃO
if (min == null || max == null || historico.length === 0) {
    node.error("Dados insuficientes");
    return liberar(null);
}

// TEMPO OFICIAL
let inicio = flow.get("hora_inicio_date");
let fim = flow.get("hora_fim_date") || Date.now();

if (!inicio) {
    node.error("hora_inicio_date não encontrada");
    return liberar(null);
}

let fimDate = new Date(fim);

// NORMALIZA INÍCIO (remove segundos)
let inicioBase = new Date(inicio);
inicioBase.setSeconds(0);
inicioBase.setMilliseconds(0);
inicio = inicioBase.getTime();

// HISTÓRICO FILTRADO
let historicoFiltrado = historico.filter(p => p.t >= inicio);

// ERRO E TOLERÂNCIA DE APROVAÇÃO (0.5 BAR)
let erro = sp - min;
let tolerancia = 0.5;
let status = erro <= tolerancia ? "APROVADO" : "REPROVADO";

// ESCALA DO GRÁFICO (20 px por bar)
let escala = 20;

// BASE FIXA DE 1 HORA (60 min * 60 s * 1000 ms)
let duracao = 60 * 60 * 1000;

// PONTOS SVG DA CURVA DE PRESSÃO
let pontos = "";

let primeiroValor = historicoFiltrado.length > 0 ? historicoFiltrado[0].v : sp;
let x0 = 50;
let y0 = 240 - ((Number(primeiroValor) || 0) * escala);
pontos += x0 + "," + y0 + " ";

historicoFiltrado.forEach((p) => {
    if (p.t > fim) return;
    let proporcao = (p.t - inicio) / duracao;
    if (proporcao < 0) proporcao = 0;
    if (proporcao > 1) proporcao = 1;
    let x = 50 + (proporcao * 900);
    let y = 240 - (Number(p.v) * escala);
    pontos += x + "," + y + " ";
});

let ultimoPonto = historicoFiltrado[historicoFiltrado.length - 1];
let duracaoReal = fim - inicio;
let proporcaoFinal = duracaoReal / duracao;
if (proporcaoFinal < 0) proporcaoFinal = 0;
if (proporcaoFinal > 1) proporcaoFinal = 1;

let xFinal = 50 + (proporcaoFinal * 900);
let yFinal = 240 - ((Number(ultimoPonto ? ultimoPonto.v : sp) || 0) * escala);
pontos += xFinal + "," + yFinal;

// LINHA GUIA DO SETPOINT
let ySP = 240 - (sp * escala);
let linhaSP = `50,${ySP} 950,${ySP}`;

// MARCADOR DE FALHA (SE REPROVADO)
let falhaX = null;
let falhaY = null;
let falhaValor = null;

if (status === "REPROVADO") {
    let pFalha = historicoFiltrado.find(p => (sp - p.v) > tolerancia);
    if (pFalha) {
        let proporcaoFalha = (pFalha.t - inicio) / duracao;
        falhaX = 50 + (proporcaoFalha * 900);
        falhaY = 240 - (Number(pFalha.v) * escala);
        falhaValor = Number(pFalha.v).toFixed(2);
    }
}

// MARCADORES DE TEMPO NO EIXO X A CADA 5 MINUTOS (FUSO BRASILEIRO)
function horaOffset(minutos) {
    let d = new Date(inicio + (minutos * 60 * 1000));
    let o = partesBR(d);
    return `${o.hour}:${o.minute}`;
}

let t0  = horaOffset(0);
let t1  = horaOffset(5);
let t2  = horaOffset(10);
let t3  = horaOffset(15);
let t4  = horaOffset(20);
let t5  = horaOffset(25);
let t6  = horaOffset(30);
let t7  = horaOffset(35);
let t8  = horaOffset(40);
let t9  = horaOffset(45);
let t10 = horaOffset(50);
let t11 = horaOffset(55);
let t12 = horaOffset(60);

// OBJETO DO RELATÓRIO
let rel = {
    equipamento: flow.get('equipamento_teste') ?? flow.get('equipamento'),
    inicio: dataHoraBR(inicio),
    fim: dataHoraBR(fimDate),
    media: media.toFixed(2),
    min: Number(min).toFixed(2),
    max: Number(max).toFixed(2),
    sp: sp,
    erro: erro.toFixed(2),
    status: status,
    pontos: pontos,
    linhaSP: linhaSP,
    falhaX: falhaX,
    falhaY: falhaY,
    falhaValor: falhaValor,
    falhaYTxt: falhaY !== null ? falhaY + 15 : null,
    t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12
};

// RESET
flow.set('tempo_restante', 60);

// DATA DE EMISSÃO BRASILEIRA
let agora = new Date();
let o = partesBR(agora);
rel.emissao = `${o.day}/${o.month}/${o.year} - ${o.hour}:${o.minute}:${o.second}`;

// NOME ÚNICO DO ARQUIVO PDF: <Equipamento>_<DD-MM-AAAA_HH-mm-ss>.pdf
let equip = String(flow.get('equipamento_teste') ?? flow.get('equipamento') ?? '')
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^A-Za-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 60) || 'Equipamento';
let carimbo = `${o.day}-${o.month}-${o.year}_${o.hour}-${o.minute}-${o.second}`;

msg.filename = "/data/relatorios/relatorio.html";                      // HTML temporário
msg.pdfFile  = "/data/relatorios/" + equip + "_" + carimbo + ".pdf";   // PDF definitivo

return liberar({ payload: rel, filename: msg.filename, pdfFile: msg.pdfFile });
```

---

#### 12. Nó `e32ec29ac871e4f2` — `Comando Chromium`
- **ID:** `e32ec29ac871e4f2`
- **Tipo:** `function` (1 entrada, 1 saída)
- **Função:** Constrói os parâmetros do Chromium headless eliminando o cabeçalho/rodapé padrão do navegador (evita datas em inglês no topo do PDF).

```javascript
// Argumentos do Chromium headless (o executável está no nó "Gerar PDF (Chromium)").
// --no-pdf-header-footer remove a data em inglês e o título "relatorio.html" impressos pelo navegador.
const pdf  = msg.pdfFile;
const html = msg.htmlFile;
msg.payload = `--headless --no-sandbox --disable-gpu --no-pdf-header-footer --print-to-pdf="${pdf}" "${html}"`;
return msg;
```

---

#### 13. Nó `fn_heartbeat` — `Keepalive InfluxDB`
- **ID:** `fn_heartbeat`
- **Tipo:** `function` (1 entrada, 2 saídas)
  - *Saída 0:* Setpoint travado para InfluxDB (somente durante o teste)
  - *Saída 1:* Estado da válvula para o painel de status do Grafana
- **Função:** Disparado a cada 2 segundos. Mantém as séries temporais preenchidas no InfluxDB, permitindo que a linha de setpoint no Grafana acompanhe exatamente o ensaio corrente sem descontinuidades temporais.

```javascript
// Roda a cada 2 s.
// Saída 1: setpoint TRAVADO no início do teste -> InfluxDB, SOMENTE enquanto há teste em andamento.
// Saída 2: estado da válvula (keepalive para o painel de status do Grafana).
let out1 = null;
if (flow.get('ativo') === true) {
    const sp = flow.get('sp_travado');
    if (sp !== undefined && sp !== null && !isNaN(Number(sp))) out1 = { payload: Number(sp) };
}
const val = flow.get('valvula');
return [out1, { payload: (val === true || val === 1 || val === 'true') }];
```

---

## 5. GUIA RÁPIDO DE MANUTENÇÃO PARA O TÉCNICO

### 5.1 Dicionário de Variáveis de Contexto (`flow.*`)

No Node-RED, você pode inspecionar e forçar todas as variáveis abrindo o menu lateral direito **Context Data -> flow**:

| Variável | Tipo | Descrição | Valor Típico |
|---|---|---|---|
| `flow.ativo` | `Boolean` | Flag mestre indicando se há um teste em execução | `true` ou `false` |
| `flow.equipamento` | `String` | Nome/código do equipamento inserido pelo operador | Ex: `"Bomba_01"` |
| `flow.equipamento_teste` | `String` | Nome do equipamento congelado no início do ensaio | Ex: `"Bomba_01"` |
| `flow.sp_travado` | `Number` | Pressão de teste travada no início do ensaio | Ex: `8.0` |
| `flow.hora_inicio_date` | `Number (ms)` | Timestamp epoch do instante que o teste começou | Ex: `1792074944000` |
| `flow.duracao_teste` | `Number (ms)` | Duração do ensaio em milissegundos | `3600000` (1 hora) |
| `flow.tempo_restante` | `Number` | Minutos inteiros restantes para o fim do teste | `60` a `0` |
| `flow.min` | `Number` | Menor pressão registrada desde o início | Ex: `7.85` |
| `flow.max` | `Number` | Maior pressão registrada desde o início | Ex: `8.05` |
| `flow.soma` | `Number` | Somatório das amostras para cálculo de média | Ex: `14400.2` |
| `flow.qtd` | `Number` | Quantidade de amostras integradas | Ex: `1800` |
| `flow.historico` | `Array` | Buffer em memória dos pontos `{v, t}` | `[{v:8.0, t:...}, ...]` |
| `flow.motor_on` | `Boolean` | Estado do switch manual do motor hidráulico | `true` ou `false` |
| `flow.valvula_manual_on` | `Boolean` | Estado do switch manual da válvula solenoide | `true` ou `false` |
| `flow.valvula` | `Boolean` | Leitura digital física da válvula no CLP (`_IO_EM_DO_00`) | `true` ou `false` |
| `flow.aviso_status` | `Object` | Mensagem de intertravamento temporária exibida na IHM | `{payload, color, ate}` |

---

### 5.2 Como Intervir ou Destravar o Sistema em Tempo Real

Se por qualquer motivo operacional (ex.: queda de energia no CLP ou operador clicou sem preencher) a interface ficar com botões travados ou o sistema pensar que está em teste:
1. Abra o Node-RED em `http://localhost:1880`.
2. No menu superior direito, clique na aba **Context Data**.
3. Expanda a seção **Flow** e localize a variável `ativo`.
4. Altere `ativo` para `false` ou simplesmente clique no botão de deploy rápido.
5. Alternativamente, envie um inject manual com o payload `"PARADO"` diretamente na entrada do nó `Habilitar / Bloquear UI` (`fn_ui_lock`). Todos os botões serão liberados instantaneamente.

---

### 5.3 Como Alterar a Tolerância de Aprovação (Padrão 0.5 bar)

Para calibrar o critério de aceitação do teste:
1. Abra o nó `Finaliza _Teste` (`6d54da2809aedd4d`).
2. Localize a linha:
   ```javascript
   let tolerancia = 0.5;
   ```
3. Modifique para o novo valor desejado (ex.: `0.3` para requisitos mais rigorosos ou `1.0` para linhas flexíveis).
4. Clique em **Done** e depois em **Deploy**.

---

### 5.4 Como Alterar a Duração Padrão do Teste (Padrão 60 Minutos)

Se o procedimento de ensaio exigir 30 minutos ou 120 minutos:
1. No nó `Inicia teste` (`49589c46b3396a0f`):
   ```javascript
   // Para 30 minutos: 30 * 60 * 1000 = 1800000 ms
   // Para 60 minutos: 3600000 ms
   flow.set("duracao_teste", 3600000);
   ```
2. No nó `Finaliza _Teste` (`6d54da2809aedd4d`):
   ```javascript
   let duracao = 60 * 60 * 1000; // Ajuste para a mesma duração em ms
   ```
3. Se desejar marcadores no gráfico com intervalos diferentes, atualize as chamadas de `horaOffset(...)` dentro do nó `Finaliza _Teste`.
4. Clique em **Done** e **Deploy**.

---

### 5.5 Como Alterar a Faixa de Pressão (Setpoint) na IHM

1. No nó `PRESSÃO DESEJADA` (tipo `ui_numeric`):
   - Abra as propriedades do nó.
   - Ajuste os campos **Min**, **Max** e **Step** (atualmente configurado para `0` a `10` bar, passo `0.1`).
2. Clique em **Done** e **Deploy**.

---

## 6. MATRIZ DE DIAGNÓSTICO E RESOLUÇÃO DE PROBLEMAS (TROUBLESHOOTING)

| Sintoma | Causa Mais Provável | Procedimento de Correção |
|---|---|---|
| **CLP Offline / Erro de Leitura no Node-RED** | Cabo de rede desconectado ou IP da máquina fora da faixa `192.168.1.x`. | 1. Teste o ping com `ping 192.168.1.33`.<br>2. Verifique se o IP cabeado do PC está configurado como `192.168.1.100 / 24` sem gateway.<br>3. Certifique-se de que a luz LINK da porta Ethernet do Micro850 está acesa verde. |
| **Erro "TIMEOUT Controller Props"** | O shim do Micro800 não foi carregado pelo Node-RED. | Verifique se o `settings.js` contém o bloco `try { Controller.prototype.write_cip = ... }` e reinicie o contêiner (`docker compose restart nodered`). |
| **Botão INICIAR TESTE não inicia e fica vermelho** | Intertravamento de segurança bloqueou a partida. | Leia a mensagem exibida na tarja: desligue o motor, feche a válvula, preencha o nome do equipamento e certifique-se de que a pressão desejada foi informada. |
| **PDF não aparece na pasta `./relatorios`** | Falha na execução do Chromium headless. | 1. Inspecione os logs: `docker compose logs --tail 50 nodered`.<br>2. Verifique permissões da pasta: `ls -la relatorios`.<br>3. Verifique se o contêiner foi construído com `Dockerfile.nodered` (contendo o pacote `chromium`). |
| **Grafana sem dados ou com tela "No Data"** | InfluxDB reiniciado com novo token ou URL inacessível. | 1. Acesse o InfluxDB em `http://localhost:8086`.<br>2. Confirme que a organização `vigor` e o bucket `carrinho` existem.<br>3. No Grafana (`http://localhost:3000`), teste a conexão em **Data Sources -> InfluxDB-Flux**. |
| **Data/Hora do relatório PDF defasada (fuso UTC)** | Renderização sem timeZone configurado. | O nó `Finaliza _Teste` já utiliza `timeZone: 'America/Sao_Paulo'`. Não utilize `new Date().toISOString()` para evitar retorno ao horário de Greenwich. |

---

## 7. DISPOSIÇÕES FINAIS E SUPORTE TÉCNICO

O projeto está totalmente isolado e pronto para operar de forma perene e independente em ambiente de chão de fábrica. Não há dependências de nuvem, telemetria remota ou pacotes obsoletos. Qualquer modificação futura de fluxo deve ser comitada no Git e documentada sequencialmente na pasta `historico_execucoes/`.

# DOSSIÊ TÉCNICO DE MANUTENÇÃO E OPERAÇÃO
## Sistema SCADA / IoT - Bancada de Teste de Pressão Hidrostática
**Controlador:** Rockwell Micro850 (2080-L50E) | **Supervisório:** Node-RED 5.0.8 (Dashboard 3.6.6) | **Banco:** InfluxDB 2.7.12 | **Dashboards:** Grafana 13.2.4  
**Compatibilidade:** Linux (Ubuntu 20.04/22.04/24.04 LTS) e Windows 10/11 (Docker Desktop / WSL2)  
**Ambiente:** 100% Offline (Air-gapped)

---

## SUMÁRIO EXECUTIVO

Este documento é a referência definitiva de engenharia de automação e software para manutenção, calibração, diagnóstico e operação do sistema de teste hidrostático da bancada.

O sistema executa testes de estanqueidade e integridade mecânica com duração configurável de **10 a 60 minutos** (passo de 5 minutos, padrão 60 minutos, com travamento multinível `duracao_travada` durante o ensaio), monitorando continuamente a conectividade CIP com o CLP (`flow.plc_online`), registrando toda a faixa de pressão de **`0,00` a `10,00 bar`** (incluindo detecção de despressurização total / rompimento e keepalive de `2 s` em regime estacionário), garantindo sincronia imediata e bidirecional de Setpoint com o CLP sem atraso de `0,5 bar`, calculando indicadores estatísticos exatos sobre a janela filtrada do ensaio (**média ponderada no tempo por retenção de ordem zero / ZOH**, mínima, máxima e tolerância bilateral simétrica **`Setpoint ± 0,5 bar`**) e gerando relatórios de ensaio em formato **PDF A4 Paisagem de página única** com gráfico vetorial SVG panorâmico dinâmico (`clipPath`, ancoragem adaptativa de falha e HTML temporário isolado em `/tmp`), além de prover telas de operação no Node-RED Dashboard (`/ui`) e análise histórica no Grafana (`uid: InfluxDB-Flux`).

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
[extra_hosts -> host-gateway]                                   [DNS alias -> influxdb:8086]
        |                                                                   |
        v                                                                   v
+-----------------------+                                   +-----------------------+
|  NODE-RED (Port 1880) |                                   |  NODE-RED (Port 1880) |
|  - Shim CIP 7 camadas |                                   |  - Shim CIP 7 camadas |
|  - Chromium Headless  |                                   |  - Chromium Headless  |
+-----------------------+                                   +-----------------------+
        |                                                                   |
        +---------------------------------+---------------------------------+
                                          | (HTTP API v2: host.docker.internal:8086)
                                          v
                              +-----------------------+
                              | INFLUXDB 2.7.12(:8086)|
                              | Org: vigor            |
                              | Bucket: carrinho      |
                              +-----------------------+
                                          | (Flux Query / uid: InfluxDB-Flux)
                                          v
                              +-----------------------+
                              | GRAFANA 13.2.4 (:3000)|
                              |  Dashboard Dinâmico   |
                              +-----------------------+
```

### 1.1 Tags Globais do CLP Micro850
Toda a comunicação do CLP foi unificada e homologada para o Micro850 via CIP nativo (Message Router não roteado, ciclo de scan de `500 ms`). **Não existe qualquer resquício de comandos legados PCCC / DF1 (como `F8:0`, `N7:1`, etc.).**

| Tag no CLP | Tipo de Dado | Sentido | Descrição Funcional |
|---|---|---|---|
| `RETORNO_BAR` | `REAL` | CLP -> Node-RED | Pressão instantânea lida pelo transmissor analógico (`0,00` a `10,00 bar`). |
| `_IO_EM_DO_00` | `BOOL` | CLP -> Node-RED | Feedback elétrico da saída digital 00 (Válvula solenoide). |
| `_IO_EM_DO_01` | `BOOL` | CLP -> Node-RED | Feedback elétrico da saída digital 01 (Bomba hidráulica / Motor). |
| `COMPARACAO` | `BOOL` | CLP -> Node-RED | Comparador interno do CLP (`true` quando pressão >= setpoint), acionando corte definitivo do motor. |
| `setpoint_node` | `REAL` | Bidirecional | Pressão desejada configurada pelo operador ou lida/confirmada do CLP (sincronia Float32 IEEE-754). |
| `on_node` | `BOOL` | Node-RED -> CLP | Comando Liga Motor (Linha 5 Ladder CLP - aciona Set em `bar_auto`). |
| `off_node` | `BOOL` | Node-RED -> CLP | Comando Desliga Motor / Pulso de RESET de `400 ms` ao Liberar Manual ou atingir Setpoint (Linha 6 Ladder CLP). |
| `onval_node` | `BOOL` | Node-RED -> CLP | Comando Abre Válvula (Linha 8 Ladder CLP - aciona Set em `_IO_EM_DO_00`). |
| `offval_node` | `BOOL` | Node-RED -> CLP | Comando Fecha Válvula / Pulso de RESET de `400 ms` ao Liberar Manual (Linha 9 Ladder CLP). |
| `ciclo_node` | `BOOL` | Node-RED -> CLP | **Sinal de Teste em Andamento**: `true` durante o teste, `false` no boot/parada e re-sincronizado na reconexão CIP. |

---

## 2. ÁRVORE COMPLETA DE ARQUIVOS DO PROJETO

```
clp_iot/
├── .env.example                       # Modelo de variáveis de ambiente do InfluxDB e Grafana
├── .gitattributes                     # Normalização de finais de linha (LF/CRLF)
├── .gitignore                         # Regras de exclusão de dados dinâmicos, credenciais e PDFs
├── Dockerfile.nodered                 # Imagem customizada Alpine do Node-RED 5.0.8 com Chromium Headless
├── README.md                          # Guia rápido de introdução e operação offline
├── docker-compose.windows.yml         # Orquestração Docker para Windows 10/11 (versões fixadas + DNS iot-network)
├── docker-compose.yml                 # Orquestração Docker para Linux (network_mode: host)
├── docker-entrypoint.sh               # Inicialização offline segura sem downloads externos
├── iniciar-sistema.bat                # Atalho Windows para subida 100% offline
├── parar-sistema.bat                  # Atalho Windows para parada limpa dos serviços
├── docs/                              # Documentação oficial centralizada de engenharia e operação
│   ├── DOSSIE_TECNICO_MANUTENCAO.md   # Documento mestre de engenharia e manutenção (este arquivo)
│   ├── README.md
│   ├── RELATORIO_MIGRACAO_WINDOWS.md
│   ├── RESUMO_EXECUCAO.md             # Ponteiro central para a execução mais recente (Versão 10)
│   └── RESUMO_PROJETO_SCADA.md
├── scripts/                           # Scripts modulares por sistema operacional
│   ├── README.md
│   ├── linux/
│   │   ├── README.md
│   │   ├── iniciar-sistema.sh
│   │   ├── parar-sistema.sh
│   │   └── setup-linux.sh
│   └── windows/
│       ├── README.md
│       ├── enviar-github.bat
│       ├── exportar-imagens-offline.bat
│       ├── iniciar-sistema.bat
│       ├── parar-sistema.bat
│       └── setup-windows.ps1
├── grafana_provisioning/              # Provisionamento automático de Data Sources e Dashboards
│   ├── dashboards/
│   │   ├── dashboards.yaml
│   │   └── pressao_hidrostatica.json  # Dashboard dinâmico de Pressão, Setpoint e Válvula
│   └── datasources/
│       └── influxdb.yaml              # Conexão determinística (uid: InfluxDB-Flux) ao InfluxDB 2.7.12
├── historico_execucoes/               # Registro cronológico imutável de todas as intervenções
│   ├── 01_RESUMO_EXECUCAO_comissionamento_rede_shim_cip.md
│   ├── 02_RESUMO_EXECUCAO_multiplataforma_docker_pdf.md
│   ├── 03_RESUMO_EXECUCAO_intertravamentos_laudo_individual_grafana.md
│   ├── 04_RESUMO_EXECUCAO_auditoria_limpeza_dossie.md
│   ├── 05_RESUMO_EXECUCAO_operacao_100pct_offline_windows_linux.md
│   ├── 06_RESUMO_EXECUCAO_controles_3_posicoes_intertravamento_fisico_mobile.md
│   ├── 07_RESUMO_EXECUCAO_tempo_restante_selecionavel_e_responsividade_mobile.md
│   ├── 08_RESUMO_EXECUCAO_corte_setpoint_comparacao_e_reset_liberar_manual.md
│   ├── 09_RESUMO_EXECUCAO_grafico_dinamico_sincronia_setpoint_e_influx_windows.md
│   ├── 10_RESUMO_EXECUCAO_auditoria_hardening_metrologia_cip_desempenho.md
│   └── README.md
├── nodered_data/                      # Volume persistente do Node-RED (/data)
│   ├── flows.json                     # Fluxo oficial limpo e validado (56 objetos JSON / 18 functions)
│   ├── package.json                   # Dependências npm estritas e homologadas (sem pacotes órfãos)
│   ├── package-lock.json              # Lockfile determinístico
│   ├── settings.js                    # Configurações do Node-RED + Shim CIP Micro800 de 7 camadas
│   └── node_modules/                  # Dependências locais para operação 100% Air-Gapped
└── relatorios/                        # Pasta no host onde os laudos PDF A4 Paisagem são gravados
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
    pull_policy: missing
    # Linux: network_mode: host permite comunicação direta em camada 2/3 com o Micro850 (192.168.1.33)
    # via interface física enp58s0 sem passar pelo NAT do Docker.
    network_mode: host
    volumes:
      - ./nodered_data:/data
      - ./relatorios:/data/relatorios
      - ./docker-entrypoint.sh:/usr/local/bin/docker-entrypoint.sh:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
    depends_on:
      - influxdb

  influxdb:
    image: influxdb:2.7
    container_name: influxdb
    pull_policy: missing
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
      - INFLUXD_REPORTING_DISABLED=true
    volumes:
      - ./influxdb_data:/var/lib/influxdb2
      - ./influxdb_config:/etc/influxdb2
    restart: unless-stopped
    networks:
      - iot-network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    pull_policy: missing
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}
      # 100% Offline: desativa envio de telemetria, checagem de atualizações e notícias externas
      - GF_ANALYTICS_REPORTING_ENABLED=false
      - GF_ANALYTICS_CHECK_FOR_UPDATES=false
      - GF_NEWS_NEWS_FEED_ENABLED=false
      - GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS=
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
> **Compatibilidade Multiplataforma de `host.docker.internal` e Pinagem Determinística:** No Windows (Docker Desktop / WSL2), as imagens estão fixadas nas versões exatas homologadas localmente (`clp_iot-nodered:latest` sobre `nodered/node-red:5.0.8`, `influxdb:2.7.12` e `grafana/grafana:13.2.4`). O serviço `nodered` compartilha a bridge `iot-network` com o `influxdb`, onde o `influxdb` publica o alias de rede `host.docker.internal`. **Não** se deve declarar `extra_hosts: ["host.docker.internal:host-gateway"]` no `nodered` do Windows, evitando injeção de `192.168.65.254` em `/etc/hosts`.

```yaml
services:
  nodered:
    build:
      context: .
      dockerfile: Dockerfile.nodered
    image: clp_iot-nodered:latest
    container_name: nodered
    pull_policy: missing
    # Windows (Docker Desktop via WSL2): expõe a porta 1880 diretamente no Windows
    # e conecta na iot-network. A comunicação com InfluxDB é feita via host.docker.internal.
    ports:
      - "1880:1880"
    networks:
      - iot-network
    volumes:
      - ./nodered_data:/data
      - ./relatorios:/data/relatorios
      - ./docker-entrypoint.sh:/usr/local/bin/docker-entrypoint.sh:ro
    restart: unless-stopped
    depends_on:
      - influxdb

  influxdb:
    image: influxdb:2.7.12
    container_name: influxdb
    pull_policy: missing
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
      - INFLUXD_REPORTING_DISABLED=true
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
    image: grafana/grafana:13.2.4
    container_name: grafana
    pull_policy: missing
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}
      # 100% Offline: desativa envio de telemetria, checagem de atualizações e notícias externas
      - GF_ANALYTICS_REPORTING_ENABLED=false
      - GF_ANALYTICS_CHECK_FOR_UPDATES=false
      - GF_NEWS_NEWS_FEED_ENABLED=false
      - GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS=
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
FROM nodered/node-red:5.0.8

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

### 3.3.1 `grafana_provisioning/datasources/influxdb.yaml`
> **UID Determinístico (`uid: InfluxDB-Flux`):** Garante que os 7 painéis provisionados em `pressao_hidrostatica.json` encontrem o datasource tanto em instalações novas quanto em atualizações sobre volumes `grafana_data/grafana.db` pré-existentes (via `deleteDatasources` + recriação atômica no boot).

```yaml
apiVersion: 1

deleteDatasources:
  - name: InfluxDB-Flux
    orgId: 1

datasources:
  - name: InfluxDB-Flux
    uid: InfluxDB-Flux
    type: influxdb
    access: proxy
    url: http://influxdb:8086
    isDefault: true
    jsonData:
      version: Flux
      organization: vigor
      defaultBucket: carrinho
      httpMode: POST
    secureJsonData:
      token: ${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}
    editable: true
```

### 3.4 `docker-entrypoint.sh`
```bash
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
```

### 3.5 O Shim CIP Micro800 de 7 Camadas em `nodered_data/settings.js` e `ethernet-ip.js`
> **Problemas Resolvidos pelo Shim CIP de 7 Camadas (Versionado no Git):**
> 1. **Limpeza Determinística de Timers (`utilities.promiseTimeout`):** Na biblioteca `ethernet-ip` original, `promiseTimeout` não executava `clearTimeout` após a resolução da Promise, mantendo objetos `Timeout` retidos até expirarem (notadamente em tentativas de reconexão de 10 s com CLP desligado). O shim aplica `clearTimeout` no `.finally()` antes de carregar `Controller`.
> 2. **Roteamento Direto Micro800 (`Controller.prototype.write_cip`):** A família Micro800 (Micro820/850/870) não possui backplane e rejeita `Unconnected Send` roteado para Porta 1/Slot 0. O shim envia os pacotes CIP diretamente ao `Message Router` via `ENIPProto.write_cip`.
> 3. **Reassemblagem de Stream TCP ENIP (`ENIPProto._handleDataEvent` / `_handleCloseEvent`):** O handler nativo assumia que cada evento `socket.on('data')` continha exatamente 1 quadro EtherNet/IP completo de 24 bytes de cabeçalho + payload. O shim introduz um buffer acumulador (`this._rxBuf`) que reassembla segmentos TCP fragmentados e separa múltiplos pacotes ENIP coalescidos no mesmo frame TCP.
> 4. **Rastreamento Sequencial de Escritas In-Flight (`Tag.prototype.value` + `_write_seq` / `_inflight_seq`):** Como `Controller._writeTagGroup` é assíncrono sobre TCP, uma nova escrita em `tag.value` durante uma requisição CIP em trânsito (ex.: borda de descida `false` de um pulso de `400 ms` enquanto a escrita `true` sofreu latência de rede) seria limpa indevidamente por `unstageWriteRequest()`. O contador monotônico `_write_seq` preserva `stage_write = true` caso um valor mais novo tenha sido enfileirado durante o voo.
> 5. **Despacho Forçado CIP via `write_ready` (`TagGroup.prototype.generateWriteMessageRequests`):** Dispara `WRITE_TAG` sempre que `tag.value !== null && (tag.write_ready || tag.value !== tag.controller_value)`, registrando `_inflight_seq` e `_inflight_val` no instante exato da montagem do pacote CIP.
> 6. **Supressão de Leitura Pré-Escrita (`Tag.prototype.controller_value`):** Suprime emissões espúrias `"Initialized"` / `"Changed"` de leituras anteriores à escrita enquanto `stage_write === true`, eliminando o atraso crônico de `0,5 bar` no setpoint.
> 7. **Confirmação Pós-Escrita Seletiva e Normalização Float32 (`Tag.prototype.unstageWriteRequest`):** Só limpa `stage_write = false` quando `_write_seq === _inflight_seq`, normaliza tags `REAL` (`0xca`) com `Math.fround(Number(val))` (precisão IEEE-754 Float32) e confirma `this.controller_value` imediatamente.

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
    // 0. Limpeza imediata de timers de timeout (10 s) em ethernet-ip/src/utilities ANTES de carregar Controller
    const eipUtilities = require("/data/node_modules/ethernet-ip/src/utilities");
    eipUtilities.promiseTimeout = (promise, ms, error = new Error("ASYNC Function Call Timed Out!!!")) => {
        return new Promise((resolve, reject) => {
            const timer = setTimeout(() => reject(error), ms);
            promise.then(
                (val) => {
                    clearTimeout(timer);
                    resolve(val);
                },
                (err) => {
                    clearTimeout(timer);
                    reject(err);
                }
            );
        });
    };

    const { Controller, Tag, TagGroup, EthernetIP } = require("/data/node_modules/ethernet-ip");
    const { MessageRouter } = EthernetIP.CIP;
    const { MULTIPLE_SERVICE_PACKET } = MessageRouter.services;

    // 1. Roteamento Direto Micro800 (envia direto ao Message Router sem Unconnected Send / backplane)
    // Nota: Object.getPrototypeOf(Controller.prototype) retorna diretamente ENIP.prototype
    const ENIPProto = Object.getPrototypeOf(Controller.prototype);
    Controller.prototype.write_cip = function (data, connected = false, timeout = 10, cb = null) {
        ENIPProto.write_cip.call(this, data, connected, timeout, cb);
    };

    // 2. Buffer de Remontagem de Stream TCP ENIP (trata pacotes fragmentados < 24+len e pacotes coalescidos > 24+len)
    const origHandleData = ENIPProto._handleDataEvent;
    const origHandleClose = ENIPProto._handleCloseEvent;
    if (typeof origHandleData === "function") {
        ENIPProto._handleDataEvent = function (data) {
            if (!Buffer.isBuffer(data) || data.length === 0) return;

            this._rxBuf = (this._rxBuf && this._rxBuf.length > 0)
                ? Buffer.concat([this._rxBuf, data])
                : data;

            while (this._rxBuf && this._rxBuf.length >= 24) {
                const payloadLen = this._rxBuf.readUInt16LE(2);
                const frameLen = 24 + payloadLen;

                // Pacote TCP fragmentado: aguarda o restante dos bytes no próximo evento 'data'
                if (this._rxBuf.length < frameLen) break;

                let frame;
                if (this._rxBuf.length === frameLen) {
                    frame = this._rxBuf;
                    this._rxBuf = null;
                } else {
                    // Dois ou mais pacotes ENIP coalescidos no mesmo segmento TCP
                    frame = Buffer.from(this._rxBuf.subarray(0, frameLen));
                    this._rxBuf = Buffer.from(this._rxBuf.subarray(frameLen));
                }

                try {
                    origHandleData.call(this, frame);
                } catch (err) {
                    this._rxBuf = null;
                    this.emit("error", err);
                    break;
                }
            }
        };
    }
    if (typeof origHandleClose === "function") {
        ENIPProto._handleCloseEvent = function (hadError) {
            this._rxBuf = null;
            return origHandleClose.call(this, hadError);
        };
    }

    // 3. Rastreamento de sequência de escrita (protege pulsos rápidos de 400 ms como TRUE -> FALSE em trânsito)
    const valDesc = Object.getOwnPropertyDescriptor(Tag.prototype, "value");
    if (valDesc && typeof valDesc.set === "function") {
        Object.defineProperty(Tag.prototype, "value", {
            get: valDesc.get,
            set: function (newValue) {
                if (this.state && this.state.tag) {
                    this.state.tag._write_seq = (this.state.tag._write_seq || 0) + 1;
                    if (newValue === null) {
                        this.state.tag.value = null;
                        this.state.tag.stage_write = false;
                        this.state.tag._inflight_seq = undefined;
                        this.state.tag._inflight_val = undefined;
                        return;
                    }
                }
                return valDesc.set.call(this, newValue);
            },
            enumerable: valDesc.enumerable,
            configurable: true
        });
    }

    // 4. Despacho Forçado CIP via write_ready (stage_write) com snapshot da escrita em voo (_inflight_seq)
    TagGroup.prototype.generateWriteMessageRequests = function () {
        const { tags } = this.state;

        let messages = [];
        let msgArr = [];
        let tagIds = [];
        let messageLength = 0;

        for (let key of Object.keys(tags)) {
            const tag = tags[key];

            if (tag.value !== null && (tag.write_ready || tag.value !== tag.controller_value)) {
                if (tag.state && tag.state.tag) {
                    tag.state.tag._inflight_seq = tag.state.tag._write_seq || 0;
                    tag.state.tag._inflight_val = tag.value;
                }
                let msg = tag.generateWriteMessageRequest();

                messageLength += msg.length + 2;

                tagIds.push(tag.instance_id);
                msgArr.push(msg);

                if (messageLength >= 300) {
                    let buf = Buffer.alloc(2 + 2 * msgArr.length);
                    buf.writeUInt16LE(msgArr.length, 0);

                    let ptr = 2;
                    let offset = buf.length;

                    for (let i = 0; i < msgArr.length; i++) {
                        buf.writeUInt16LE(offset, ptr);
                        ptr += 2;
                        offset += msgArr[i].length;
                    }

                    buf = Buffer.concat([buf, ...msgArr]);
                    buf = MessageRouter.build(MULTIPLE_SERVICE_PACKET, this.state.path, buf);

                    messages.push({ data: buf, tag_ids: tagIds });
                    messageLength = 0;
                    msgArr = [];
                    tagIds = [];
                }
            }
        }

        if (msgArr.length > 0) {
            let buf = Buffer.alloc(2 + 2 * msgArr.length);
            buf.writeUInt16LE(msgArr.length, 0);

            let ptr = 2;
            let offset = buf.length;

            for (let i = 0; i < msgArr.length; i++) {
                buf.writeUInt16LE(offset, ptr);
                ptr += 2;
                offset += msgArr[i].length;
            }

            buf = Buffer.concat([buf, ...msgArr]);
            buf = MessageRouter.build(MULTIPLE_SERVICE_PACKET, this.state.path, buf);

            messages.push({ data: buf, tag_ids: tagIds });
        }

        return messages;
    };

    // 5. Supressão de leitura antiga durante escrita pendente (stage_write === true)
    const ctrlValDesc = Object.getOwnPropertyDescriptor(Tag.prototype, "controller_value");
    if (ctrlValDesc && typeof ctrlValDesc.set === "function") {
        Object.defineProperty(Tag.prototype, "controller_value", {
            get: ctrlValDesc.get,
            set: function (newValue) {
                if (this.state && this.state.tag && this.state.tag.stage_write === true) {
                    if (this.state.tag.value !== null) {
                        this.state.tag.controllerValue = newValue;
                        return;
                    }
                    this.state.tag.stage_write = false;
                }
                return ctrlValDesc.set.call(this, newValue);
            },
            enumerable: ctrlValDesc.enumerable,
            configurable: true
        });
    }

    // 6. Confirmação pós-escrita segura contra corrida em voo + normalização IEEE-754 Float32 para REAL (0xca)
    Tag.prototype.unstageWriteRequest = function () {
        const { tag } = this.state;
        const hasInflight = tag._inflight_seq !== undefined;
        const sentRaw = hasInflight ? tag._inflight_val : tag.value;
        const normalizedSent = (tag.type === 0xca && sentRaw !== null && !isNaN(Number(sentRaw)))
            ? Math.fround(Number(sentRaw))
            : sentRaw;

        const superseded = hasInflight && tag._write_seq !== tag._inflight_seq;
        tag._inflight_seq = undefined;
        tag._inflight_val = undefined;

        if (superseded) {
            // Uma nova escrita (ex.: fim do pulso FALSE após 400 ms) entrou na fila enquanto o pacote anterior estava em trânsito.
            // Registra o valor confirmado no CLP sem apagar stage_write, garantindo o envio da nova escrita no próximo ciclo.
            tag.controllerValue = normalizedSent;
            tag.stage_write = (tag.value !== null);
            return;
        }

        tag.stage_write = false;
        if (tag.type === 0xca && tag.value !== null && !isNaN(Number(tag.value))) {
            tag.value = normalizedSent;
        }
        this.controller_value = normalizedSent;
    };

    console.log("[micro800-shim] ethernet-ip patched: direct Message Router + TCP framing + inflight write guard + timer cleanup + REAL sync");
} catch (e) {
    console.warn("[micro800-shim] not applied:", e.message);
}
```

Complementarmente, em `nodered_data/node_modules/node-red-contrib-cip-ethernet-ip/red/ethernet-ip.js` (`EthIpOut` -> `onNewMsg`), mantém-se o tratador limpo sem zerar `controllerValue`:
```javascript
        function onNewMsg(msg, send, done) {
            //the actual write will be performed by the scan cycle
            //of the Controller on the endpoint
            tag.value = statusVal = msg.payload;
            // we currently have no feedback of the written value, so
            // let's just call done() here
            done();

            node.status(generateStatus(node.endpoint.getStatus(), statusVal));
        }
```

### 3.6 `scripts/linux/setup-linux.sh`
```bash
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
```

### 3.7 `scripts/windows/setup-windows.ps1`
```powershell
# ==============================================================================
# INICIALIZAÇÃO DO SISTEMA SCADA / IoT - BANCADA DE PRESSÃO HIDROSTÁTICA
# Ambiente: Windows (Docker Desktop com WSL2)
# ==============================================================================

# Garante que o diretório de trabalho seja a raiz do projeto (onde está docker-compose.windows.yml)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (Test-Path "$scriptDir\..\..\docker-compose.windows.yml") {
    Set-Location (Resolve-Path "$scriptDir\..\..")
} elseif (Test-Path "$scriptDir\docker-compose.windows.yml") {
    Set-Location $scriptDir
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "   INICIALIZAÇÃO DO SISTEMA SCADA / IoT - BANCADA DE PRESSÃO     " -ForegroundColor Cyan
Write-Host "             Ambiente: Windows (Docker Desktop)                  " -ForegroundColor Cyan
Write-Host "             Diretório: $(Get-Location)                          " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# 1. Configuração do arquivo de variáveis de ambiente (.env)
if (-not (Test-Path ".env")) {
    Write-Host "[1/4] Criando arquivo .env a partir de .env.example..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host "       .env criado com sucesso." -ForegroundColor Green
} else {
    Write-Host "[1/4] Arquivo .env já existe. Mantendo configurações locais." -ForegroundColor Green
}

# 1.1 Configuração automática das credenciais do Node-RED para InfluxDB
$credPath = "nodered_data/flows_cred.json"
if (-not (Test-Path $credPath)) {
    Write-Host "       Provisionando credencial do InfluxDB para o Node-RED..." -ForegroundColor Yellow
    $token = "mDT86-v55lCtaReP2ECGeXKz0bdrsDg3Kn5693it6YOaI-ITNpMWW-MQqWi3X-YWkBwbSEvQMuT3SWAK13N8NA=="
    if (Test-Path ".env") {
        $envToken = Get-Content ".env" | Where-Object { $_ -match "^DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=(.*)$" } | ForEach-Object { $matches[1].Trim() }
        if ($envToken) { $token = $envToken }
    }
    $credJson = @{
        "235fd83d5ce9ea5d" = @{
            "token" = $token
        }
    } | ConvertTo-Json
    Set-Content -Path $credPath -Value $credJson -Encoding UTF8
    Write-Host "       flows_cred.json provisionado com sucesso." -ForegroundColor Green
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

# 3. Orientação e Verificação da Placa de Rede para o CLP Micro850 (100% Offline)
Write-Host "[3/4] Verificando adaptadores de rede e conectividade com o CLP..." -ForegroundColor Yellow
try {
    $adaptadores = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" -and $_.MediaType -eq "802.3" }
    if ($adaptadores) {
        Write-Host "       Adaptador Ethernet ativo detectado: $($adaptadores[0].Name)" -ForegroundColor Cyan
        $ipAtual = Get-NetIPAddress -InterfaceAlias $adaptadores[0].Name -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -like "192.168.1.*" }
        if ($ipAtual) {
            Write-Host "       [OK] Adaptador possui IP estático na sub-rede industrial (192.168.1.x): $($ipAtual.IPAddress)" -ForegroundColor Green
        } else {
            Write-Host "       [AVISO] Configure o IP estático na placa cabeada do Windows:" -ForegroundColor Yellow
            Write-Host "               IP: 192.168.1.100 ou 192.168.1.200 | Máscara: 255.255.255.0 | Gateway: (em branco)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "       [INFO] Conecte o cabo Ethernet entre o computador e o CLP Micro850 (IP fixo 192.168.1.33)." -ForegroundColor Yellow
    }

    # Teste de conectividade com o CLP (sem depender de DNS ou internet)
    $pingClp = Test-Connection -ComputerName "192.168.1.33" -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($pingClp) {
        Write-Host "       [OK] Comunicação com o CLP Micro850 (192.168.1.33) confirmada!" -ForegroundColor Green
    } else {
        Write-Host "       [INFO] CLP 192.168.1.33 ainda não respondeu ao ping (verifique cabo/alimentação)." -ForegroundColor Gray
    }
} catch {
    Write-Host "       Verificação automática de rede ignorada: $($_.Exception.Message)" -ForegroundColor Gray
}

# 4. Inicialização do Docker Compose no Windows (100% Offline)
Write-Host "[4/4] Verificando Docker e iniciando contêineres em modo 100% offline..." -ForegroundColor Yellow
$dockerOk = $false
try {
    $null = docker ps 2>&1
    if ($LASTEXITCODE -eq 0) { $dockerOk = $true }
} catch {}

if (-not $dockerOk) {
    Write-Host "       Docker não está respondendo. Iniciando Docker Desktop..." -ForegroundColor Yellow
    $dockerPaths = @(
        "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe",
        "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    )
    foreach ($p in $dockerPaths) {
        if (Test-Path $p) {
            Start-Process $p
            break
        }
    }
    Write-Host "       Aguardando o serviço do Docker iniciar..." -ForegroundColor Gray
    $tentativas = 0
    while ($tentativas -lt 20) {
        Start-Sleep -Seconds 3
        try {
            $null = docker ps 2>&1
            if ($LASTEXITCODE -eq 0) {
                $dockerOk = $true
                break
            }
        } catch {}
        $tentativas++
    }
}

# Carregamento automático de imagens offline (.tar) se existirem na pasta
$tarFiles = Get-ChildItem -Path "." -Filter "*.tar" -ErrorAction SilentlyContinue
foreach ($tar in $tarFiles) {
    Write-Host "       Carregando imagem offline: $($tar.Name)..." -ForegroundColor Cyan
    docker load -i $tar.FullName
}

# Execução offline: Se a imagem já existe no Docker local, NÃO recompila (evita chamadas apk/alpine)
$hasNodeRed = docker images -q clp_iot-nodered:latest
if ($hasNodeRed) {
    Write-Host "       [MODO OFFLINE] Imagem 'clp_iot-nodered:latest' encontrada no cache local." -ForegroundColor Green
    Write-Host "       Subindo serviços sem qualquer consulta à internet..." -ForegroundColor Green
    docker compose -f docker-compose.windows.yml up -d
} else {
    Write-Host "       [AVISO] Imagem 'clp_iot-nodered:latest' ausente no Docker." -ForegroundColor Yellow
    Write-Host "       Tentando compilação local (requer conexão ou cache de pacotes)..." -ForegroundColor Yellow
    docker compose -f docker-compose.windows.yml up -d --build
}

Write-Host "=================================================================" -ForegroundColor Green
Write-Host "   SISTEMA SCADA EM EXECUÇÃO NO WINDOWS (100% OFFLINE):          " -ForegroundColor Green
Write-Host "   - Supervisório / IHM Operador : http://localhost:1880/ui      " -ForegroundColor Cyan
Write-Host "   - Editor de Fluxos Node-RED   : http://localhost:1880         " -ForegroundColor Cyan
Write-Host "   - InfluxDB 2.7 (Dados/Tokens) : http://localhost:8086         " -ForegroundColor Cyan
Write-Host "   - Grafana (Gráficos Flux)     : http://localhost:3000         " -ForegroundColor Cyan
Write-Host "   - Pasta de Relatórios PDF/HTML: .\relatorios                  " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Green
```

---

## 4. MAPEAMENTO COMPLETO DO FLUXO DO NODE-RED (`flows.json`)

O fluxo do Node-RED é composto por **56 objetos JSON** (1 aba, 4 nós de configuração e 51 nós funcionais/visuais, incluindo **18 nós `function`**) organizados em blocos lógicos sem sobreposição no canvas e sem duplicidade de escrita no InfluxDB.

### 4.1 Visão Geral dos Blocos Lógicos

```
[Status CLP (PRESSAO)] -------> (fn_status_clp) -----------------------> [CLP: ciclo_node sync / boot=false]
[IHM: Equipamento (100ms)] ---> (fn_set_eq: Salvar Equipamento)
[IHM: Motor 3 Posições] ------> (fn_ctrl_motor_manual: Pulso 400ms) ---> [CLP: on_node / off_node]
[IHM: Válvula 3 Posições] ----> (fn_ctrl_valvula_manual: Pulso 400ms) -> [CLP: onval_node / offval_node]
[IHM: PRESSÃO DESEJADA] ------> [CLP: setpoint_node] & (fn_cache_setpoint) & [IHM: Pressão definida]
[CLP: setpoint_node] ---------> (fn_cache_setpoint_plc: Anti-Eco) -----> [IHM: Pressão definida & PRESSÃO DESEJADA]
[IHM: Seletor Tempo 10..60m] <> (fn_set_tempo_restante: Trava ativo)

[CLP: RETORNO_BAR (500ms)] ---> [InfluxDB: PT-010 (398b99857e5197e4)]
                            +-> (7d655f41: Coleta pressão >= 0.00 bar) -> [IHM: Manômetro gauge]
                            +-> (fn_auto_cutoff_sp: sem storm CIP) <---- [CLP: COMPARACAO (x:160, y:620)]
                                         |
                                         +-----------------------------> [CLP: on_node=0 / off_node pulso 400ms] & [IHM: MOTOR=3]
[CLP: _IO_EM_DO_01 (Bomba)] --> (fn_cache_bomba)
[CLP: _IO_EM_DO_00 (Válvula)] > (fn_cache_valvula) --------------------> [InfluxDB: vp-01]
(Inject 2s) ------------------> (fn_heartbeat: 4 saídas) --------------> [InfluxDB: setpoint & vp-01 & PT-010 keepalive] & (Coleta pressão)

[IHM: INICIAR TESTE] ---------> (49589c46: Inicia teste + seed t0) ----> [CLP: ciclo_node = true]
                                                                    +--> [InfluxDB: setpoint travado]
                                                                    +--> (fn_ui_lock: 11 saídas - Bloqueia UI & Zera Tags)
(Inject 1s) ------------------> (5214bd83: Decremento de tempo dedup) -> [IHM: Seletor Tempo & Status]
                                         | (tempo esgotado -> FINALIZAR_AUTO)
                                         v
[IHM: FINALIZAR TESTE] -------> (6d54da28: Finaliza _Teste ZOH ±0,5) --> [CLP: ciclo_node = false]
                                         |                          +--> (fn_ui_lock: 11 saídas - Libera UI)
                                         v                          +--> [InfluxDB: ponto final setpoint]
                                [8525c1d0: Relatório HTML/SVG A4 Paisagem (clipPath)]
                                         v
                                (4e72940d: /tmp/laudo_<basePdf>.html) -> (e32ec29a: Comando Chromium)
                                         v
                                [38510ae3: Gerar PDF (Chromium 30s)] --> (fn_verifica_pdf: Limpa /tmp & Alerta IHM)
```

1. **Supervisão Online/Offline do CLP e Resiliência de `ciclo_node`:** O nó `status_clp_endpoint` monitora o estado de conexão CIP de `PRESSAO` (`fba7dcc329b4be25`) e alimenta `fn_status_clp`, que atualiza `flow.plc_online`, bloqueia a partida do ensaio se o CLP estiver desconectado, garante `ciclo_node = false` no boot do Node-RED e re-envia o estado vigente de `ciclo_node` caso o cabo Ethernet reconecte durante um ensaio.
2. **Cobertura Completa de `0,00 bar` e Keepalive Estacionário de `2 s`:** `Coleta pressão` aceita `valor >= 0` (`Number.isFinite(valor) && valor >= 0`), permitindo ao manômetro exibir `0,00 bar` na despressurização e detectando rompimento catastrófico em ensaio ativo. Quando `RETORNO_BAR` permanece estritamente constante no CLP (sem evento `Changed`), `fn_heartbeat` injeta keepalive periódico a cada `2 s` tanto em `PT-010` quanto em `Coleta pressão`.
3. **Poda Amortizada $O(1)$ de Alta Performance:** Em vez de realocar o array com `Array.filter` a cada amostra ($O(N^2)$ acumulado), `Coleta pressão` avança um ponteiro na cabeça ordenada temporalmente e aplica `historico.slice(corte)` apenas quando necessário, reduzindo o processamento de 72.000 amostras de `~48 s` para `~44 ms` (ganho > 1.000x).
4. **Corte Definitivo no Setpoint Sem Tempestade CIP:** `fn_auto_cutoff_sp` avalia `sp_travado` somente com `ativo === true` (limpando `sp_travado = null` ao finalizar), cancela timers pendentes via `motor_cmd_seq`, preserva `enabled: false` no dropdown `MOTOR` durante ensaios e só dispara `WRITE_TAG` quando `motor_on`, `on_node` ou `bomba_fisica` estão ativos (eliminando 21.600 escritas CIP/hora redundantes).
5. **Metrologia Exata no Relatório (`Finaliza _Teste`):** `min`, `max` e `media` são extraídos exclusivamente de `historicoFiltrado` (`[inicio, fim]`, iniciando na amostra semeada em `t = inicio`), usando **média ponderada no tempo (integração ZOH)** imune à taxa variável de eventos `Changed` do driver CIP e **tolerância simétrica bilateral `Setpoint ± 0,5 bar`** (`Math.abs(erro) <= 0.5`), reprovando tanto queda excessiva de pressão (`erro > +0,5 bar`) quanto sobrepressão severa (`erro < -0,5 bar`).
6. **Geração Segura de PDF A4 Paisagem:** `Finaliza _Teste` grava cada HTML temporário em `/tmp/laudo_<basePdf>.html` (sem colisão concorrente), `Comando Chromium` inclui `--disable-dev-shm-usage`, o nó `exec` possui timeout de `30 s` e `fn_verifica_pdf` remove o HTML temporário e alerta o operador na tarja `STATUS` se `rc.code !== 0`.

---

### 4.2 CÓDIGO JAVASCRIPT INTEGRAL DE TODOS OS 18 NÓS `function`

Abaixo está o código JavaScript **EXATO e integral** contido em todos os 18 nós `function` de `nodered_data/flows.json`.

---

#### 1. Nó `fn_set_eq` — `Salvar Equipamento`
- **ID:** `fn_set_eq` | **Saídas:** `1` (sem fios conectados)
- **Função:** Armazena a identificação do equipamento digitada na IHM em `flow.equipamento` (bloqueado no backend se `flow.ativo === true`).

```javascript
if (flow.get('ativo') === true) return null;
flow.set('equipamento', msg.payload);
return null;
```

---

#### 2. Nó `fn_ctrl_motor_manual` — `Controle Motor Manual`
- **ID:** `fn_ctrl_motor_manual` | **Saídas:** `2` (`[0] on_node`, `[1] off_node`)
- **Função:** Controla o motor em 3 estados (bloqueado durante ensaio ativo), cancela timers obsoletos via contador sequencial `motor_cmd_seq` e dispara pulso de RESET de `400 ms` em `off_node` ao selecionar `LIBERAR MANUAL` (`3`).

```javascript
if (flow.get('ativo') === true) return null;

const val = Number(msg.payload);
const seq = (flow.get('motor_cmd_seq') || 0) + 1;
flow.set('motor_cmd_seq', seq);
flow.set('pulso_off_motor', false);

if (val === 1) { // 1: MOTOR LIGADO
    flow.set('corte_efetuado', false);
    flow.set('motor_on', true);
    flow.set('on_node', true);
    flow.set('off_node', false);
    node.send([{ payload: true }, { payload: false }]);
    return;
} else if (val === 2) { // 2: MOTOR DESLIGADO
    flow.set('motor_on', false);
    flow.set('on_node', false);
    flow.set('off_node', true);
    node.send([{ payload: false }, { payload: true }]);
    return;
} else { // 3: LIBERAR MANUAL
    flow.set('motor_on', false);
    flow.set('on_node', false);
    flow.set('off_node', true);
    flow.set('pulso_off_motor', true);

    node.send([{ payload: false }, { payload: true }]);

    setTimeout(() => {
        if (flow.get('motor_cmd_seq') !== seq) return;
        flow.set('pulso_off_motor', false);
        flow.set('off_node', false);
        node.send([null, { payload: false }]);
    }, 400);

    return;
}
```

---

#### 3. Nó `fn_ctrl_valvula_manual` — `Controle Válvula Manual`
- **ID:** `fn_ctrl_valvula_manual` | **Saídas:** `2` (`[0] onval_node`, `[1] offval_node`)
- **Função:** Controla a válvula em 3 estados (bloqueado durante ensaio ativo), cancela timers obsoletos via contador sequencial `valvula_cmd_seq` e dispara pulso de RESET de `400 ms` em `offval_node` ao selecionar `LIBERAR MANUAL` (`3`).

```javascript
if (flow.get('ativo') === true) return null;

const val = Number(msg.payload);
const seq = (flow.get('valvula_cmd_seq') || 0) + 1;
flow.set('valvula_cmd_seq', seq);

if (val === 1) { // 1: VÁLVULA ABERTA
    flow.set('valvula_manual_on', true);
    flow.set('onval_node', true);
    flow.set('offval_node', false);
    node.send([{ payload: true }, { payload: false }]);
    return;
} else if (val === 2) { // 2: VÁLVULA FECHADA
    flow.set('valvula_manual_on', false);
    flow.set('onval_node', false);
    flow.set('offval_node', true);
    node.send([{ payload: false }, { payload: true }]);
    return;
} else { // 3: LIBERAR MANUAL
    flow.set('valvula_manual_on', false);
    flow.set('onval_node', false);
    flow.set('offval_node', true);

    node.send([{ payload: false }, { payload: true }]);

    setTimeout(() => {
        if (flow.get('valvula_cmd_seq') !== seq) return;
        flow.set('offval_node', false);
        node.send([null, { payload: false }]);
    }, 400);

    return;
}
```

---

#### 4. Nó `fn_auto_cutoff_sp` — `Zeramento Automático Setpoint`
- **ID:** `fn_auto_cutoff_sp` | **Saídas:** `3` (`[0] on_node`, `[1] off_node`, `[2] dropdown MOTOR`)
- **Função:** Monitora `COMPARACAO` e `RETORNO_BAR` (avaliando `sp_travado` apenas quando `ativo === true`), corta o motor **somente** quando há comando/bomba ligada (eliminando tempestade de 21.600 escritas CIP/h com motor já desligado) e aplica pulso de RESET de `400 ms` com `motor_cmd_seq` preservando `enabled: false` durante ensaio ativo.

```javascript
// Monitora COMPARACAO e RETORNO_BAR para desligar o motor UMA ÚNICA VEZ ao atingir o setpoint.
let atingiuSetpoint = false;
const isComparacao = (typeof msg.payload === 'boolean' || msg.variable === 'COMPARACAO' || msg.topic === 'COMPARACAO');

if (isComparacao) {
    if (msg.payload === true || msg.payload === 1 || msg.payload === 'true') {
        atingiuSetpoint = true;
    }
} else {
    const pressao = Number(msg.payload);
    if (Number.isFinite(pressao)) {
        let sp = 0;
        if (flow.get('ativo') === true && flow.get('sp_travado') !== null && flow.get('sp_travado') !== undefined) {
            sp = Number(flow.get('sp_travado'));
        } else {
            const tUi = flow.get('sp_ui_t') || 0;
            const tPlc = flow.get('sp_plc_t') || 0;
            const cand1 = tUi >= tPlc ? flow.get('sp_ui') : flow.get('sp_plc');
            const cand2 = tUi >= tPlc ? flow.get('sp_plc') : flow.get('sp_ui');
            sp = Number(cand1 ?? cand2 ?? 0);
        }
        if (sp > 0 && pressao >= sp) {
            atingiuSetpoint = true;
        }
    }
}

if (!atingiuSetpoint) {
    flow.set('corte_efetuado', false);
    return null;
}

// Se o corte já foi efetuado neste ciclo de pressão, não emite pulso duplo
if (flow.get('corte_efetuado') === true) {
    return null;
}

// Só dispara o corte automático quando o motor/bomba está realmente ligado ou comandado,
// evitando tempestade de 21.600 escritas CIP/hora com motor desligado e preservando MOTOR DESLIGADO (2).
const motorLigado = (flow.get('motor_on') === true) ||
                    (flow.get('on_node') === true) ||
                    (flow.get('bomba_fisica') === true || flow.get('bomba_fisica') === 1);

if (!motorLigado || flow.get('pulso_off_motor') === true) {
    return null;
}

flow.set('corte_efetuado', true);
const seq = (flow.get('motor_cmd_seq') || 0) + 1;
flow.set('motor_cmd_seq', seq);
flow.set('motor_on', false);
flow.set('on_node', false);
flow.set('off_node', true);
flow.set('pulso_off_motor', true);

// Preserva enabled: false caso um ensaio esteja ativo (não remove disabled: true de replayMessages)
node.send([
    { payload: false },
    { payload: true },
    { payload: 3, enabled: flow.get('ativo') !== true }
]);

setTimeout(() => {
    if (flow.get('motor_cmd_seq') !== seq) return;
    flow.set('pulso_off_motor', false);
    flow.set('off_node', false);
    node.send([null, { payload: false }, null]);
}, 400);

return null;
```

---

#### 5. Nó `fn_cache_bomba` — `Cache Bomba Física`
- **ID:** `fn_cache_bomba` | **Saídas:** `1`
- **Função:** Armazena o feedback físico `_IO_EM_DO_01` da bomba hidráulica em `flow.bomba_fisica`.

```javascript
let b = msg.payload === true || msg.payload === 1 || msg.payload === 'true';
flow.set('bomba_fisica', b);
return { payload: b };
```

---

#### 6. Nó `fn_cache_valvula` — `Cache Válvula`
- **ID:** `fn_cache_valvula` | **Saídas:** `1` (`[0] InfluxDB vp-01`)
- **Função:** Normaliza o feedback físico `_IO_EM_DO_00` da válvula para booleano, atualiza `flow.valvula` e envia à measurement `vp-01`.

```javascript
let val = !!msg.payload;
flow.set('valvula', val);
return { payload: val };
```

---

#### 7. Nó `fn_cache_setpoint` — `Cache Setpoint (tela)`
- **ID:** `fn_cache_setpoint` | **Saídas:** `0`
- **Função:** Bloqueia edições durante ensaio ativo (`flow.ativo === true`), arredonda o setpoint digitado em `PRESSÃO DESEJADA:` para 2 casas decimais e memoriza `flow.sp_ui` e `flow.sp_ui_t`.

```javascript
// Valor digitado na tela (PRESSÃO DESEJADA). Bloqueia alterações no CLP durante ensaio ativo.
if (flow.get('ativo') === true) return null;
if (msg.payload === null || msg.payload === undefined || msg.payload === '') return null;
const sp = Math.round(Number(msg.payload) * 100) / 100;
if (isNaN(sp)) return null;
flow.set('sp_ui', sp);
flow.set('sp_ui_t', Date.now());
return { payload: sp };
```

---

#### 8. Nó `fn_cache_setpoint_plc` — `Cache Setpoint (CLP)`
- **ID:** `fn_cache_setpoint_plc` | **Saídas:** `2` (`[0] Pressão definida do teste:`, `[1] PRESSÃO DESEJADA:`)
- **Função:** Recebe a leitura/confirmação de `setpoint_node` do CLP, filtra ecos atrasados dentro de `1500 ms` após edição na tela, atualiza `flow.sp_plc` e sincroniza os indicadores visuais da IHM (sem tocar em `PRESSÃO DESEJADA:` durante ensaio ativo).

```javascript
// Último setpoint lido do CLP (setpoint_node). Sincroniza tela sem eco atrasado; não grava no Influx.
if (msg.payload === null || msg.payload === undefined || msg.payload === '') return null;
const bruto = Number(msg.payload);
if (isNaN(bruto)) return null;
const sp = Math.round(bruto * 100) / 100;

// Filtro anti-eco atrasado: descarta leitura antiga caso o operador tenha acabado de alterar na tela
if (Date.now() - (flow.get('sp_ui_t') || 0) < 1500 && Math.abs(sp - Number(flow.get('sp_ui'))) > 0.001) {
    return null;
}

flow.set('sp_plc', sp);
flow.set('sp_plc_t', Date.now());
return [
    { payload: sp },
    flow.get('ativo') === true ? null : { payload: sp }
];
```

---

#### 9. Nó `fn_set_tempo_restante` — `Definir Tempo Restante`
- **ID:** `fn_set_tempo_restante` | **Saídas:** `1` (`[0] Seletor Tempo Restante`)
- **Função:** Bloqueia alterações no backend caso `flow.ativo === true`; quando parado, valida e grava a duração escolhida (10 a 60 min em múltiplos de 5 min) em `duracao_selecionada`, `duracao_teste` e `tempo_restante`.

```javascript
if (flow.get('ativo') === true) return null;

const val = parseInt(msg.payload, 10);
if (isNaN(val) || val < 10 || val > 60) return null;

// Garante intervalo de 5 em 5 entre 10 e 60 minutos
const min = Math.max(10, Math.min(60, Math.round(val / 5) * 5));
const duracaoMs = min * 60 * 1000;

flow.set('duracao_selecionada', duracaoMs);
flow.set('duracao_teste', duracaoMs);
flow.set('tempo_restante', min);

const mm = String(min).padStart(2, '0');
const texto = `TEMPO RESTANTE: ${mm}:00`;

return {
    payload: texto,
    cronometro: `${mm}:00`,
    minutos: min,
    enabled: true
};
```

---

#### 10. Nó `49589c46b3396a0f` — `Inicia teste`
- **ID:** `49589c46b3396a0f` | **Saídas:** `4` (`[0] fn_ui_lock`, `[1] ciclo_node`, `[2] InfluxDB setpoint`, `[3] Status do teste`)
- **Função:** Valida os 5 intertravamentos de partida (incluindo `CLP ONLINE` via `flow.plc_online === true`), trava `sp_travado`, `duracao_travada` e `equipamento_teste`, semeia a amostra inicial `{ v: pressao_atual, t: agora }` em `flow.historico` no instante exato `t = inicio` e inicia oficialmente o ensaio.

```javascript
// Botão INICIAR TESTE: valida comunicação com o CLP, intertravamentos, trava o setpoint e inicia o ciclo.
// Saídas: [0] bloqueia a UI ('RODANDO') | [1] ciclo_node = true (CLP) | [2] 1º ponto do setpoint travado (InfluxDB) | [3] texto de STATUS
if (flow.get('ativo') === true) return null;   // já existe um teste em andamento

const valido = (v) => v !== null && v !== undefined && v !== '' && !isNaN(Number(v));

const clpOnline      = flow.get('plc_online') === true;
const equipamento    = String(flow.get('equipamento') ?? '').trim();
const bombaFisica    = flow.get('bomba_fisica') === true || flow.get('bomba_fisica') === 1;
const motorComando   = flow.get('motor_on') === true;
const motorLigado    = motorComando || bombaFisica;

const valvulaFisica  = flow.get('valvula') === true || flow.get('valvula') === 1;
const valvulaComando = flow.get('valvula_manual_on') === true;
const valvulaAberta  = valvulaComando || valvulaFisica;

const pAtual = flow.get('pressao_atual');
const pNum = Number(pAtual ?? 0);

// Setpoint vigente = valor mais recente entre o campo da tela e o lido do CLP
const tUi = flow.get('sp_ui_t') || 0;
const tPlc = flow.get('sp_plc_t') || 0;
const primeiro = tUi >= tPlc ? flow.get('sp_ui') : flow.get('sp_plc');
const segundo  = tUi >= tPlc ? flow.get('sp_plc') : flow.get('sp_ui');
const spBruto = valido(primeiro) ? primeiro : segundo;

const motivos = [];
if (!clpOnline) motivos.push('CLP SEM COMUNICAÇÃO (192.168.1.33)');
if (!equipamento) motivos.push('PREENCHA O EQUIPAMENTO');
if (motorLigado) motivos.push('DESLIGUE O MOTOR / BOMBA');
if (valvulaAberta) motivos.push('FECHE A VÁLVULA');
if (!valido(spBruto) || Number(spBruto) <= 0) motivos.push('DEFINA A PRESSÃO DESEJADA (> 0 BAR)');
if (!Number.isFinite(pNum) || pNum <= 0) motivos.push('PRESSURIZE A PEÇA (> 0 BAR)');

if (motivos.length > 0) {
    const aviso = { payload: 'BLOQUEADO - ' + motivos.join(' / '), color: '#C62828' };
    flow.set('aviso_status', { payload: aviso.payload, color: aviso.color, ate: Date.now() + 8000 });
    return [null, null, null, aviso];
}

const sp = Math.round(Number(spBruto) * 100) / 100;
const agoraInicio = Date.now();

flow.set('ativo', true);
flow.set('aviso_status', null);
flow.set('inicio', new Date(agoraInicio).toLocaleString('pt-BR'));
flow.set('hora_inicio_date', agoraInicio);
flow.set('hora_fim_date', null);

// Semeia imediatamente a pressão atual no instante t=0 (garante laudo mesmo com pressão 100% estável sem variação de bits)
if (pAtual !== undefined && pAtual !== null && Number.isFinite(Number(pAtual))) {
    const p0 = Math.max(0, Number(pAtual));
    flow.set('soma', p0);
    flow.set('qtd', 1);
    flow.set('min', p0);
    flow.set('max', p0);
    flow.set('historico', [{ v: p0, t: agoraInicio }]);
    flow.set('ultima_coleta_t', agoraInicio);
} else {
    flow.set('soma', 0);
    flow.set('qtd', 0);
    flow.set('min', null);
    flow.set('max', null);
    flow.set('historico', []);
    flow.set('ultima_coleta_t', 0);
}

// Duração configurada pelo seletor (padrão 60 min se não selecionada)
let duracaoTeste = flow.get("duracao_selecionada") || flow.get("duracao_teste") || 3600000;
flow.set("duracao_teste", duracaoTeste);
flow.set("duracao_travada", duracaoTeste);
flow.set("tempo_restante", Math.ceil(duracaoTeste / 60000));

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

#### 11. Nó `fn_ui_lock` — `Habilitar / Bloquear UI`
- **ID:** `fn_ui_lock` | **Saídas:** `11` (`[0..5]` widgets da UI, `[6..9]` tags CIP manuais, `[10]` `Seletor Tempo Restante`)
- **Função:** Gerencia o bloqueio/desbloqueio completo da IHM (incluindo `Seletor Tempo Restante`), invalida timers pendentes (`motor_cmd_seq` / `valvula_cmd_seq`) e garante liberação manual das tags no boot, início e fim de ensaio.

```javascript
// Entrada: msg.payload = 'RODANDO' | 'PARADO' | 'BOOT'
let estado = msg.payload;
if (estado === 'BOOT') estado = flow.get('ativo') === true ? 'RODANDO' : 'PARADO';
const rodando = estado === 'RODANDO';

// Invalida timers pendentes de 400 ms em fn_ctrl_motor_manual / fn_ctrl_valvula_manual / fn_auto_cutoff_sp
flow.set('motor_cmd_seq', (flow.get('motor_cmd_seq') || 0) + 1);
flow.set('valvula_cmd_seq', (flow.get('valvula_cmd_seq') || 0) + 1);
flow.set('pulso_off_motor', false);
flow.set('corte_efetuado', false);

// Sempre garante que o estado do contexto reflita a liberação manual
flow.set('motor_on', false);
flow.set('on_node', false);
flow.set('off_node', false);
flow.set('valvula_manual_on', false);
flow.set('onval_node', false);
flow.set('offval_node', false);

const sp = flow.get('sp_travado');
const mostraSp = rodando && sp !== undefined && sp !== null;

const falseMsg = { payload: false };

const duracaoRef = (rodando ? flow.get('duracao_travada') : flow.get('duracao_selecionada')) || flow.get('duracao_teste') || 3600000;
const minutosSeletor = Math.round(Number(duracaoRef) / 60000);

return [
    { enabled: !rodando },
    { enabled: !rodando, payload: 3 },
    { enabled: !rodando, payload: 3 },
    mostraSp ? { enabled: !rodando, payload: Number(sp) } : { enabled: !rodando },
    { enabled: !rodando },
    { enabled: rodando },
    falseMsg,
    falseMsg,
    falseMsg,
    falseMsg,
    { enabled: !rodando, minutos: minutosSeletor },
    falseMsg
];
```

---

#### 12. Nó `7d655f418f1c0085` — `Coleta pressão`
- **ID:** `7d655f418f1c0085` | **Saídas:** `1` (`[0] gauge`)
- **Função:** Aceita `0.00 bar` (`!Number.isFinite(valor) || valor < 0`), atualiza `flow.pressao_atual`, calcula estatísticas em tempo real, poda a cabeça do buffer `flow.historico` em tempo amortizado $O(1)$ com janela dinâmica (`duracao_travada + 120000 ms` durante ensaio ativo) e alimenta o manômetro `gauge`.

```javascript
// Recebe leituras reais de RETORNO_BAR (eth-ip in) e amostras periódicas de keepalive durante o ensaio
if (msg.payload === null || msg.payload === undefined || msg.payload === '') return null;

let bruto = Number(msg.payload);
if (!Number.isFinite(bruto)) return null;

// Corrige pequeno desvio negativo de zero (4-20 mA) e permite leitura real de 0.00 bar (manômetro e ruptura)
let valor = bruto < 0 ? 0 : bruto;
let agora = Date.now();
let ativo = flow.get('ativo') === true;
let isKeepalive = msg._keepalive === true;

if (!isKeepalive) {
    flow.set('pressao_atual', valor);
    flow.set('pressao_atual_t', agora);
}

// Fora de ensaio: atualiza apenas o manômetro em tempo real sem acumular memória à toa
if (!ativo) {
    return isKeepalive ? null : { payload: valor };
}

// Se for amostra de keepalive (2 s) e uma leitura real do CLP acabou de ser gravada (< 950 ms), evita duplicidade
if (isKeepalive && (agora - (flow.get('ultima_coleta_t') || 0)) < 950) {
    return null;
}

flow.set('ultima_coleta_t', agora);

// Acumuladores do ensaio ativo
let soma = flow.get('soma') || 0;
let qtd = flow.get('qtd') || 0;
soma += valor;
qtd += 1;
flow.set('soma', soma);
flow.set('qtd', qtd);

let min = flow.get('min');
let max = flow.get('max');
if (min === null || min === undefined || valor < min) flow.set('min', valor);
if (max === null || max === undefined || valor > max) flow.set('max', valor);

let historico = flow.get('historico') || [];
historico.push({ v: valor, t: agora });

// Poda O(1) amortizada na cabeça da fila (preserva toda a janela do ensaio + 2 min de margem)
const janelaMs = (flow.get('duracao_travada') || flow.get('duracao_teste') || 3600000) + 120000;
let corte = 0;
while (corte < historico.length && (agora - historico[corte].t) > janelaMs) {
    corte++;
}
if (corte > 0) {
    historico.splice(0, corte);
}

flow.set('historico', historico);

return isKeepalive ? null : { payload: valor };
```

---

#### 13. Nó `5214bd83dc5b5467` — `Decremento de tempo`
- **ID:** `5214bd83dc5b5467` | **Saídas:** `3` (`[0] Seletor Tempo Restante`, `[1] Finaliza _Teste`, `[2] Status do teste`)
- **Função:** Executado a cada `1 s`; deduplica mensagens idênticas em repouso (eliminando tráfego WebSocket ocioso de 1 Hz), exibe alerta `CLP OFFLINE - VERIFIQUE CABO / ENERGIA (192.168.1.33)` quando desconectado, atualiza cronômetro `MM:SS` durante o ensaio e aciona `FINALIZAR_AUTO` ao zerar.

```javascript
// Roda a cada 1 s (inject). Saídas: 1 = tempo restante | 2 = finalização automática | 3 = status do teste
const fmt = (ms) => {
    const total = Math.max(0, Math.ceil(ms / 1000));      // segundos restantes (arredonda p/ cima)
    const mm = String(Math.floor(total / 60)).padStart(2, '0');
    const ss = String(total % 60).padStart(2, '0');
    return `${mm}:${ss}`;
};
const tempo = (ms, enabled, minSelect) => {
    const totalSec = Math.max(0, Math.ceil(ms / 1000));
    const crono = fmt(ms);
    return {
        payload: `TEMPO RESTANTE: ${crono}`,
        cronometro: crono,
        segundos: totalSec,
        minutos: minSelect,
        enabled: enabled
    };
};

const AGUARDANDO = { payload: "AGUARDANDO INÍCIO DO TESTE", color: "#B26A00" };  // âmbar

let ativo   = flow.get('ativo');
let inicio  = flow.get("hora_inicio_date");
let duracao = (ativo === true ? flow.get("duracao_travada") : null) || flow.get("duracao_selecionada") || flow.get("duracao_teste") || 3600000;
let minSelect = Math.round(duracao / 60000);

// NUNCA INICIOU / NÃO ESTÁ ATIVO -> contagem parada (com deduplicação 1 Hz para não piscar o dropdown)
if (!inicio || !ativo) {
    let status = AGUARDANDO;
    if (flow.get('plc_online') === false) {
        status = { payload: "AGUARDANDO CONEXÃO COM O CLP (192.168.1.33)", color: "#D84315" };
    }
    const aviso = flow.get('aviso_status');          // alerta de intertravamento / erro PDF
    if (aviso && aviso.ate > Date.now()) {
        status = { payload: aviso.payload, color: aviso.color };
    }

    const msgTempo = tempo(duracao, true, minSelect);
    const chaveTempo = `${msgTempo.cronometro}|${msgTempo.minutos}|${msgTempo.enabled}`;
    const chaveStatus = `${status.payload}|${status.color}`;

    const outTempo = (context.get('idle_tempo') !== chaveTempo) ? msgTempo : null;
    const outStatus = (context.get('idle_status') !== chaveStatus) ? status : null;

    context.set('idle_tempo', chaveTempo);
    context.set('idle_status', chaveStatus);

    if (!outTempo && !outStatus) return null;
    return [outTempo, null, outStatus];
}

// Em ensaio ativo: limpa cache de deduplicação ociosa para atualização imediata ao finalizar
context.set('idle_tempo', null);
context.set('idle_status', null);

let restante = (inicio + duracao) - Date.now();

// CHEGOU EM ZERO -> FINALIZA AUTOMÁTICO
if (restante <= 0 && ativo === true) {
    flow.set('tempo_restante', 0);
    flow.set('ativo', false);
    flow.set('hora_fim_date', Date.now());
    return [tempo(0, true, minSelect), { payload: "FINALIZAR_AUTO" }, AGUARDANDO];
}

// CONTAGEM NORMAL
flow.set('tempo_restante', Math.ceil(restante / 60000));   // mantido em minutos (compatibilidade)

const sp = flow.get('sp_travado');
let rodando = {
    payload: `TESTE RODANDO - SETPOINT ${sp !== undefined && sp !== null ? Number(sp).toFixed(2) : '--'} BAR`,
    color: "#2E7D32"
};
if (flow.get('plc_online') === false) {
    rodando = { payload: "ALERTA: CLP SEM COMUNICAÇÃO - TESTE EM ANDAMENTO", color: "#C62828" };
}
return [tempo(restante, false, minSelect), null, rodando];
```

---

#### 14. Nó `6d54da2809aedd4d` — `Finaliza _Teste`
- **ID:** `6d54da2809aedd4d` | **Saídas:** `5` (`[0]` livre, `[1] Relatório  HTML`, `[2] fn_ui_lock`, `[3] ciclo_node`, `[4] InfluxDB setpoint`)
- **Função:** Extrai `min`, `max` e média ponderada no tempo (integração por retenção de ordem zero / ZOH) estritamente sobre `historicoFiltrado` (`[inicio, fim]`), aplica tolerância simétrica `Setpoint ± 0,5 bar` (`Math.abs(erro) <= tolerancia`, reprovando subpressão e sobrepressão severa), limpa `sp_travado = null`, posiciona `falhaAnchor` sem corte nas bordas e gera HTML temporário exclusivo `/tmp/laudo_<basePdf>.html` + PDF único em `/data/relatorios/<basePdf>.pdf`.

```javascript
// Entradas: botão FINALIZAR TESTE (payload 0) ou cronômetro (payload "FINALIZAR_AUTO").
// Saídas: [0] livre | [1] relatório (HTML -> PDF) | [2] libera a UI ('PARADO') | [3] ciclo_node = false (CLP) | [4] ponto final do setpoint travado (InfluxDB)
const auto = msg.payload === 'FINALIZAR_AUTO';
if (!auto && flow.get('ativo') !== true) return null;   // nenhum teste em andamento

const spTravado = flow.get('sp_travado');
// SEMPRE libera a tela, limpa sp_travado e zera ciclo_node, mesmo que o relatório não possa ser gerado
const liberar = (rel) => {
    flow.set('ativo', false);
    flow.set('sp_travado', null);
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

let sp = Number(spTravado ?? flow.get('sp') ?? 0) || 0;
let historico = flow.get('historico') || [];

let inicio = Number(flow.get("hora_inicio_date"));
let fim = Number(flow.get("hora_fim_date") || Date.now());

if (!inicio) {
    node.error("hora_inicio_date não encontrada");
    return liberar(null);
}

if (historico.length === 0) {
    const pAtual = flow.get('pressao_atual');
    if (pAtual !== undefined && pAtual !== null && Number.isFinite(Number(pAtual))) {
        historico = [{ v: Math.max(0, Number(pAtual)), t: inicio }];
    }
}

// Histórico estrito do intervalo [inicio, fim]
let historicoFiltrado = historico.filter(p => p.t >= inicio && p.t <= fim);
if (historicoFiltrado.length === 0 && historico.length > 0) {
    historicoFiltrado = [historico[historico.length - 1]];
}
if (historicoFiltrado.length === 0) {
    node.error("Dados insuficientes");
    return liberar(null);
}

// Estatísticas calculadas diretamente sobre os pontos do ensaio + Média Ponderada no Tempo (integral de retenção de ordem zero)
let min = Number(historicoFiltrado[0].v);
let max = Number(historicoFiltrado[0].v);
let somaSimples = 0;
for (let i = 0; i < historicoFiltrado.length; i++) {
    const v = Number(historicoFiltrado[i].v);
    if (v < min) min = v;
    if (v > max) max = v;
    somaSimples += v;
}

let media = somaSimples / historicoFiltrado.length;
if (fim > inicio && historicoFiltrado.length > 0) {
    let area = 0;
    let pesoTotal = 0;
    if (historicoFiltrado[0].t > inicio) {
        const dt0 = Math.min(fim, historicoFiltrado[0].t) - inicio;
        if (dt0 > 0) {
            area += Number(historicoFiltrado[0].v) * dt0;
            pesoTotal += dt0;
        }
    }
    for (let i = 0; i < historicoFiltrado.length; i++) {
        const tAtual = Math.max(inicio, historicoFiltrado[i].t);
        const tProx = (i + 1 < historicoFiltrado.length) ? Math.min(fim, historicoFiltrado[i + 1].t) : fim;
        const dt = Math.max(0, tProx - tAtual);
        area += Number(historicoFiltrado[i].v) * dt;
        pesoTotal += dt;
    }
    if (pesoTotal > 0) {
        media = area / pesoTotal;
    }
}

let fimDate = new Date(fim);

// Base de tempo dinâmica
let duracao = Number(flow.get('duracao_travada') || flow.get('duracao_teste') || flow.get('duracao_selecionada') || 3600000);
let duracaoMin = Math.max(10, Math.round(duracao / 60000));

// Erro simétrico (Setpoint ± 0,5 bar): reprova tanto queda severa quanto sobrepressão severa (sem erro negativo)
let tolerancia = 0.5;
let erro = Math.max(Math.abs(sp - min), Math.abs(max - sp));
let erroArred = Math.round(erro * 10000) / 10000;
let status = erroArred <= tolerancia ? "APROVADO" : "REPROVADO";

// Escala vertical: 0 a 10 bar -> 360 px (36 px/bar, y=390 até y=30)
let escala = 36;
let pontosArr = [];

if (historicoFiltrado[0].t > inicio) {
    let y0 = Number((390 - (Number(historicoFiltrado[0].v) * escala)).toFixed(2));
    pontosArr.push(`60,${y0}`);
}

for (let i = 0; i < historicoFiltrado.length; i++) {
    let p = historicoFiltrado[i];
    let proporcao = duracao > 0 ? (p.t - inicio) / duracao : 0;
    if (proporcao < 0) proporcao = 0;
    if (proporcao > 1) proporcao = 1;

    let x = Number((60 + (proporcao * 1080)).toFixed(2));
    let y = Number((390 - (Number(p.v) * escala)).toFixed(2));
    pontosArr.push(`${x},${y}`);
}
let pontos = pontosArr.join(' ');

// Linha de Setpoint limitada à área útil do gráfico
let linhaSP = Number((390 - (Math.min(10, Math.max(0, sp)) * escala)).toFixed(2));

// Primeiro ponto fora da faixa Setpoint ± 0,5 bar
let falhaX = null;
let falhaY = null;
let falhaValor = null;
let falhaAnchor = "middle";

for (let i = 0; i < historicoFiltrado.length; i++) {
    let p = historicoFiltrado[i];
    let desvioPonto = Math.round(Math.abs(Number(p.v) - sp) * 10000) / 10000;

    if (desvioPonto > tolerancia) {
        let proporcao = duracao > 0 ? (p.t - inicio) / duracao : 0;
        if (proporcao < 0) proporcao = 0;
        if (proporcao > 1) proporcao = 1;

        let vPlot = Math.min(10, Math.max(0, Number(p.v)));
        falhaX = Number((60 + (proporcao * 1080)).toFixed(2));
        falhaY = Number((390 - (vPlot * escala)).toFixed(2));
        falhaValor = Number(p.v).toFixed(2);
        if (falhaX < 150) falhaAnchor = "start";
        else if (falhaX > 1050) falhaAnchor = "end";
        break;
    }
}

// Grade vertical e rótulos dinâmicos do eixo X
let passoMin = 5;
if (duracaoMin <= 15) {
    passoMin = 1;
} else if (duracaoMin === 20) {
    passoMin = 2;
}

function horaOffset(minutos) {
    return new Date(inicio + (minutos * 60000))
        .toLocaleTimeString('pt-BR', {
            timeZone: BR,
            hour: '2-digit',
            minute: '2-digit'
        });
}

let eixoX = [];
for (let m = 0; m <= duracaoMin; m += passoMin) {
    let x = Number((60 + ((m / duracaoMin) * 1080)).toFixed(2));
    let classe = (m === 0) ? "axis-base" : "grid-main";
    let rotulo = horaOffset(m);
    eixoX.push({ x: x, classe: classe, rotulo: rotulo });
}

// Faixa visual da zona de tolerância simétrica ([sp - 0.5, sp + 0.5] limitada a [0, 10])
let limSupTol = Math.min(10, Math.max(0, sp + tolerancia));
let limInfTol = Math.min(10, Math.max(0, sp - tolerancia));
let faixaTolY = Number((390 - (limSupTol * escala)).toFixed(2));
let faixaTolAltura = Number((Math.max(0, limSupTol - limInfTol) * escala).toFixed(2));

let falhaYTxt = null;
if (falhaY !== null) {
    falhaYTxt = falhaY > 365 ? (falhaY - 10) : (falhaY < 50 ? (falhaY + 18) : (falhaY + 16));
}

let rel = {
    equipamento: flow.get('equipamento_teste') ?? flow.get('equipamento'),

    inicio: dataHoraBR(inicio),
    fim: dataHoraBR(fimDate),
    duracaoMin: duracaoMin,

    media: media.toFixed(2),
    min: Number(min).toFixed(2),
    max: Number(max).toFixed(2),

    sp: sp,
    spFmt: Number(sp).toFixed(2),
    toleranciaFmt: tolerancia.toFixed(2),
    statusCor: status === "APROVADO" ? "#15803d" : "#b91c1c",
    statusBg: status === "APROVADO" ? "#dcfce7" : "#fee2e2",
    statusBorda: status === "APROVADO" ? "#16a34a" : "#dc2626",
    faixaTolY: faixaTolY,
    faixaTolAltura: faixaTolAltura,

    erro: erro.toFixed(2),
    status: status,

    pontos: pontos,
    linhaSP: linhaSP,

    falhaX: falhaX,
    falhaY: falhaY,
    falhaValor: falhaValor,
    falhaYTxt: falhaYTxt,
    falhaAnchor: falhaAnchor,

    eixoX: eixoX
};

// RESET mantendo a duração configurada (ou 60 min padrão)
let duracaoCfg = flow.get('duracao_selecionada') || 3600000;
flow.set('tempo_restante', Math.ceil(duracaoCfg / 60000));
flow.set('duracao_teste', duracaoCfg);
flow.set('duracao_travada', null);

let agora = new Date();
let o = partesBR(agora);
rel.emissao = `${o.day}/${o.month}/${o.year} - ${o.hour}:${o.minute}:${o.second}`;

// NOME ÚNICO DO PDF: <Equipamento>_<DD-MM-AAAA_HH-mm-ss>.pdf (com anti-colisão no mesmo segundo)
let equip = String(flow.get('equipamento_teste') ?? flow.get('equipamento') ?? '')
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^A-Za-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 60) || 'Equipamento';
let carimbo = `${o.day}-${o.month}-${o.year}_${o.hour}-${o.minute}-${o.second}`;
let basePdf = `${equip}_${carimbo}`;
if (flow.get('ultimo_pdf_base') === basePdf) {
    let seq = (flow.get('ultimo_pdf_seq') || 1) + 1;
    flow.set('ultimo_pdf_seq', seq);
    basePdf = `${basePdf}_${seq}`;
} else {
    flow.set('ultimo_pdf_base', basePdf);
    flow.set('ultimo_pdf_seq', 1);
}

// HTML temporário isolado em /tmp por relatório (evita corrida entre execuções) e PDF único em /data/relatorios
msg.filename = "/tmp/laudo_" + basePdf + ".html";
msg.pdfFile  = "/data/relatorios/" + basePdf + ".pdf";

return liberar({ payload: rel, filename: msg.filename, pdfFile: msg.pdfFile });
```

---

#### 15. Nó `e32ec29ac871e4f2` — `Comando Chromium`
- **ID:** `e32ec29ac871e4f2` | **Saídas:** `1` (`[0] Gerar PDF (Chromium)`)
- **Função:** Monta a linha de comando headless do `chromium-browser` com `--disable-dev-shm-usage` (evitando crash em `/dev/shm` de 64 MB no Docker) apontando para `msg.filename` (`/tmp/laudo_<basePdf>.html`) e `msg.pdfFile`.

```javascript
// Argumentos do Chromium headless (o executável está no nó "Gerar PDF (Chromium)").
// --disable-dev-shm-usage evita falha de memória compartilhada (/dev/shm de 64 MB no Docker).
// --no-pdf-header-footer remove a data em inglês e o título impressos pelo navegador.
const pdf  = msg.pdfFile;
const html = msg.filename || "/tmp/relatorio.html";
msg.payload = `--headless --no-sandbox --disable-gpu --disable-dev-shm-usage --no-pdf-header-footer --print-to-pdf="${pdf}" "${html}"`;
return msg;
```

---

#### 16. Nó `fn_heartbeat` — `Keepalive InfluxDB`
- **ID:** `fn_heartbeat` | **Saídas:** `4` (`[0] InfluxDB setpoint`, `[1] InfluxDB vp-01`, `[2] InfluxDB PT-010`, `[3] Coleta pressão`)
- **Função:** Executado a cada `2 s`; suprime telemetria falsa quando `plc_online !== true`, publica `sp_travado` e re-amostra `pressao_atual` (keepalive de `PT-010` e `Coleta pressão` quando `RETORNO_BAR` permanece perfeitamente estável por `>= 1800 ms`) durante ensaio ativo, além do keepalive booleano de `vp-01`.

```javascript
// Roda a cada 2 s.
// Saída 1: setpoint TRAVADO -> InfluxDB (somente durante ensaio ativo).
// Saída 2: estado da válvula -> InfluxDB (keepalive para painel do Grafana).
// Saída 3: pressão atual -> InfluxDB PT-010 (evita 'No data' no Grafana quando a pressão está 100% estável e CLP online).
// Saída 4: amostra periódica -> Coleta pressão (garante curva e média fiéis mesmo sem variação de bits durante o ensaio).
const ativo = flow.get('ativo') === true;
const online = flow.get('plc_online') === true;

let outSetpoint = null;
if (ativo) {
    const sp = flow.get('sp_travado');
    if (sp !== undefined && sp !== null && !isNaN(Number(sp))) {
        outSetpoint = { payload: Number(sp) };
    }
}

const val = flow.get('valvula');
const outValvula = online ? { payload: (val === true || val === 1 || val === 'true') } : null;

let outPressaoInflux = null;
let outPressaoColeta = null;
const p = flow.get('pressao_atual');
if (p !== undefined && p !== null && Number.isFinite(Number(p))) {
    const pVal = Math.max(0, Number(p));
    if (online) {
        outPressaoInflux = { payload: pVal };
    }
    if (ativo && flow.get('plc_online') !== false) {
        outPressaoColeta = { payload: pVal, _keepalive: true };
    }
}

return [outSetpoint, outValvula, outPressaoInflux, outPressaoColeta];
```

---

#### 17. Nó `fn_status_clp` — `Monitorar Conexão CLP`
- **ID:** `fn_status_clp` | **Saídas:** `1` (`[0] ciclo_node`)
- **Função:** Monitora o nó `status` (`status_clp_endpoint` vinculado a `PRESSAO`), atualiza `flow.plc_online` (`fill === "green"`), força `ciclo_node = false` no boot (`msg.topic === "boot"`) e re-sincroniza `ciclo_node = (flow.ativo === true)` automaticamente ao reconectar o cabo Ethernet do CLP.

```javascript
// Monitora o status em tempo real do link EtherNet/IP CIP através do nó PRESSAO (fba7dcc329b4be25).
// fill === 'green' indica sessão CIP online; 'red'/'yellow'/'grey' indica offline ou reconectando.
const fill = (msg && msg.status && msg.status.fill) ? String(msg.status.fill) : '';
const online = (fill === 'green');
const estavaOnline = flow.get('plc_online') === true;

flow.set('plc_online', online);
flow.set('plc_status_texto', (msg && msg.status && msg.status.text) ? String(msg.status.text) : '');

// Ao reconectar após queda de cabo/energia (onControllerEnd zera tag.value = null):
// Reenvia imediatamente o estado real de ciclo_node (true se ensaio ativo, false se parado).
if (online && !estavaOnline) {
    return { payload: flow.get('ativo') === true };
}

return null;
```

---

#### 18. Nó `fn_verifica_pdf` — `Verificar Geração PDF`
- **ID:** `fn_verifica_pdf` | **Saídas:** `1` (`[0] Status do teste`)
- **Função:** Inspeciona o código de retorno (`rc.code`) do processo `chromium-browser` (com timeout de `30 s`), remove o arquivo HTML temporário `/tmp/laudo_*.html` sem acumular lixo e publica alerta vermelho de 12 s na tarja `STATUS` caso a geração do PDF falhe.

```javascript
// Monitora a saída do nó exec "Gerar PDF (Chromium)"
const rc = msg.payload; // { code: number, signal?: string }
const html = msg.filename;

// Limpeza garantida do arquivo HTML temporário em /tmp
if (html && typeof html === 'string' && html.startsWith('/tmp/laudo_')) {
    try {
        if (typeof fs !== 'undefined' && typeof fs.unlink === 'function') {
            fs.unlink(html, () => {});
        } else {
            require('fs').unlink(html, () => {});
        }
    } catch (e) {}
}

if (!rc || rc.code !== 0) {
    node.error("Falha ao gerar PDF via Chromium: " + JSON.stringify(rc));
    return {
        payload: "FALHA AO GERAR PDF DO RELATÓRIO",
        color: "#C62828"
    };
}
return null;
```

---

## 5. GUIA RÁPIDO DE MANUTENÇÃO PARA O TÉCNICO

### 5.1 Dicionário de Variáveis de Contexto (`flow.*`)

No Node-RED, você pode inspecionar todas as variáveis abrindo o menu lateral direito **Context Data -> Flow**:

| Variável | Tipo | Descrição | Valor Típico |
|---|---|---|---|
| `flow.ativo` | `Boolean` | Flag mestre indicando se há um teste em execução | `true` ou `false` |
| `flow.plc_online` | `Boolean` | Estado em tempo real da sessão EtherNet/IP CIP com o Micro850 | `true` (verde) ou `false` |
| `flow.equipamento` | `String` | Nome/código do equipamento digitado na IHM | Ex: `"Bomba_01"` |
| `flow.equipamento_teste` | `String` | Nome do equipamento congelado no início do ensaio | Ex: `"Bomba_01"` |
| `flow.pressao_atual` | `Number` | Última pressão válida (`>= 0 bar`) recebida de `RETORNO_BAR` | Ex: `5.50` ou `0.00` |
| `flow.pressao_atual_t` | `Number (ms)` | Timestamp epoch da última atualização em `Coleta pressão` | Ex: `1793396502000` |
| `flow.sp_ui` | `Number` | Último setpoint ajustado na caixa `PRESSÃO DESEJADA:` (2 casas) | Ex: `5.5` |
| `flow.sp_ui_t` | `Number (ms)` | Timestamp epoch da última alteração manual de setpoint na tela | Ex: `1793396500000` |
| `flow.sp_plc` | `Number` | Último setpoint confirmado/lido da tag `setpoint_node` do CLP | Ex: `5.5` |
| `flow.sp_plc_t` | `Number (ms)` | Timestamp epoch da última confirmação de setpoint vinda do CLP | Ex: `1793396500250` |
| `flow.sp_travado` | `Number / null` | Pressão travada na partida do ensaio (`null` fora de ensaio) | Ex: `5.5` ou `null` |
| `flow.hora_inicio_date` | `Number (ms)` | Timestamp epoch exato do instante em que o teste iniciou | Ex: `1793396501000` |
| `flow.hora_fim_date` | `Number (ms)` | Timestamp epoch exato do término automático (ou `null` durante ensaio) | Ex: `1793400101000` |
| `flow.duracao_selecionada` | `Number (ms)` | Duração escolhida pelo operador no seletor (10 a 60 min) | `600000` a `3600000` |
| `flow.duracao_teste` | `Number (ms)` | Duração configurada corrente em milissegundos | `3600000` (padrão 60 min) |
| `flow.duracao_travada` | `Number (ms)` | Duração travada na partida (imutável até o fim do ensaio) | `600000` a `3600000` |
| `flow.tempo_restante` | `Number` | Minutos inteiros restantes para o término do ensaio | `60` a `0` |
| `flow.min` | `Number` | Menor pressão (`>= 0.00 bar`) registrada no contexto corrente | Ex: `5.32` ou `0.00` |
| `flow.max` | `Number` | Maior pressão registrada no contexto corrente | Ex: `5.54` |
| `flow.historico` | `Array` | Buffer `{v, t}` podado em $O(1)$ (`duracao_travada + 2 min`) | `[{v:5.5, t:...}]` |
| `flow.motor_on` | `Boolean` | Estado lógico do comando manual do motor | `true` ou `false` |
| `flow.motor_cmd_seq` | `Number` | Sequencial monotônico para cancelamento de timers de `400 ms` do motor | Ex: `14` |
| `flow.on_node` / `flow.off_node` | `Boolean` | Espelho em contexto dos comandos CIP enviados ao motor | `true` ou `false` |
| `flow.bomba_fisica` | `Boolean` | Feedback digital físico da bomba no CLP (`_IO_EM_DO_01`) | `true` ou `false` |
| `flow.valvula_manual_on` | `Boolean` | Estado lógico do comando manual da válvula | `true` ou `false` |
| `flow.valvula_cmd_seq` | `Number` | Sequencial monotônico para cancelamento de timers de `400 ms` da válvula | Ex: `8` |
| `flow.onval_node` / `flow.offval_node` | `Boolean` | Espelho em contexto dos comandos CIP enviados à válvula | `true` ou `false` |
| `flow.valvula` | `Boolean` | Feedback digital físico da válvula no CLP (`_IO_EM_DO_00`) | `true` ou `false` |
| `flow.ultimo_pdf_base` / `ultimo_pdf_seq` | `String / Number` | Controle anti-colisão de nomes de PDF emitidos no mesmo segundo | `"Bomba_..."` / `2` |
| `flow.aviso_status` | `Object` | Mensagem temporária na tarja de status (intertravamento ou falha PDF) | `{payload, color, ate}` |

---

### 5.2 Como Intervir ou Destravar o Sistema em Tempo Real

Se por qualquer motivo operacional a interface precisar ser reinicializada:
1. Abra o Editor do Node-RED em `http://localhost:1880`.
2. Na aba lateral **Context Data -> Flow**, altere `ativo` para `false` (ou recrie/reinicie o contêiner `nodered`).
3. Alternativamente, acione um inject manual com `"PARADO"` na entrada do nó `Habilitar / Bloquear UI` (`fn_ui_lock`): todas as 11 saídas liberarão os controles da IHM imediatamente.

---

### 5.3 Como Alterar a Tolerância Simétrica de Aprovação (Padrão `± 0.5 bar`)

1. Abra o nó `Finaliza _Teste` (`6d54da2809aedd4d`).
2. Localize `let tolerancia = 0.5;` e ajuste para o valor desejado (ex.: `0.3` ou `1.0`).
3. O critério bilateral `Math.abs(erro) <= tolerancia` e a faixa verde visual (`[Setpoint - tolerancia, Setpoint + tolerancia]`) no gráfico SVG ajustar-se-ão automaticamente tanto para subpressão quanto para sobrepressão.

---

### 5.4 Seleção Dinâmica de Duração do Ensaio (`10 a 60 Minutos`)

A duração do ensaio é selecionável diretamente na IHM pelo widget **Seletor Tempo Restante** (`10` a `60 min`, passo de `5 min`), ficando bloqueada em 3 camadas (frontend `ng-disabled`, UI lock `11ª saída` e backend `fn_set_tempo_restante`) enquanto `flow.ativo === true`. Caso deseje alterar o valor padrão de boot (`60 min` = `3600000 ms`), ajuste o fallback `3600000` nos nós `Inicia teste`, `Decremento de tempo`, `Finaliza _Teste` e `fn_ui_lock`.

---

### 5.5 Como Alterar a Faixa ou Passo de Pressão (Setpoint) na IHM

1. No nó `PRESSÃO DESEJADA:` (`id: "c27f650072a158be"`, tipo `ui_numeric`), ajuste **Min** (`0`), **Max** (`10`) e **Step** (atualmente `0.5` bar).
2. O arredondamento `Math.round(Number(msg.payload) * 100) / 100` nos nós `fn_cache_setpoint` e `fn_cache_setpoint_plc` e `Math.fround` no shim CIP já suportam passos decimais finos (ex.: `0.1` ou `0.25` bar) sem erro de ponto flutuante.

---

## 6. MATRIZ DE DIAGNÓSTICO E RESOLUÇÃO DE PROBLEMAS (TROUBLESHOOTING)

| Sintoma | Causa Mais Provável | Procedimento de Correção |
|---|---|---|
| **Tarja vermelha `CLP OFFLINE - VERIFIQUE CABO / ENERGIA (192.168.1.33)`** | Cabo Ethernet desconectado, Micro850 desligado ou IP do PC fora da sub-rede `192.168.1.x`. | 1. Teste `ping 192.168.1.33`.<br>2. Confirme IP estático `192.168.1.100/24` sem gateway na placa cabeada.<br>3. Ao reconectar, `fn_status_clp` liberará `plc_online = true` e re-sincronizará `ciclo_node` automaticamente. |
| **Erro `TIMEOUT occurred while reading Controller Props`** | Shim CIP Micro800 ausente no `settings.js`. | Verifique nos logs `docker logs nodered` a linha `[micro800-shim] ethernet-ip patched: direct Message Router + TCP framing + inflight write guard + timer cleanup + REAL sync`. |
| **Painéis do Grafana exibindo `Datasource InfluxDB-Flux was not found`** | `uid: InfluxDB-Flux` ausente no provisionamento de datasources. | Confirme que `grafana_provisioning/datasources/influxdb.yaml` contém `deleteDatasources` + `uid: InfluxDB-Flux` e reinicie o contêiner `docker restart grafana`. |
| **Erro `Write to InfluxDB failed: ETIMEDOUT 192.168.65.254:8086` no Windows** | Presença indevida de `extra_hosts: ["host.docker.internal:host-gateway"]` no serviço `nodered` do `docker-compose.windows.yml`. | Mantenha `extra_hosts` **apenas** no `docker-compose.yml` (Linux). No Windows, o `influxdb` já possui o alias `host.docker.internal` na `iot-network`. |
| **Botão INICIAR TESTE bloqueado em vermelho** | Intertravamento de segurança atuou. | Leia a tarja `STATUS`: verifique se o CLP está online, preencha `Equipamento`, desligue o motor (`_IO_EM_DO_01 = false`), feche a válvula (`_IO_EM_DO_00 = false`) e defina a `PRESSÃO DESEJADA`. |
| **Tarja vermelha `FALHA AO GERAR PDF DO RELATÓRIO`** | Falha de permissão em `./relatorios` ou timeout de renderização do Chromium. | 1. Consulte `docker logs --tail 50 nodered` para ver o código de saída capturado por `fn_verifica_pdf`.<br>2. Verifique espaço em disco e permissão de escrita em `./relatorios`. |

---

## 7. DISPOSIÇÕES FINAIS E SUPORTE TÉCNICO

O projeto opera de maneira **100% autônoma e offline (air-gapped)** em chão de fábrica, compatível com Windows e Linux usando exatamente o mesmo `flows.json` e `settings.js`. Toda evolução técnica deve ser versionada no Git, documentada em `docs/DOSSIE_TECNICO_MANUTENCAO.md` e registrada sequencialmente em `historico_execucoes/` (com ponteiro atualizado em `docs/RESUMO_EXECUCAO.md`).

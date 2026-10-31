# RESUMO DE EXECUÇÃO #10: AUDITORIA PROFUNDA, HARDENING METROLÓGICO (±0,5 BAR & ZOH), BLINDAGEM CIP 7 CAMADAS, SUPERVISÃO CLP E OTIMIZAÇÃO DE DESEMPENHO

**Data:** 31 de Outubro de 2026  
**Ambiente:** Rockwell Micro850 (`192.168.1.33`, CIP EtherNet/IP) + Node-RED 5.0.8 (Dashboard 3.6.6) + InfluxDB 2.7.12 + Grafana 13.2.4 + Chromium Headless  
**Regra de Ouro:** Operação 100% Offline (Air-gapped) — Zero `npm install`, `docker pull`, rebuild online ou CDNs externos

---

## 1. ESCOPO CONSOLIDADO DA EXECUÇÃO 10

Esta execução materializa o plano completo de correções aprovado após auditoria profunda de código, metrologia, concorrência CIP e desempenho de runtime, dividido em 4 pacotes sequenciais (preservando estritamente intactos os itens excluídos de segurança local, Linux/mobile e batching do InfluxDB):

### 1.1 Pacote 1 — Higiene Estrutural, Documentação e UX (`BAIXO-01` a `BAIXO-05`)
1. **Remoção de Dependência Órfã (`BAIXO-01`):** Exclusão do pacote não utilizado `node-red-contrib-ui-led` de `nodered_data/package.json` e `nodered_data/package-lock.json`, com desativação (`"enabled": false`) em `nodered_data/.config.nodes.json`, acelerando a inicialização de paleta do Node-RED sem tocar em `node_modules/` offline.
2. **Alinhamento Documental de Tags CIP e Imagem Docker (`BAIXO-02`):** Atualização das tabelas das 10 tags CIP (`BOOL` / `REAL`) e referência à imagem oficial `clp_iot-nodered:latest` em `README.md` e `docs/RESUMO_PROJETO_SCADA.md`.
3. **Centralização da Documentação em `docs/` (`BAIXO-03`):** Remoção das duplicatas na raiz (`DOSSIE_TECNICO_MANUTENCAO.md` e `RESUMO_EXECUCAO.md`), consolidando `docs/` como fonte única de verdade com 100% dos links relativos validados.
4. **Datas sem Escape HTML e Anti-Colisão de PDF (`BAIXO-04`):** Uso de chaves triplas Mustache (`{{{payload.inicio}}}`, `{{{payload.fim}}}`, `{{{payload.emissao}}}`) em `Relatório  HTML` e sufixo incremental automático (`_2`, `_3`) em `Finaliza _Teste` caso dois laudos sejam emitidos no mesmo segundo.
5. ** Fluidez de Digitação na IHM (`BAIXO-05`):** Redução do `delay` do campo `Equipamento` (`input_eq`) de `300 ms` para `100 ms` (`> 0` para preservar o modo `'text-input'` do `node-red-dashboard` com `sendOnBlur: true`).

### 1.2 Pacote 2 — Correções Críticas de Metrologia, Intertravamento e Grafana (`CRÍTICO-01` a `CRÍTICO-05` + `ALTO-04`)
1. **Leitura de `0,00 bar` e Detecção de Rompimento Catastrófico (`CRÍTICO-01`):** Substituição do filtro `if (!valor || valor <= 0) return null;` em `Coleta pressão` por `if (msg.payload === null || msg.payload === undefined || msg.payload === '' || !Number.isFinite(valor) || valor < 0) return null;`. O manômetro da IHM agora zera fielmente (`0,00 bar`) ao aliviar a linha, e qualquer queda a `0,00 bar` durante um ensaio ativo é registrada em `historico` e reprova o teste (`min = 0.00 bar`).
2. **Isolamento de `sp_travado` Entre Ensaios (`CRÍTICO-02`):** `Finaliza _Teste` limpa explicitamente `flow.set('sp_travado', null)` na função `liberar()`, e `fn_auto_cutoff_sp` só consulta `sp_travado` quando `flow.get('ativo') === true`, impedindo que o setpoint de um ensaio encerrado corte a pressurização manual subsequente em um setpoint maior.
3. **UID Determinístico do Datasource no Grafana (`CRÍTICO-03`):** Inclusão de `uid: InfluxDB-Flux` acompanhado de `deleteDatasources` em `grafana_provisioning/datasources/influxdb.yaml`, garantindo que todos os 7 painéis de `pressao_hidrostatica.json` resolvam o datasource tanto em novas máquinas quanto na migração automática de bancos `grafana.db` pré-existentes sem erro de provisionamento.
4. **Tolerância Simétrica Bilateral `Setpoint ± 0,5 bar` (`CRÍTICO-04`):** Atualização do critério de aprovação em `Finaliza _Teste` para `Math.abs(erro) <= tolerancia` (`tolerancia = 0.5`), calculando o maior desvio bilateral dentro de `[Setpoint - 0,5 bar, Setpoint + 0,5 bar]`, reprovando tanto perda de estanqueidade (`pressão < SP - 0,5`) quanto sobrepressão severa (`pressão > SP + 0,5`, erro negativo fora da faixa) e expandindo a faixa verde SVG (`2 * tolerancia`).
5. **Supervisão Online/Offline do CLP e Resiliência de `ciclo_node` (`CRÍTICO-05`):** Adição dos nós `status_clp_endpoint` (vigiando o estado CIP de `PRESSAO`) e `fn_status_clp`, bloqueando `Inicia teste` quando `flow.plc_online !== true`, forçando `ciclo_node = false` no boot do Node-RED, exibindo alerta vermelho claro na tarja `STATUS` quando o cabo/CLP está desconectado e re-enviando `ciclo_node` automaticamente na reconexão Ethernet.
6. **Média Ponderada no Tempo (ZOH) e Amostragem Estacionária (`ALTO-04` — Reclassificado como Crítico):**
   - `Inicia teste` semeia imediatamente `{ v: pressao_atual, t: agora }` em `flow.historico` no instante `t = inicio`;
   - `fn_heartbeat` (4 saídas) injeta keepalive periódico a cada `2 s` em `PT-010` e `Coleta pressão` sempre que o CLP está online em ensaio ativo e `RETORNO_BAR` permanece perfeitamente constante por `>= 1800 ms` (compensando a natureza por-mudança do evento `Changed` do driver `ethernet-ip`);
   - `Finaliza _Teste` calcula `min`, `max` e `media` exclusivamente sobre `historicoFiltrado` (`[inicio, fim]`) usando integração temporal exata por retenção de ordem zero (Zero-Order Hold / ZOH), eliminando qualquer contaminação pré-teste e qualquer viés causado por rajadas de ruído analógico.

### 1.3 Pacote 3 — Blindagem do Protocolo CIP, Concorrência de Comandos e Robustez do PDF (`ALTO-01` a `ALTO-03`, `ALTO-05`)
1. **Proteção de Escritas CIP In-Flight (`ALTO-01`):** Evolução do `[micro800-shim]` em `nodered_data/settings.js` com contadores monotônicos `_write_seq` e `_inflight_seq` no setter `Tag.prototype.value`, `generateWriteMessageRequests` e `unstageWriteRequest`, impedindo que a borda de descida (`false`) de um pulso de `400 ms` seja descartada caso a escrita `true` sofra atraso TCP.
2. **Eliminação da Tempestade CIP e Condições de Corrida de UI (`ALTO-02`):**
   - `fn_auto_cutoff_sp` verifica se o motor está efetivamente ligado (`motor_on || on_node || bomba_fisica`) antes de disparar o corte, eliminando **21.600 escritas CIP/hora** redundantes quando o motor já está desligado;
   - Preservação do estado `2` (`MOTOR DESLIGADO`) e do bloqueio `enabled: false` no dropdown `MOTOR` durante ensaios (com `replayMessages` do Dashboard);
   - Cancelamento de timers de `400 ms` obsoletos via `motor_cmd_seq` e `valvula_cmd_seq` em `fn_ctrl_motor_manual`, `fn_ctrl_valvula_manual`, `fn_auto_cutoff_sp` e `fn_ui_lock`;
   - Guardas de backend `if (flow.get('ativo') === true) return null;` em `fn_set_eq`, `fn_ctrl_motor_manual`, `fn_ctrl_valvula_manual` e `fn_cache_setpoint`.
3. **Reassemblagem de Stream TCP EtherNet/IP (`ALTO-03`):** Substituição de `ENIPProto._handleDataEvent` em `nodered_data/settings.js` por um acumulador de stream TCP (`this._rxBuf`) que lê o campo `Length` do cabeçalho ENIP de 24 bytes (`offset 2`, UInt16LE), aguardando pacotes fragmentados e fatiando múltiplos pacotes ENIP coalescidos no mesmo segmento TCP.
4. **Blindagem do Chromium Headless e Verificação Pós-PDF (`ALTO-05`):** Adição de `--disable-dev-shm-usage` em `Comando Chromium` (prevenindo crash em `/dev/shm` de 64 MB do Docker), timeout de `30 s` no nó `exec` (`38510ae3de26350c`), isolamento de HTML temporário por relatório (`/tmp/laudo_<basePdf>.html`) e criação do nó `fn_verifica_pdf` para remoção automática do HTML temporário e alerta vermelho na IHM em caso de erro de renderização.

### 1.4 Pacote 4 — Desempenho de Runtime, SVG e Pinagem Offline (`MÉDIO-01`, `03`, `04`, `06`, `07`)
1. **Poda Amortizada $O(1)$ do Histórico (`MÉDIO-01`):** Substituição de `Array.prototype.filter` a cada amostra em `Coleta pressão` por avanço de índice na cabeça ordenada temporalmente (`historico.slice(corte)` apenas quando há amostras expiradas).
2. **Limpeza de Timers em `promiseTimeout` (`MÉDIO-03`):** Patch em `ethernet-ip/src/utilities.promiseTimeout` aplicando `clearTimeout(timer)` no `.finally()` antes da carga de `Controller`.
3. **Aperfeiçoamentos Visuais do Gráfico SVG (`MÉDIO-04`):** Adição de `<clipPath id="plot-clip">` delimitando curvas acima de `10 bar` à área útil `(60,30)..(1140,390)` e `text-anchor` dinâmico (`start` / `middle` / `end`) no rótulo de falha próximo às bordas.
4. **Deduplicação WebSocket em Repouso e Comparação Numérica (`MÉDIO-06`):** `Decremento de tempo` armazena assinaturas em `context` quando ocioso (`!ativo`), emitindo para o Dashboard apenas quando o texto/estado muda, e o template Angular `Seletor Tempo Restante` utiliza comparações estritamente numéricas (`(+selectedMin) <= 10` e `(+selectedMin) >= 60`).
5. **Pinagem Determinística de Versões Docker Offline (`MÉDIO-07`):** Fixação das imagens locais homologadas (`FROM nodered/node-red:5.0.8` em `Dockerfile.nodered`, `influxdb:2.7.12` e `grafana/grafana:13.2.4` em `docker-compose.windows.yml` e `scripts/windows/exportar-imagens-offline.bat`) via `docker tag` 100% offline.

---

## 2. ARQUIVOS ALTERADOS E REMOVIDOS

| Arquivo | Natureza da Alteração |
| :--- | :--- |
| `DOSSIE_TECNICO_MANUTENCAO.md` e `RESUMO_EXECUCAO.md` (raiz) | Removidos (duplicatas eliminadas em favor da centralização exclusiva em `docs/`). |
| `nodered_data/package.json`, `package-lock.json`, `.config.nodes.json` | Remoção/desativação da dependência órfã `node-red-contrib-ui-led`. |
| `nodered_data/settings.js` | Evolução do `[micro800-shim]` de 4 para **7 camadas** (`promiseTimeout` cleanup, Message Router direto, TCP stream framing `_rxBuf`, `_write_seq`/`_inflight_seq`, `write_ready`, supressão pré-escrita e confirmação Float32 seletiva). |
| `nodered_data/flows.json` | Evolução para **56 objetos JSON / 18 functions**: adição de `status_clp_endpoint`, `fn_status_clp` e `fn_verifica_pdf`; atualização metrológica, anti-race e de desempenho nos nós existentes. |
| `grafana_provisioning/datasources/influxdb.yaml` | Adição de `deleteDatasources` e `uid: InfluxDB-Flux` determinístico. |
| `Dockerfile.nodered`, `docker-compose.windows.yml`, `scripts/windows/exportar-imagens-offline.bat` | Pinagem determinística offline para `nodered/node-red:5.0.8`, `influxdb:2.7.12` e `grafana/grafana:13.2.4`. |
| `README.md`, `docs/RESUMO_PROJETO_SCADA.md`, `docs/DOSSIE_TECNICO_MANUTENCAO.md` | Atualização das tabelas CIP, arquitetura e sincronização 100% verbatim dos 18 nós `function` e shim de 7 camadas. |
| `historico_execucoes/10_...md`, `historico_execucoes/README.md`, `docs/RESUMO_EXECUCAO.md` | Registro permanente da Execução 10 e atualização dos ponteiros. |

---

## 3. BENCHMARK DE DESEMPENHO E VALIDAÇÃO AUTOMATIZADA + CONTÊINERES REAIS

Todos os pacotes foram validados por suíte automatizada de regressão em VM Node.js (`verify_batch1.js` e `verify_all_packages.js`) e em execução real nos contêineres Docker offline (`nodered`, `influxdb`, `grafana`):

| Cenário / Verificação | Antes | Depois | Resultado |
| :--- | :--- | :--- | :---: |
| **Benchmark `Coleta pressão` — Ensaio Padrão (7.200 amostras / 60 min @ 2 Hz)** | `315,62 ms` | **`5,36 ms`** (**58,9x mais rápido**) | **APROVADO** |
| **Benchmark Estresse `Coleta pressão` — Alta Frequência (72.000 amostras)** | `48.129,20 ms` (`48,1 s`) | **`44,30 ms`** (**1.086x mais rápido**) | **APROVADO** |
| **Tráfego CIP Ocioso no Setpoint (`fn_auto_cutoff_sp`, motor desligado)** | `21.600 escritas CIP/hora` | **`0 escritas CIP/hora`** | **APROVADO** |
| **Tráfego WebSocket Ocioso (`Decremento de tempo`, 60 s parado)** | `120 mensagens/min` | **`2 mensagens` (apenas na mudança)** | **APROVADO** |
| **Shim CIP 7 Camadas no Contêiner `nodered` (`v5.0.8`)** | 4 camadas | Log: `[micro800-shim] ethernet-ip patched: direct Message Router + TCP framing + inflight write guard + timer cleanup + REAL sync` | **APROVADO** |
| **Reassemblagem TCP Fragmentado/Coalescido + Guarda In-Flight `400 ms`** | Perda de pacote / pulso preso | 2 pacotes coalescidos + 3 fragmentos reconstruídos; `_write_seq > _inflight_seq` preservou `stage_write = true` para borda `FALSE` | **APROVADO** |
| **Metrologia ZOH + Tolerância `± 0,5 bar` + `0,00 bar` Ruptura** | Média simples / só erro `+` / `<=0` ignorado | Média ZOH imune a rajadas (`5,35 bar` exato), reprovação em `5,51 bar` (`SP=5,0`), `4,49 bar` (`SP=5,0`) e ruptura `0,00 bar` | **APROVADO** |
| **Provisionamento Grafana `13.2.4` (`grafana.db` + `/api/health`)** | `uid: P35862FFA6F3BFED8` (quebrado) | Migrado automaticamente para `uid: InfluxDB-Flux` (`RestartCount=0`, `{"database":"ok","version":"13.2.4"}`) | **APROVADO** |

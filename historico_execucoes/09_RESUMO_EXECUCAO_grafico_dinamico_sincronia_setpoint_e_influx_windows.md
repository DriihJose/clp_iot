# RESUMO DE EXECUÇÃO #09: GRÁFICO SVG DINÂMICO A4 PAISAGEM, SINCRONIA IMEDIATA DE SETPOINT (SHIM CIP 4 CAMADAS) E CORREÇÃO DO INFLUXDB NO WINDOWS

**Data:** 30 de Outubro de 2026  
**Ambiente:** Rockwell Micro850 (`192.168.1.33`, CIP EtherNet/IP) + Node-RED 4.x/5.x (Dashboard 3.6.6) + InfluxDB 2.7 + Grafana + Chromium Headless  
**Regra de Ouro:** Operação 100% Offline (Air-gapped) — Zero `npm install`, `docker pull`, rebuild online ou CDNs externos

---

## 1. ESCOPO CONSOLIDADO DA EXECUÇÃO 09

Esta execução consolida as evoluções do laudo PDF A4 Paisagem e gráfico vetorial SVG dinâmico por tempo (commits `19e1e86` e `0415fb1`) integradas à resolução definitiva de três problemas críticos de operação em bancada e manutenção:

1. **Laudo PDF A4 Paisagem de Página Única, Gráfico SVG Dinâmico (`10 a 60 min`) e Bloqueio Multinível de Tempo (`0415fb1`):**
   - Layout **A4 Paisagem (`@page { size: A4 landscape; margin: 10mm; }`, container `188mm`)** com cabeçalho horizontal, faixa única de 6 KPIs, faixa visual verde da zona de tolerância aprovada (`faixaTolY` / `faixaTolAltura`), marcador condicional de falha e geração garantida em **1 única página** sem transbordo.
   - Projeção dinâmica do eixo X (`eixoX` em `Finaliza _Teste`) ajustando automaticamente o espaçamento da grade vertical conforme a duração do ensaio (`1 min` para `10–15 min`, `2 min` para `20 min`, `5 min` para `25–60 min`), eliminando rótulos `HH:mm` duplicados.
   - Travamento imutável da duração na partida (`flow.duracao_travada`) e bloqueio multinível em 3 camadas durante o ensaio: frontend (`ng-disabled`), UI lock (11ª saída de `fn_ui_lock`) e backend (`if (flow.get('ativo') === true) return null;` em `fn_set_tempo_restante`), mantendo o dropdown fixo na duração escolhida sem ficar em branco.
   - Janela dinâmica de retenção em `Coleta pressão` (`duracao_travada + 120000 ms` durante ensaio ativo) para preservar 100% das amostras em ensaios longos (> 10 min) e remoção do truncamento artificial de segundos em `Finaliza _Teste`.

2. **Eliminação do Atraso Crônico de `0,5 bar` no Setpoint e Evolução do Shim CIP (`settings.js` + `ethernet-ip.js` + `flows.json`):**
   - **Causa Raiz Identificada:** Em `EthIpOut.onNewMsg` (`ethernet-ip.js`), zerar `tag.state.tag.controllerValue = null` antes da escrita fazia com que o ciclo `Controller.scan()` — que executa `_readTagGroup` **antes** de `_writeTagGroup` — lesse o valor antigo do Micro850 e disparasse o evento `"Initialized"` com `0,5 bar` de defasagem. Esse valor antigo sobrescrevia `Pressão definida do teste:` (via fio direto de `eth_in_setpoint`) e atualizava `flow.sp_plc` com timestamp mais recente que `flow.sp_ui`. Em seguida, `unstageWriteRequest()` atribuía `tag.controllerValue = tag.value` diretamente sem acionar o setter `controller_value`, impedindo a emissão de `"Changed"` após a confirmação da escrita.
   - **Solução Implementada:**
     1. Remoção de `tag.state.tag.controllerValue = null` em `nodered_data/node_modules/node-red-contrib-cip-ethernet-ip/red/ethernet-ip.js`.
     2. Evolução do bloco `[micro800-shim]` em `nodered_data/settings.js` (versionado no Git) para 4 camadas:
        - **Camada 1:** Roteamento direto ao `Message Router` (`Controller.prototype.write_cip` via `ENIP.write_cip`, sem backplane).
        - **Camada 2:** Despacho forçado CIP via `tag.write_ready` (`stage_write`) em `TagGroup.prototype.generateWriteMessageRequests` (`tag.value !== null && (tag.write_ready || tag.value !== tag.controller_value)`), garantindo o envio efetivo dos pulsos SET/RESET de `400 ms` mesmo quando `tag.value === tag.controller_value`.
        - **Camada 3:** Interceptação do setter `Tag.prototype.controller_value` suprimindo emissões `"Initialized"` / `"Changed"` de leituras pré-escrita enquanto `stage_write === true`.
        - **Camada 4:** Sobrescrita de `Tag.prototype.unstageWriteRequest` limpando `stage_write = false`, normalizando tags `REAL` (`0xca`) com `Math.fround(Number(tag.value))` (precisão IEEE-754 Float32 idêntica a `readFloatLE`) e acionando `this.controller_value = tag.value` para confirmação imediata pós-escrita.
     3. Blindagem no `flows.json`: arredondamento de 2 casas decimais em `fn_cache_setpoint`, remoção do fio direto `eth_in_setpoint -> 9c879e7c29e0e8de` e evolução de `fn_cache_setpoint_plc` para 2 saídas (`Pressão definida do teste:` e `PRESSÃO DESEJADA:` com `passthru: false`) dotado de filtro anti-eco atrasado de `1500 ms`.

3. **Correção Definitiva de Gravação no InfluxDB / Grafana no Windows (`docker-compose.windows.yml`):**
   - **Causa Raiz Identificada:** A diretiva `extra_hosts: ["host.docker.internal:host-gateway"]` no serviço `nodered` do `docker-compose.windows.yml` injetava `192.168.65.254 host.docker.internal` em `/etc/hosts`, sobrepondo o DNS interno do Docker (`127.0.0.11`) e provocando falhas contínuas `AggregateError [ETIMEDOUT]: connect ETIMEDOUT 192.168.65.254:8086`.
   - **Solução Implementada:** Remoção de `extra_hosts` apenas do serviço `nodered` em `docker-compose.windows.yml` (mantendo-o intacto em `docker-compose.yml` para Linux `network_mode: host`). Como o serviço `influxdb` declara o alias `host.docker.internal` na rede `iot-network`, o Node-RED no Windows passa a resolver `http://host.docker.internal:8086` diretamente para o IP interno do contêiner `influxdb` (`172.18.0.2`), mantendo 100% de compatibilidade multiplataforma Windows/Linux com um único `flows.json`.

4. **Higiene Técnica do Fluxo (`flows.json`) e Sincronização Integral dos Dossiês:**
   - Remoção do nó `influxdb out` duplicado `bb3820654f2359db` (pós-`Coleta pressão`), mantendo exclusivamente o nó `398b99857e5197e4` conectado diretamente ao nó `PRESSAO` (`fba7dcc329b4be25`) para gravar uma única vez cada leitura real da measurement `PT-010` (incluindo `0.00 bar` na despressurização).
   - Desempilhamento visual no canvas: reposicionamento do nó `COMPARACAO` (`eth_in_comparacao`) de `(x: 160, y: 840)` (sobreposto a `VALVULA`) para `(x: 160, y: 620)`.
   - Sincronização integral (100% verbatim) de todos os 16 nós `function` e arquivos de infraestrutura entre `DOSSIE_TECNICO_MANUTENCAO.md` e `docs/DOSSIE_TECNICO_MANUTENCAO.md`.

---

## 2. ARQUIVOS ALTERADOS

| Arquivo | Natureza da Alteração |
| :--- | :--- |
| `nodered_data/node_modules/node-red-contrib-cip-ethernet-ip/red/ethernet-ip.js` | Remoção de `tag.state.tag.controllerValue = null` em `EthIpOut.onNewMsg`. |
| `nodered_data/settings.js` | Evolução do `[micro800-shim]` para 4 camadas (`write_cip`, `generateWriteMessageRequests` via `write_ready`, supressão em `controller_value` durante `stage_write` e `unstageWriteRequest` com `Math.fround`). |
| `nodered_data/flows.json` | Blindagem de `fn_cache_setpoint` e `fn_cache_setpoint_plc` (2 saídas + filtro anti-eco 1500 ms), remoção do fio direto de `eth_in_setpoint`, remoção do nó duplicado `bb3820654f2359db` (`PT-010`) e reposicionamento de `eth_in_comparacao` para `(160, 620)`. |
| `docker-compose.windows.yml` | Remoção de `extra_hosts` no serviço `nodered` para resolução DNS direta via alias `host.docker.internal` na `iot-network`. |
| `DOSSIE_TECNICO_MANUTENCAO.md` e `docs/DOSSIE_TECNICO_MANUTENCAO.md` | Sincronização integral byte a byte da infraestrutura, shim CIP e todos os 16 nós `function`. |
| `historico_execucoes/README.md`, `RESUMO_EXECUCAO.md` e `docs/RESUMO_EXECUCAO.md` | Registro permanente da Execução 09 e atualização dos ponteiros. |

---

## 3. VALIDAÇÃO EM BANCADA REAL (MICRO850 ONLINE + DOCKER WINDOWS OFFLINE)

O contêiner `nodered` foi recriado em modo estritamente offline (`docker compose -f docker-compose.windows.yml up -d --no-build nodered`) e submetido à bateria completa de validação com o CLP Rockwell Micro850 (`192.168.1.33`) conectado fisicamente:

| Verificação | Evidência Comprovada em Execução Real | Status |
| :--- | :--- | :---: |
| **Shim CIP 4 Camadas Ativo no Boot** | Log inicial: `[micro800-shim] ethernet-ip patched: direct Message Router + stage_write forced dispatch + REAL sync` | **APROVADO** |
| **DNS e Saúde do InfluxDB no Windows** | `host.docker.internal -> 172.18.0.2` \| `GET /health -> HTTP 200 {"status":"pass","version":"v2.7.12"}` \| **Zero** warnings `Write to InfluxDB failed` | **APROVADO** |
| **Gravação Única de `PT-010` e `vp-01`** | Query Flux no bucket `carrinho` (`org: vigor`) confirmou amostras `PT-010` únicas a cada `500 ms` (`~4.703 bar`) e keepalive `vp-01` a cada `2 s` | **APROVADO** |
| **Sincronia de Setpoint (Cliques Simples)** | `5.0 -> 5.5 bar` e `5.5 -> 6.0 bar`: `sp_ui === sp_plc === PRESSÃO DESEJADA === Pressão definida` imediatamente, zero atraso de `0,5 bar` | **APROVADO** |
| **Sincronia de Setpoint (Cliques Rápidos)** | Rajada `6.0 -> 6.5 -> 7.0 -> 6.5 -> 6.0 -> 5.5 -> 5.0 bar` (passo 120 ms): sem regressão visual e convergência exata `sp_ui = 5`, `sp_plc = 5` | **APROVADO** |
| **Partida Imediata após Mudança de Setpoint** | Alteração `5.0 -> 5.5 bar` seguida de `INICIAR TESTE` em `< 50 ms`: `sp_travado = 5.5`, `sp_plc = 5.5`, `ativo = true` | **APROVADO** |
| **Pulsos SET/RESET de `400 ms` (Motor/Válvula)** | Seleção de `LIBERAR MANUAL` (`3`): `off_node = true` / `offval_node = true` em `t = 150 ms` e retorno limpo a `false` após `400 ms` | **APROVADO** |
| **Bloqueio Multinível do Seletor de Tempo** | Tentativa de alterar duração durante `ativo === true` bloqueada (`duracao_travada` preservada); em `ativo === false`, ajuste normal (`20 min` = `1200000 ms`) | **APROVADO** |
| **Laudo PDF A4 Paisagem de Página Única** | Renderização offline via Chromium Headless gerou PDF válido de **1 página** (`MediaBox [0 0 841.92 594.96]`, `5.50 bar`, grade SVG dinâmica) | **APROVADO** |

---

## 4. CONCLUSÃO

O sistema SCADA/IoT encontra-se 100% sincronizado, higienizado e homologado em bancada física em regime estritamente offline (air-gapped), eliminando definitivamente a defasagem de `0,5 bar` no setpoint e o timeout de rede do InfluxDB no Windows, com documentação de manutenção integralmente espelhada ao código em produção.


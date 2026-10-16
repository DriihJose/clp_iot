# RESUMO DE EXECUÇÃO #05: HOMOLOGAÇÃO DE OPERAÇÃO 100% OFFLINE (AIR-GAPPED) EM WINDOWS E LINUX

**Data:** 16 de Outubro de 2026  
**Ambiente:** Windows 10/11 (Docker Desktop / WSL2) & Linux (Ubuntu Nativo)  
**Objetivo:** Eliminar qualquer chamada, dependência ou verificação de rede externa (internet), garantindo que a aplicação SCADA/IoT da bancada de teste hidrostático inicialize e opere com 100% de autonomia e isolamento (air-gapped).

---

## 1. DIAGNÓSTICO DAS DEPENDÊNCIAS DE INTERNET IDENTIFICADAS

Durante os testes de campo em ambiente desconectado, foram mapeados 5 pontos de bloqueio que exigiam conectividade externa:

1. **Recompilação Forçada com Flag `--build` (Alpine `apk`):**  
   Os scripts de inicialização executavam `docker compose up -d --build`. Isso forçava o Docker a reprocessar o `Dockerfile.nodered`, acionando o gerenciador `apk add` para instalar o Chromium headless e fontes. Sem internet, a resolução de nomes para `dl-cdn.alpinelinux.org` falhava e abortava o contêiner.
2. **Consultas a Registros Remotos do Docker Hub (Tags `:latest`):**  
   Imagens com tags mutáveis (`clp_iot-nodered:latest` e `grafana/grafana:latest`) disparavam tentativas de verificação de digest remoto no Docker Hub (`registry-1.docker.io`).
3. **Telemetria, Notificações e Catálogo Externo de Paletas:**  
   * **Node-RED:** Consultava `catalogue.nodered.org` no carregamento do Palette Manager e enviava telemetria para `nodered.org`.
   * **Grafana:** Consultava `stats.grafana.org` para telemetria de uso e `grafana.com` para feed de notícias e checagem de novas versões.
   * **InfluxDB:** Disparava telemetria periódica para `telemetry.influxdata.com`.
4. **Instalação Não Blindada de Dependências (`docker-entrypoint.sh`):**  
   O script de entrada executava `npm install` caso `ethernet-ip` não fosse detectado, tentando conectar ao `registry.npmjs.org`.
5. **Suposições de Roteamento:**  
   Documentações e instruções anteriores assumiam tráfego simultâneo com Wi-Fi/Internet, enquanto na bancada a comunicação é estritamente ponto a ponto com o CLP via cabo Ethernet (sem Gateway).

---

## 2. INTERVENÇÕES REALIZADAS E CORREÇÕES DE CÓDIGO

### 2.1 Orquestração Docker (`docker-compose.windows.yml` e `docker-compose.yml`)
* **Diretiva `pull_policy: missing`:** Aplicada em todos os serviços (`nodered`, `influxdb`, `grafana`), impedindo que o Docker tente contatar o registro remoto quando a imagem já existir localmente.
* **Desativação Total de Telemetria:**
  * **Grafana:** Adicionadas as variáveis de ambiente `GF_ANALYTICS_REPORTING_ENABLED=false`, `GF_ANALYTICS_CHECK_FOR_UPDATES=false`, `GF_NEWS_NEWS_FEED_ENABLED=false` e `GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS=""`.
  * **InfluxDB:** Adicionada a variável `INFLUXD_REPORTING_DISABLED=true`.
* **Montagem de Volume do Entrypoint:** Mapeado `./docker-entrypoint.sh:/usr/local/bin/docker-entrypoint.sh:ro` para permitir atualizações de inicialização sem demandar rebuild da imagem.

### 2.2 Automação de Inicialização (`setup-windows.ps1` e `setup-linux.sh`)
* **Remoção da Flag `--build` Obrigatória:** O script agora inspeciona o cache local (`docker images -q clp_iot-nodered:latest`). Existindo a imagem local, a inicialização ocorre em modo 100% offline via `docker compose up -d` (boot instantâneo).
* **Auto-carregamento de Imagens Offline (`.tar`):** Se arquivos `.tar` de imagens Docker estiverem presentes na pasta do projeto, o script executa automaticamente `docker load -i`, viabilizando instalação limpa via pen drive.
* **Diagnóstico Ponto a Ponto do CLP:** Adicionado teste de conectividade ICMP direto ao IP `192.168.1.33` (Micro850) no script.

### 2.3 Runtime do Node-RED (`nodered_data/settings.js` e `docker-entrypoint.sh`)
* **`settings.js`:**
  * `telemetry: { enabled: false, updateNotification: false }`
  * `editorTheme.palette.catalogues: []` *(desabilita consulta a catálogo online)*
  * `externalModules: { autoInstall: false }`
* **`docker-entrypoint.sh`:** Verificação de pacotes restringida a `--offline` utilizando o cache local em `/data/.npm`.

### 2.4 Utilitários e Scripts em Lote (`.bat`)
* **`iniciar-sistema.bat`:** Execução com 1 clique do ambiente Windows.
* **`parar-sistema.bat`:** Encerramento seguro dos contêineres e liberação de portas.
* **`exportar-imagens-offline.bat`:** Empacota as 3 imagens em `imagens-offline.tar` para transporte físico seguro.

---

## 3. VALIDAÇÃO E HOMOLOGAÇÃO EM BANCADA

Após a aplicação dos patches, o sistema foi validado em teste com rede física isolada:

| Verificação | Resultado | Status |
| :--- | :--- | :---: |
| **Comunicação CLP Micro850** | Ping direto a `192.168.1.33` via placa `Ethernet` (`192.168.1.200`) | **OK** |
| **Boot dos Contêineres** | Inicialização sem rebuild ou consultas externas (0 chamadas a registros) | **OK** |
| **Supervisório IHM (`:1880/ui`)** | Interface carregada sem bloqueios ou timeouts de fontes/CDNs | **200 OK** |
| **Editor Node-RED (`:1880`)** | Inicializado com paleta local e sem requisições externas | **200 OK** |
| **Banco InfluxDB (`:8086`)** | Autenticação e gravação ativas sem envio de métricas externas | **200 OK** |
| **Grafana (`:3000`)** | Dashboard analítico carregado com todas as consultas locais | **200 OK** |
| **Laudos PDF (`relatorios/`)** | Chromium headless gera relatórios A4 com gráficos SVG vetoriais offline | **OK** |

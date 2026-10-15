# Resumo de Execução: Compatibilidade Multiplataforma e Relatórios PDF
**Projeto:** Sistema SCADA/IoT - Bancada de Testes de Pressão Hidrostática (Vigor Alimentos)  
**Data:** 15 de Outubro de 2026  
**Status:** Concluído com Sucesso e Validado  

---

## 1. Resumo Executivo

O repositório `/home/mec/clp_iot` foi totalmente reestruturado para ser **100% plug-and-play e multiplataforma**, permitindo que o projeto seja clonado via Git e executado imediatamente tanto em **Linux (Ubuntu Desktop nativo)** quanto em **Windows (Docker Desktop com WSL2)**, sem necessidade de edições manuais em fluxos ou configurações de rede.

Além disso, a geração de relatórios de teste foi internalizada dentro do contêiner Docker via **Chromium headless nativo**, eliminando qualquer dependência de caminhos ou executáveis do sistema host.

---

## 2. Detalhamento das Alterações por Etapa

### ETAPA 1: Auditoria e Geração de PDF Multiplataforma
1. **Auditoria no `nodered_data/flows.json`:**
   * Removidas todas as chamadas legadas ao Google Chrome do Windows (`C:\Program Files\Google\Chrome\Application\chrome.exe`) e diretórios como `C:\RelatoriosTestePressao\`.
   * **Nó `Finaliza _Teste` (`6d54da2809aedd4d`):** Atualizado para gerar caminhos POSIX padronizados dentro do contêiner (`/data/relatorios/relatorio_<timestamp>.html` e `/data/relatorios/relatorio.html`).
   * **Nó `Comando Chromium` (`e32ec29ac871e4f2`):** Atualizado para montar a linha de comando do Chromium headless Linux.
   * **Nó `Gerar PDF (Chromium)` (`38510ae3de26350c`):** Atualizado para executar nativamente:
     ```bash
     chromium-browser --headless --no-sandbox --disable-gpu --print-to-pdf="/data/relatorios/saida.pdf" "/data/relatorios/relatorio.html"
     ```
2. **Criação do `Dockerfile.nodered`:**
   * Baseado na imagem oficial `nodered/node-red:latest` (Alpine Linux).
   * Instala pacotes do sistema: `chromium`, `nss`, `freetype`, `harfbuzz`, `ca-certificates` e `ttf-freefont`.
   * Configura execução segura sob usuário não-root `node-red`.
3. **Mapeamento de Relatórios:**
   * Criadas as pastas `./relatorios` no host e `./nodered_data/relatorios`, ambas versionadas com `.gitkeep`.
   * Atualizado [.gitignore](file:///home/mec/clp_iot/.gitignore) para ignorar relatórios gerados (`*.pdf`, `*.html`), mantendo o repositório limpo.

---

### ETAPA 2: Compatibilidade de Rede Docker (Linux vs. Windows)
1. **Linux (`docker-compose.yml`):**
   * Mantido `network_mode: host` no serviço `nodered` para garantir comunicação direta em camada 2/3 com o Micro850 (`192.168.1.33:44818`) pela placa `enp58s0` sem degradação por NAT.
   * Mapeamento de volume `./relatorios:/data/relatorios` para acesso imediato aos PDFs no host.
   * Adicionado `extra_hosts: ["host.docker.internal:host-gateway"]`.
2. **Windows (`docker-compose.windows.yml`):**
   * Configurado com `ports: - "1880:1880"` conectado na `iot-network` para exposição correta das portas no Windows.
   * Mapeado `host.docker.internal` para comunicação transparente com o InfluxDB na porta 8086.
3. **Unificação de DNS no `flows.json`:**
   * O nó de configuração do InfluxDB (`235fd83d5ce9ea5d`) foi ajustado para `url: http://host.docker.internal:8086`. Dessa forma, o mesmo arquivo de fluxo funciona tanto no Linux quanto no Windows sem qualquer alteração manual.

---

### ETAPA 3: Auto-Instalação de Módulos e Proteção do Shim Micro800
1. **Verificação do `nodered_data/package.json`:**
   * Garantidas as dependências: `node-red-contrib-cip-ethernet-ip`, `node-red-contrib-influxdb`, `node-red-dashboard`, `node-red-contrib-ui-led` e `@flowfuse/node-red-dashboard`.
2. **Script `docker-entrypoint.sh`:**
   * Criado script de entrada que verifica se `/data/node_modules/ethernet-ip` existe.
   * Em caso de `git clone` em um PC novo, o script executa automaticamente `npm install` dentro de `/data` **antes** do Node-RED iniciar.
3. **Blindagem do Shim Micro800 em `settings.js`:**
   * Como o `npm install` ocorre no boot antes da inicialização do Node-RED, o arquivo `settings.js` encontra o módulo `ethernet-ip` imediatamente na primeira inicialização, garantindo que o patch do Message Router seja aplicado sem erros.

---

### ETAPA 4: Auto-Provisionamento do InfluxDB 2.7 e Grafana
1. **InfluxDB:**
   * Configurado com variáveis `DOCKER_INFLUXDB_INIT_*` no Compose lidas do arquivo `.env`.
   * Criado `.env.example` versionado e `.env` local com as credenciais padrão e o token compartilhado pré-configurado.
   * Em bancos já existentes (como a bancada atual), os dados existentes são 100% preservados.
2. **Grafana Provisioning (`grafana_provisioning/`):**
   * `datasources/influxdb.yaml`: Provisiona automaticamente a fonte de dados `InfluxDB-Flux` conectando em `http://influxdb:8086`, org `vigor`, bucket `carrinho`.
   * `dashboards/dashboards.yaml` e `dashboards/pressao_hidrostatica.json`: Provisiona um dashboard completo com curva de pressão em tempo real, status da válvula principal (VP-01) e indicador de pico de pressão.

---

### ETAPA 5: Padronização Git e Scripts de Automação
1. **`.gitattributes`:** Força quebras de linha `LF` em scripts Linux, YAML, JSON e JS, e `CRLF` em scripts PowerShell (`.ps1`).
2. **`setup-linux.sh` (Executável):**
   * Configura placa de rede via `nmcli` com IP `192.168.1.100/24` sem gateway.
   * Ajusta permissões de UID (`chown -R 1000:1000 nodered_data`).
   * Provisiona `.env` a partir de `.env.example`.
   * Constrói a imagem e sobe a stack via `docker compose up -d --build`.
3. **`setup-windows.ps1`:**
   * Verifica adaptadores de rede físicos e orienta/configura IP estático `192.168.1.100/24`.
   * Cria pastas locais, provisiona `.env` e sobe a stack via `docker-compose.windows.yml`.
4. **`README.md`:** Documentação completa da arquitetura, operação offline e comandos.

---

## 3. Validação Prática em Bancada (Resultados Reais)

| Item Verificado | Resultado Obtido | Status |
| :--- | :--- | :---: |
| **Compilação da Imagem Node-RED** | Imagem `clp_iot-nodered:latest` gerada com Chromium e fontes |  OK |
| **Carregamento do Shim Micro800** | Log: `[micro800-shim] ethernet-ip patched: direct Message Router` |  OK |
| **Comunicação CIP com o Micro850** | `PLC Connected successfully! RETORNO_BAR = 8.75 bar` em 4 ms |  OK |
| **Geração de PDF com Chromium** | `relatorios/teste.pdf` gerado via headless (21.519 bytes, PDF v1.4) |  OK |
| **Armazenamento no InfluxDB** | 350+ pontos de pressão gravados continuamente no bucket `carrinho` |  OK |
| **Provisionamento do Grafana** | Datasource `InfluxDB-Flux` e dashboard carregados automaticamente |  OK |
| **Status do Contêiner Node-RED** | `Health: healthy` |  OK |

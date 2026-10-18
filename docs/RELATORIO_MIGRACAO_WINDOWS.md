# 📘 Relatório Técnico: Execução da Aplicação Linux no Windows (Modo 100% Offline)

> **Projeto:** Sistema SCADA / IoT - Bancada de Testes de Pressão Hidrostática  
> **Controlador:** CLP Allen-Bradley Micro850 (2080-L50E @ 192.168.1.33)  
> **Stack de Software:** Node-RED 5.x / 4.x, InfluxDB 2.7, Grafana 11.x, Chromium Headless  
> **Ambiente Operacional:** Windows 10/11 (Docker Desktop com WSL2) - **100% Isolado / Air-Gapped (Sem Internet)**  

---

## 1. Contexto e Objetivo

A aplicação foi originalmente projetada e comissionada em ambiente Linux e agora opera no Windows em bancada industrial. O requisito fundamental deste ambiente de teste e chão de fábrica é a **operação 100% autônoma e offline (air-gapped)**:

* O computador do operador **não depende de internet, Wi-Fi ou roteador externo** para funcionar.
* A comunicação com o CLP Allen-Bradley Micro850 é **ponto a ponto** através de cabo Ethernet dedicado.
* Todos os serviços (supervisório IHM, gravação em banco de séries temporais, geração de gráficos analíticos e emissão de laudos PDF) rodam estritamente locais.

---

## 2. Diagnóstico: O que causava dependência de Internet e como foi corrigido

Na versão inicial da migração para Windows, o sistema ainda possuía chamadas e parâmetros que tentavam acessar a rede externa. Abaixo estão detalhadas todas as causas identificadas e as correções implementadas:

---

### 🔴 Causa 1: Flag `--build` forçando recompilação da imagem Docker via APK (Alpine)

* **O Problema:**
  * O script `setup-windows.ps1` executava `docker compose -f docker-compose.windows.yml up -d --build`.
  * A flag `--build` forçava o Docker a reconstruir o `Dockerfile.nodered` a cada inicialização.
  * O `Dockerfile.nodered` possui o comando:
    ```dockerfile
    RUN apk add --no-cache chromium nss freetype harfbuzz ca-certificates ttf-freefont
    ```
  * Sem internet, o gerenciador `apk` da Alpine tentava alcançar `dl-cdn.alpinelinux.org`, falhava com erro de resolução de DNS (`Temporary failure in name resolution`) e abortava toda a inicialização.
* **A Solução:**
  * O `setup-windows.ps1` e o `setup-linux.sh` agora checam se a imagem local `clp_iot-nodered:latest` já existe no cache do Docker.
  * **Existindo a imagem local (o caso do seu computador):** o script executa imediatamente `docker compose up -d` (sem `--build`). A inicialização ocorre em 0 segundos, totalmente offline, sem consultar repositórios externos.
  * Adicionado suporte ao arquivo `docker-entrypoint.sh` montado via volume (`:ro`) no compose, permitindo atualizações de scripts sem necessidade de recompilar a imagem.

---

### 🔴 Causa 2: Docker Compose consultando o Docker Hub para tags `:latest`

* **O Problema:**
  * Por padrão, imagens que utilizam tag `:latest` (como `grafana/grafana:latest` e `clp_iot-nodered:latest`) podem levar o Docker Compose a tentar consultar o registro remoto (`registry-1.docker.io`) para checar se há camadas novas.
  * Em ambiente desconectado, isso causava lentidão ou erros de timeout de rede.
* **A Solução:**
  * Foi adicionada a diretiva declarativa em todos os serviços do `docker-compose.windows.yml` e `docker-compose.yml`:
    ```yaml
    pull_policy: missing
    ```
  * O Docker Compose agora utiliza estritamente as imagens locais já presentes no disco, sem abrir nenhuma conexão com a internet.

---

### 🔴 Causa 3: Telemetria, Catálogo e Notificações de Atualização (Node-RED, Grafana e InfluxDB)

* **O Problema:**
  * **Node-RED:** Tentava consultar `catalogue.nodered.org` para listar nós da comunidade no Palette Manager e buscava atualizações no `nodered.org/telemetry`.
  * **Grafana:** Consultava `stats.grafana.org` para telemetria de uso, `grafana.com` para feed de notícias e checagem de novas versões.
  * **InfluxDB:** Disparava relatórios de telemetria para `telemetry.influxdata.com`.
  * Sem internet, esses serviços registravam múltiplos avisos de timeout e atrasavam a abertura das páginas.
* **A Solução:**
  1. **Node-RED (`nodered_data/settings.js`):**
     * `telemetry: { enabled: false, updateNotification: false }`
     * `editorTheme.palette.catalogues: []` *(desativa a consulta ao catálogo externo)*
     * `externalModules.autoInstall: false` *(impede tentativas de baixar módulos via npm)*
  2. **Grafana (`docker-compose.windows.yml`):**
     * `GF_ANALYTICS_REPORTING_ENABLED=false`
     * `GF_ANALYTICS_CHECK_FOR_UPDATES=false`
     * `GF_NEWS_NEWS_FEED_ENABLED=false`
     * `GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS=""`
  3. **InfluxDB (`docker-compose.windows.yml`):**
     * `INFLUXD_REPORTING_DISABLED=true`

---

### 🔴 Causa 4: Script de entrada (`docker-entrypoint.sh`) tentando `npm install`

* **O Problema:**
  * Havia uma rotina que, caso não detectasse a pasta `node_modules/ethernet-ip`, executava `npm install`.
  * Em ambiente offline, o comando `npm install` sem flags falhava ao tentar alcançar o `registry.npmjs.org`.
* **A Solução:**
  * Atualizado o `docker-entrypoint.sh` para usar modo offline estrito: caso necessário, utiliza o cache local `--offline` de `/data/.npm`.
  * Assegurado que as dependências locais (`node_modules`) permaneçam preservadas no diretório do projeto.

---

### 🔴 Causa 5: Topologia de Rede Industrial (CLP Micro850 @ 192.168.1.33)

* **Como deve ser configurada a rede física:**
  * **IP do CLP:** `192.168.1.33` (Máscara: `255.255.255.0`)
  * **IP do Computador:** deve ser configurado como IP fixo na faixa `192.168.1.x` (por exemplo `192.168.1.100` ou `192.168.1.200`), com máscara `255.255.255.0`.
  * **Gateway:** **DEIXAR EM BRANCO**. Como é uma bancada industrial isolada e sem internet, não existe roteador de gateway padrão.
  * **DNS:** Não é necessário configurar nenhum servidor DNS.
* **No seu computador:** A placa física `Ethernet` já está configurada com o IP `192.168.1.200` e o teste automático do `setup-windows.ps1` já confirmou a comunicação direta com o CLP:
  ```
  [OK] Adaptador possui IP estático na sub-rede industrial (192.168.1.x): 192.168.1.200
  [OK] Comunicação com o CLP Micro850 (192.168.1.33) confirmada!
  ```

---

## 3. Resumo de Todas as Modificações Realizadas

| Arquivo / Recurso | Ação Realizada | Justificativa Técnica |
| :--- | :--- | :--- |
| **`docker-compose.windows.yml`** | Adicionado `pull_policy: missing`, desativada telemetria do Grafana/InfluxDB e montado `docker-entrypoint.sh` | Garante inicialização 100% offline e sem consultas a registros externos |
| **`docker-compose.yml`** | Configurações idênticas de `pull_policy` e telemetria para Linux | Mantém paridade multiplataforma 100% offline |
| **`setup-windows.ps1`** | Removido `--build` forçado, adicionado teste de ping do CLP e suporte a arquivos `.tar` locais | Sobe o sistema offline instantaneamente e diagnostica cabo do CLP |
| **`setup-linux.sh`** | Mesma lógica de inicialização com verificação de imagem offline e `.tar` | Garante inicialização offline perfeita no Linux |
| **`nodered_data/settings.js`** | Desativada telemetria, aviso de updates e catálogo externo de paletas | Elimina timeouts e tráfego externo no Node-RED |
| **`docker-entrypoint.sh`** | Fallback de auto-instalação restrito a `--offline` | Impede que o contêiner tente acessar o `registry.npmjs.org` |
| **`exportar-imagens-offline.bat`** | Criado script utilitário de exportação para pen drive | Permite empacotar as 3 imagens Docker em um único arquivo `.tar` para transporte físico |
| **`iniciar-sistema.bat`** | Atalho operacional de 1 clique | Executa o setup offline sem exigir terminal aberto pelo usuário |
| **`parar-sistema.bat`** | Atalho operacional de encerramento | Finaliza os contêineres de forma limpa preservando dados |

---

## 4. Portabilidade para Outras Máquinas Offline (Pen Drive / Instalação Limpa)

Se você precisar levar este projeto para outro computador industrial que nunca foi conectado à internet:

1. Na sua máquina atual (com as imagens já baixadas), execute:
   * **`exportar-imagens-offline.bat`**
   * Isso criará o arquivo **`imagens-offline.tar`** contendo Node-RED, InfluxDB e Grafana.
2. Copie toda a pasta do projeto (junto com `imagens-offline.tar`) em um pen drive.
3. No computador de destino:
   * Instale o Docker Desktop.
   * Dê duplo clique em **`iniciar-sistema.bat`**.
   * O script detectará automaticamente o arquivo `.tar`, importará as imagens para o Docker local e subirá toda a bancada sem precisar de um único byte de conexão externa.

---

## 5. Status Atual e Testes de Validação

Todos os contêineres estão em execução ativa local e foram testados com respostas `HTTP 200 OK`:

| Serviço | URL Local | Função Operacional | Status |
| :--- | :--- | :--- | :---: |
| **IHM do Operador (Supervisório)** | **[http://localhost:1880/ui](http://localhost:1880/ui)** | Manômetros, setpoints, ciclo automático e intertravamentos | **200 OK** |
| **Editor de Engenharia Node-RED** | **[http://localhost:1880](http://localhost:1880)** | Driver CIP Allen-Bradley, lógica de controle e relatórios | **200 OK** |
| **Grafana Analítico** | **[http://localhost:3000](http://localhost:3000)** | Gráficos históricos de pressão (*user: admin / pass: admin*) | **200 OK** |
| **Banco InfluxDB 2.7** | **[http://localhost:8086](http://localhost:8086)** | Armazenamento de séries temporais de pressão e setpoint | **200 OK** |
| **Laudos e Relatórios PDF** | `.\relatorios` | Geração local via Chromium headless sem dependência externa | **Pronto** |

---

## 6. Procedimento de Operação

* **Para Iniciar:** Dê duplo clique em **`iniciar-sistema.bat`**.
* **Para Encerrar:** Dê duplo clique em **`parar-sistema.bat`**.

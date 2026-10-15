# Sistema SCADA / IoT - Bancada de Testes de Pressão Hidrostática

Sistema supervisório e de aquisição de dados industrial para bancada de ensaios de pressão hidrostática (Vigor Alimentos / Detecto), integrando **CLP Allen-Bradley Micro850 (2080-L50E)**, **Node-RED**, **InfluxDB 2.7** e **Grafana** em contêineres Docker multiplataforma (Linux Ubuntu e Windows com Docker Desktop), operando **100% OFFLINE**.

> 📖 **DOCUMENTAÇÃO DE ENGENHARIA E MANUTENÇÃO:**  
> - **[DOSSIE_TECNICO_MANUTENCAO.md](DOSSIE_TECNICO_MANUTENCAO.md):** Manual técnico completo com a íntegra de todos os códigos JavaScript, nós `function`, variáveis de contexto (`flow.*`), arquivos de infraestrutura e procedimentos de calibração/destravamento ao vivo.  
> - **[RESUMO_EXECUCAO.md](RESUMO_EXECUCAO.md):** Ponteiro central do histórico permanente de bancada mantido cronologicamente na pasta [`historico_execucoes/`](historico_execucoes/).

---

## 1. Arquitetura do Sistema

```
+-----------------------------------------------------------------------------------+
|                           COMPUTADOR DA BANCADA / IHM                             |
|                                                                                   |
|  +--------------------+        +--------------------+        +-----------------+  |
|  |     Node-RED       | (HTTP) |      InfluxDB      | (Flux) |     Grafana     |  |
|  |  (Supervisório /ui)|------->|      (v2.7.12)     |<-------|   (Porta 3000)  |  |
|  |  (Relatórios PDF)  |        |    (Porta 8086)    |        +-----------------+  |
|  +---------+----------+        +--------------------+                             |
|            | (EtherNet/IP CIP Nativo - Porta TCP 44818)                           |
+------------|----------------------------------------------------------------------+
             | Cabo de Rede Ethernet (Sub-rede 192.168.1.0/24)
             v
+---------------------------------------------------+
|      CLP Allen-Bradley Micro850 (2080-L50E)       |
|      IP Fixo: 192.168.1.33 | Slot: 0 | Modo: RUN  |
+---------------------------------------------------+
```

### Tecnologias e Serviços:
* **Node-RED 4.x:** Supervisório web do operador (`/ui`), driver CIP Simbólico com o CLP, lógica de intertravamento de segurança, temporização e gerador de relatórios PDF com Chromium headless.
* **InfluxDB 2.7:** Armazenamento de séries temporais de alta performance (Org: `vigor`, Bucket: `carrinho`).
* **Grafana 11.x:** Painéis analíticos com 5 cartões superiores reorganizados e curvas de pressão com setpoint dinâmico provisionados via código.
* **CLP Micro850:** Controlador do processo com tags globais de leitura e comando direto (Message Router).

---

## 2. Início Rápido (Quick Start)

### Pré-requisitos:
* **Docker** e **Docker Compose** instalados.
* Cabo de rede conectado diretamente à porta Ethernet do CLP Micro850.

---

### 🐧 Executando no Linux (Ubuntu Desktop / Debian)

1. Clone o repositório:
   ```bash
   git clone https://github.com/DriihJose/clp_iot.git
   cd clp_iot
   ```
2. Execute o script automatizado de configuração e inicialização:
   ```bash
   ./setup-linux.sh
   ```
   *O script configura a placa de rede com IP estático `192.168.1.100/24` sem gateway (evitando conflitos com Wi-Fi), ajusta permissões de pastas, constrói a imagem com Chromium e inicia os contêineres em `network_mode: host`.*

---

### 🪟 Executando no Windows (Docker Desktop com WSL2)

1. Abra o **PowerShell** como Administrador e clone o repositório:
   ```powershell
   git clone https://github.com/DriihJose/clp_iot.git
   cd clp_iot
   ```
2. Configure o IP estático no adaptador de rede Ethernet do Windows:
   * **IP:** `192.168.1.100`
   * **Máscara:** `255.255.255.0`
   * **Gateway:** *(deixe em branco)*
3. Execute o script de inicialização do Windows:
   ```powershell
   .\setup-windows.ps1
   ```
   *O script provisiona as pastas, gera o `.env` e sobe a stack via `docker-compose.windows.yml` com as portas devidamente mapeadas no Windows e alias de rede para o InfluxDB.*

---

## 3. URLs de Acesso

Após inicializar a stack, os seguintes serviços estarão disponíveis:

| Serviço | URL | Descrição |
| :--- | :--- | :--- |
| **IHM / Supervisório** | **[http://localhost:1880/ui](http://localhost:1880/ui)** | Tela operacional do teste (intertravamentos, manômetro, botões, LED) |
| **Editor Node-RED** | **[http://localhost:1880](http://localhost:1880)** | Fluxos e lógica de controle |
| **Grafana** | **[http://localhost:3000](http://localhost:3000)** | Gráficos analíticos provisionados (*user: admin / pass: admin*) |
| **InfluxDB 2.7** | **[http://localhost:8086](http://localhost:8086)** | Painel do banco de dados de telemetria |
| **Pasta de Relatórios** | **`./relatorios`** | Arquivos HTML e relatórios PDF individuais gerados automaticamente |

---

## 4. Mapeamento de Tags CIP (Micro850)

Toda a comunicação utiliza EtherNet/IP CIP nativo no endpoint `192.168.1.33:44818` (Slot 0). **Zero protocolos legados (PCCC/DF1).**

| Tag no CLP | Tipo | Direção | Função no Sistema |
| :--- | :--- | :--- | :--- |
| `RETORNO_BAR` | `REAL` | Entrada (Read) | Pressão em tempo real lida pelo transmissor analógico (0 a 10 bar). |
| `_IO_EM_DO_00` | `BOOL` | Entrada (Read) | Feedback elétrico da saída digital física da válvula solenoide. |
| `setpoint_node` | `REAL` | Bidirecional | Pressão desejada de teste (3 BAR, 6 BAR, 8 BAR ou customizado). |
| `on_node` | `DINT` | Saída (Write) | Comando manual de ligar motor/bomba hidráulica. |
| `off_node` | `DINT` | Saída (Write) | Comando manual de desligar motor/bomba hidráulica. |
| `onval_node` | `DINT` | Saída (Write) | Comando manual de abertura da válvula solenoide. |
| `offval_node` | `DINT` | Saída (Write) | Comando manual de fechamento da válvula solenoide. |
| `ciclo_node` | `BOOL` | Saída (Write) | Sinaliza ciclo de teste hidrostático em andamento (`true`) ou finalizado (`false`). |

---

## 5. Destaques Técnicos de Engenharia

### A. Intertravamento de Segurança e Bloqueio Dinâmico de UI
O sistema impede erros humanos antes e durante o ensaio:
1. **Condições de Partida:** O botão `INICIAR TESTE` audita 4 requisitos obrigatórios:
   - Nome do Equipamento preenchido.
   - Motor desligado.
   - Válvula solenoide fechada (no comando e na leitura física).
   - Setpoint de pressão definido e válido.
   *(Se houver pendência, a partida é bloqueada e um alerta vermelho temporário é exibido no campo `STATUS:`)*.
2. **Bloqueio Seletivo de UI (`msg.enabled`):** Enquanto o ensaio roda, todos os campos de edição e switches manuais são desabilitados na interface, mantendo acessível exclusivamente o botão `FINALIZAR TESTE`.

### B. Shim de Compatibilidade Micro800 no `settings.js`
A família Micro800 não possui backplane modular físico. Drivers CIP convencionais (como `ethernet-ip`) encapsulam todas as requisições em pacotes *Unconnected Send* com saltos de backplane (Porta 1, Slot X), causando erro de `TIMEOUT occurred while reading Controller Props`.  
O arquivo [`nodered_data/settings.js`](nodered_data/settings.js) inclui um **shim de interceptação** que direciona as mensagens diretamente ao *Message Router* do CLP (método idêntico ao `pylogix`), estabilizando a conexão CIP.

### C. Geração de Laudos PDF Independentes via Chromium Headless
O contêiner do Node-RED compila internamente relatórios individuais para cada ensaio realizado:
* **Nomenclatura Dinâmica Única:** `<Equipamento>_<DD-MM-AAAA_HH-mm-ss>.pdf` salvo diretamente em `./relatorios/`.
* **Zero sobrescrita:** Testes sucessivos não apagam ensaios anteriores.
* **Layout A4 Otimizado:** Gráfico de pressão vetorial SVG responsivo com linha de setpoint, marcação de ponto de falha (se reprovado), tabela estatística (média, mín, máx, erro), tolerância de 0.5 bar, carimbo de emissão brasileiro (`America/Sao_Paulo`) e flag `--no-pdf-header-footer` (sem cabeçalhos indesejados do browser).

### D. Dashboards Grafana com Setpoint Dinâmico
* **5 Cartões Superiores Reorganizados:** Pressão Atual (manômetro em bar), Status da Válvula (Aberta/Fechada), Pressão Máxima, Pressão Mínima e Pressão Média.
* **Setpoint em Série Temporal:** O setpoint congelado no início do teste é gravado no InfluxDB durante o ensaio, gerando uma linha de referência visualmente sincronizada com a curva de pressão lida.

---

## 6. Procedimento para Operação Offline (Bancada sem Internet)

Para levar a bancada para campo sem conexão de internet:

1. **Na máquina de desenvolvimento (com internet):**
   ```bash
   # Salve as imagens Docker:
   docker save -o imagens_scada.tar clp_iot-nodered:latest influxdb:2.7 grafana/grafana:latest
   
   # Compacte a pasta do projeto incluindo as dependências já baixadas:
   tar -czvf clp_iot_bancada.tar.gz /home/mec/clp_iot
   ```
2. **Na máquina de bancada (sem internet):**
   ```bash
   # Extraia o arquivo e carregue as imagens:
   tar -xzvf clp_iot_bancada.tar.gz
   cd clp_iot
   docker load -i imagens_scada.tar
   
   # Inicie a aplicação normalmente:
   ./setup-linux.sh
   ```

---

## 7. Registro Permanente de Execuções e Auditoria

Todas as alterações, diagnósticos e manutenções do projeto seguem o princípio de histórico imutável:
* Cada intervenção gera um relatório numerado em [`historico_execucoes/`](historico_execucoes/).
* O sumário completo está indexado em [`historico_execucoes/README.md`](historico_execucoes/README.md).
* O documento [`DOSSIE_TECNICO_MANUTENCAO.md`](DOSSIE_TECNICO_MANUTENCAO.md) na raiz do repositório consolida o estado de arte e todas as instruções de manutenção.

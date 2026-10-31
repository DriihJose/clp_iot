# Sistema SCADA / IoT - Bancada de Testes de Pressão Hidrostática

Sistema supervisório e de aquisição de dados industrial para bancada de ensaios de pressão hidrostática (Vigor Alimentos / Detecto), integrando **CLP Allen-Bradley Micro850 (2080-L50E)**, **Node-RED**, **InfluxDB 2.7** e **Grafana** em contêineres Docker multiplataforma (Linux Ubuntu e Windows com Docker Desktop), operando **100% OFFLINE**.

> 📖 **DOCUMENTAÇÃO DE ENGENHARIA E OPERAÇÃO:**  
> - **[`docs/DOSSIE_TECNICO_MANUTENCAO.md`](docs/DOSSIE_TECNICO_MANUTENCAO.md):** Manual técnico completo com a íntegra de todos os códigos JavaScript, nós `function`, variáveis de contexto (`flow.*`), arquivos de infraestrutura e procedimentos de calibração/destravamento ao vivo.  
> - **[`docs/RELATORIO_MIGRACAO_WINDOWS.md`](docs/RELATORIO_MIGRACAO_WINDOWS.md):** Diagnóstico e implementação da operação 100% autônoma e offline no Windows.  
> - **[`docs/RESUMO_PROJETO_SCADA.md`](docs/RESUMO_PROJETO_SCADA.md):** Visão executiva da arquitetura e especificações do sistema.  
> - **[`docs/RESUMO_EXECUCAO.md`](docs/RESUMO_EXECUCAO.md):** Ponteiro central do histórico permanente de bancada mantido em [`historico_execucoes/`](historico_execucoes/).  
> - **[`scripts/README.md`](scripts/README.md):** Documentação detalhada dos scripts operacionais para Windows e Linux.

---

## 1. Estrutura do Projeto

```text
C:\aplicacoes\clp_iot\
├── docs/                       # Documentações técnicas e relatórios de engenharia
│   ├── DOSSIE_TECNICO_MANUTENCAO.md
│   ├── RELATORIO_MIGRACAO_WINDOWS.md
│   ├── RESUMO_PROJETO_SCADA.md
│   ├── RESUMO_EXECUCAO.md
│   └── README.md
├── scripts/                    # Scripts operacionais e de ciclo de vida
│   ├── windows/                # Scripts Windows (iniciar, parar, backup, GitHub)
│   │   ├── iniciar-sistema.bat
│   │   ├── parar-sistema.bat
│   │   ├── setup-windows.ps1
│   │   ├── exportar-imagens-offline.bat
│   │   ├── enviar-github.bat
│   │   └── README.md
│   ├── linux/                  # Scripts Linux (iniciar, parar, setup de rede)
│   │   ├── iniciar-sistema.sh
│   │   ├── parar-sistema.sh
│   │   ├── setup-linux.sh
│   │   └── README.md
│   └── README.md
├── nodered_data/               # Fluxos, nós e credenciais do Node-RED
├── relatorios/                 # Relatórios HTML e PDFs gerados ao finalizar testes
├── grafana_provisioning/       # Dashboards e datasources automáticos do Grafana
├── grafana_data/               # Banco de dados e configurações do Grafana
├── influxdb_data/              # Dados de séries temporais do InfluxDB
├── influxdb_config/            # Configurações do InfluxDB
├── historico_execucoes/        # Registro permanente de manutenções de bancada
├── docker-compose.windows.yml  # Orquestração de contêineres para Windows
├── docker-compose.yml          # Orquestração de contêineres para Linux
├── docker-entrypoint.sh        # Entrypoint personalizado do Node-RED
├── Dockerfile.nodered          # Imagem customizada com Chromium headless
├── iniciar-sistema.bat         # Atalho raiz para iniciar o SCADA no Windows
├── parar-sistema.bat           # Atalho raiz para parar o SCADA no Windows
├── .env                        # Variáveis de ambiente locais
└── README.md                   # Este arquivo
```

---

## 2. Início Rápido (Quick Start)

### 🪟 No Windows (Ambiente de Produção / Bancada)
1. **Pela Área de Trabalho:** Dê um duplo clique no atalho **`Iniciar SCADA`**.
2. **Ou pela pasta da aplicação:** Execute `C:\aplicacoes\clp_iot\iniciar-sistema.bat`.
3. Para encerrar o sistema com segurança: duplo clique em **`Parar SCADA`** (na Área de Trabalho ou na pasta).
4. Para acessar os relatórios gerados: duplo clique em **`Relatórios SCADA`** na Área de Trabalho.

### 🐧 No Linux (Ubuntu Desktop / Debian)
1. No terminal, navegue até a pasta do projeto:
   ```bash
   cd /caminho/do/projeto/clp_iot
   ```
2. Inicie a aplicação:
   ```bash
   ./scripts/linux/iniciar-sistema.sh
   ```
3. Para parar o sistema:
   ```bash
   ./scripts/linux/parar-sistema.sh
   ```

---

## 3. URLs e Portas de Acesso Local (100% Offline)

| Serviço | URL | Descrição |
| :--- | :--- | :--- |
| **IHM / Supervisório** | **[http://localhost:1880/ui](http://localhost:1880/ui)** | Painel operacional do operador (manômetro, seletores manuais, cronômetro e status) |
| **Editor Node-RED** | **[http://localhost:1880](http://localhost:1880)** | Fluxos lógicos de comunicação e automação |
| **Grafana** | **[http://localhost:3000](http://localhost:3000)** | Painéis analíticos (*user: admin / pass: admin*) |
| **InfluxDB 2.7** | **[http://localhost:8086](http://localhost:8086)** | Banco de séries temporais |
| **Pasta de Relatórios** | **`C:\aplicacoes\clp_iot\relatorios`** | Laudos PDF individuais gerados por ensaio |

---

## 4. Mapeamento de Tags CIP (Micro850)

Comunicação via EtherNet/IP CIP nativo no endpoint `192.168.1.33:44818` (Slot 0):

| Tag no CLP | Tipo | Direção | Função no Sistema |
| :--- | :--- | :--- | :--- |
| `RETORNO_BAR` | `REAL` | Entrada (Read) | Pressão em tempo real lida pelo transmissor analógico (0 a 10 bar). |
| `_IO_EM_DO_00` | `BOOL` | Entrada (Read) | Feedback elétrico da saída digital física da válvula solenoide. |
| `_IO_EM_DO_01` | `BOOL` | Entrada (Read) | Feedback elétrico da saída digital física do motor/bomba hidráulica. |
| `COMPARACAO` | `BOOL` | Entrada (Read) | Flag lógica do CLP indicando pressão igual ou superior ao setpoint (`RETORNO_BAR >= setpoint_node`). |
| `setpoint_node` | `REAL` | Bidirecional | Pressão desejada de teste (0 a 10 bar, passo 0,5 bar). |
| `on_node` | `BOOL` | Saída (Write) | Comando remoto de ligar motor/bomba hidráulica. |
| `off_node` | `BOOL` | Saída (Write) | Comando remoto de desligar motor/bomba hidráulica (e pulso de `400 ms` ao liberar manual). |
| `onval_node` | `BOOL` | Saída (Write) | Comando remoto de abertura da válvula solenoide. |
| `offval_node` | `BOOL` | Saída (Write) | Comando remoto de fechamento da válvula solenoide (e pulso de `400 ms` ao liberar manual). |
| `ciclo_node` | `BOOL` | Saída (Write) | Sinaliza ciclo de teste hidrostático em andamento (`true`) ou finalizado (`false`). |

---

## 5. Destaques Técnicos de Engenharia
- **Intertravamento de Segurança:** Bloqueio de início caso motor esteja ligado, válvula aberta, sem setpoint ou sem identificação de equipamento.
- **Bloqueio Seletivo de UI:** Impede intervenções operacionais acidentais durante a realização do ensaio hidrostático.
- **Shim de Compatibilidade Micro800:** Comunicação direta com o Message Router do controlador sem overhead de backplane modular.
- **Laudos PDF com Chromium Headless:** Layout A4 com curva vetorial SVG, marcação visual de pontos de conformidade/falha, tabela estatística e assinatura técnica.

# 🪟 Scripts de Operação e Manutenção - Windows

Este diretório contém os scripts de automação, ciclo de vida e manutenção do sistema SCADA / IoT para ambiente **Windows 10/11** (executando via Docker Desktop com backend WSL2 em ambiente 100% offline).

---

## 📋 Sumário dos Scripts

| Arquivo | Descrição | Como Executar |
| :--- | :--- | :--- |
| **`iniciar-sistema.bat`** | Script mestre de inicialização. Garante caminhos corretos e executa o `setup-windows.ps1`. | Duplo clique ou via atalho na Área de Trabalho. |
| **`parar-sistema.bat`** | Desliga ordenadamente todos os contêineres Docker (`nodered`, `influxdb`, `grafana`). | Duplo clique ou via atalho na Área de Trabalho. |
| **`setup-windows.ps1`** | Rotina inteligente em PowerShell com diagnóstico de rede, CLP, credenciais e contêineres. | Chamado automaticamente pelo `iniciar-sistema.bat`. |
| **`exportar-imagens-offline.bat`** | Empacota as imagens Docker locais em um arquivo `imagens-offline.tar`. | Duplo clique quando precisar transferir para outra bancada sem internet. |
| **`enviar-github.bat`** | Sincroniza e envia novos commits locais para o repositório remoto no GitHub. | Duplo clique quando conectado à internet e desejar versionar alterações. |

---

## 🔍 Detalhamento Técnico de Cada Script

### 1. `iniciar-sistema.bat`
* **Função:** Ponto de entrada amigável para o operador ou técnico de bancada.
* **Comportamento:**
  1. Define a raiz do projeto (`C:\aplicacoes\clp_iot`).
  2. Ajusta o diretório de trabalho corrente.
  3. Invoca o PowerShell ignorando restrições de política de execução (`-ExecutionPolicy Bypass`).
  4. Mantém a janela aberta após a conclusão para leitura dos links e mensagens de status.

### 2. `parar-sistema.bat`
* **Função:** Finalização segura e ordenada do ambiente.
* **Comportamento:**
  1. Navega até a raiz do projeto.
  2. Executa `docker compose -f docker-compose.windows.yml down`.
  3. Desmonta volumes e remove a rede virtual interna de forma limpa, evitando corrupção nas bases de dados do InfluxDB e Grafana.

### 3. `setup-windows.ps1`
* **Função:** Script de provisionamento e validação pré-voo automatizado.
* **Etapas executadas sequencialmente:**
  1. **Arquivo de Ambiente (`.env`):** Verifica se `.env` existe; caso contrário, copia a partir de `.env.example`.
  2. **Token InfluxDB / Node-RED:** Injeta automaticamente o token administrativo em `nodered_data/flows_cred.json`, eliminando erros de autenticação no supervisório.
  3. **Diretórios Locais:** Cria pastas necessárias caso ainda não existam (`relatorios`, `nodered_data`, `grafana_data`, `influxdb_data`, `influxdb_config`).
  4. **Diagnóstico da Placa Ethernet:** Localiza adaptadores de rede físicos ativos, verifica se o IP está na faixa `192.168.1.x` e executa um teste de ping pontual no CLP Allen-Bradley Micro850 (`192.168.1.33`).
  5. **Verificação do Docker Desktop:** Testa se a engine Docker está respondendo. Se estiver fechada, tenta inicializar o executável do Docker Desktop e aguarda até estar pronto.
  6. **Importação Offline:** Se encontrar arquivos `.tar` no diretório raiz, carrega-os com `docker load`.
  7. **Subida dos Serviços:** Inicia os contêineres via `docker compose -f docker-compose.windows.yml up -d`. Se a imagem local do Node-RED já existir, não faz chamadas externas (100% offline).
  8. **Exibição dos Endereços de Acesso:** Exibe os links de acesso aos painéis locais.

### 4. `exportar-imagens-offline.bat`
* **Função:** Exportação das imagens Docker para implantação em computadores sem acesso à internet (air-gapped).
* **Comportamento:**
  - Gera o arquivo `imagens-offline.tar` contendo:
    - `clp_iot-nodered:latest`
    - `influxdb:2.7`
    - `grafana/grafana:latest`
  - Esse arquivo pode ser copiado para um pendrive e colocado na raiz de qualquer computador novo. Ao rodar `iniciar-sistema.bat`, as imagens serão importadas automaticamente sem baixar nenhum byte da internet.

### 5. `enviar-github.bat`
* **Função:** Facilita a sincronização com o repositório remoto `https://github.com/DriihJose/clp_iot`.
* **Comportamento:**
  - Executa `git push origin main`.
  - Orienta o usuário caso o Git Credential Manager requisite autenticação no navegador.

---

## 🛠️ Resolução de Problemas Frequentes (Troubleshooting)

### A. "Porta já em uso" (1880, 8086 ou 3000)
- **Causa:** Outra instância ou serviço está usando a porta.
- **Solução:** Execute `parar-sistema.bat`. Se persistir, verifique processos locais:
  ```powershell
  Get-Process -Id (Get-NetTCPConnection -LocalPort 1880).OwningProcess
  ```

### B. "CLP 192.168.1.33 ainda não respondeu ao ping"
- **Causa:** Cabo de rede desconectado, CLP desligado ou IP do computador fora da sub-rede.
- **Solução:**
  1. Verifique se o cabo Ethernet está firme na porta do Micro850 e na placa do computador.
  2. Configure o IP da placa Ethernet do Windows como estático:
     - **IP:** `192.168.1.100` (ou `192.168.1.200`)
     - **Máscara:** `255.255.255.0`
     - **Gateway:** (deixe em branco)

### C. Docker não inicia
- Abra o Docker Desktop manualmente pelo menu Iniciar e aguarde o ícone da baleia parar de piscar antes de executar `iniciar-sistema.bat`.

---

## 🔗 Atalhos Criados na Área de Trabalho
- **`Iniciar SCADA`**: Inicia o sistema rapidamente.
- **`Parar SCADA`**: Finaliza todos os contêineres com segurança.
- **`Relatórios SCADA`**: Acesso direto à pasta onde os PDFs e HTMLs dos testes finalizados são salvos.

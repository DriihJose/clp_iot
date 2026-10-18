# 🐧 Scripts de Operação e Manutenção - Linux

Este diretório contém os scripts de automação, ciclo de vida e configuração de rede para o sistema SCADA / IoT em distribuições **Linux (Ubuntu / Debian / Debian Industrial)**.

---

## 📋 Sumário dos Scripts

| Arquivo | Descrição | Como Executar |
| :--- | :--- | :--- |
| **`iniciar-sistema.sh`** | Atalho rápido para executar o `setup-linux.sh`. | `./iniciar-sistema.sh` ou `bash iniciar-sistema.sh` |
| **`parar-sistema.sh`** | Para todos os contêineres e limpa a stack via `docker compose down`. | `./parar-sistema.sh` ou `bash parar-sistema.sh` |
| **`setup-linux.sh`** | Script mestre de validação, permissões, rede industrial e subida do Docker. | `./setup-linux.sh` |

---

## 🔍 Detalhamento Técnico de Cada Script

### 1. `iniciar-sistema.sh`
* **Função:** Facilita o início rápido da aplicação no terminal.
* **Comportamento:**
  - Localiza a pasta do projeto.
  - Chama `bash setup-linux.sh`.

### 2. `parar-sistema.sh`
* **Função:** Finalização segura dos contêineres Docker no Linux.
* **Comportamento:**
  - Navega até a raiz do projeto (`clp_iot`).
  - Executa `docker compose down`.
  - Garante o encerramento seguro dos processos antes de desligar o computador.

### 3. `setup-linux.sh`
* **Função:** Configuração integral do ambiente Linux industrial.
* **Etapas executadas sequencialmente:**
  1. **Arquivo de Ambiente (`.env`):** Cria a partir de `.env.example` se não existir.
  2. **Permissões de Diretórios:**
     - `nodered_data` e `relatorios`: pertencentes ao UID `1000:1000` (usuário padrão do contêiner Node-RED).
     - `grafana_data`: pertencente ao UID `472:472` (usuário padrão do Grafana).
     - Evita erros comuns de *Permission Denied* ao criar relatórios ou gravar fluxos.
  3. **Configuração de Rede via NetworkManager (`nmcli`):**
     - Identifica a placa de rede cabeada física (ex: `enp58s0` ou perfil Ethernet).
     - Configura o IP estático `192.168.1.100/24` sem gateway padrão e com `never-default yes` (evita conflitos de rota de internet).
  4. **Teste de Ping ao CLP:**
     - Dispara pacotes ICMP para `192.168.1.33` (Micro850) para verificar se a bancada está comunicável.
  5. **Carga Offline de Imagens:**
     - Se houver arquivos `*.tar` na raiz, carrega-os no Docker local com `docker load`.
  6. **Inicialização do Docker Compose:**
     - No Linux, o Node-RED roda em `network_mode: host` para comunicação direta na camada 2/3 com a interface física Ethernet, garantindo máxima performance e baixíssima latência na leitura de tags CIP / Ethernet/IP.

---

## ⚙️ Permissões de Execução

Antes de executar pela primeira vez em um novo computador Linux, garanta permissão de execução nos scripts:

```bash
chmod +x scripts/linux/*.sh
```

---

## 🛠️ Resolução de Problemas Frequentes (Linux)

### A. "Permission denied" ao executar comandos Docker
- Certifique-se de que seu usuário pertence ao grupo `docker`:
  ```bash
  sudo usermod -aG docker $USER
  newgrp docker
  ```

### B. Interface cabeada não recebe o IP estático
- Verifique o nome da interface com `ip addr show` e ajuste o perfil:
  ```bash
  sudo nmcli con mod "Conexao cabeada 1" ipv4.addresses 192.168.1.100/24 ipv4.method manual
  sudo nmcli con up "Conexao cabeada 1"
  ```
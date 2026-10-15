# Relatório Técnico de Desenvolvimento: Sistema SCADA/IoT de Bancada
**Projeto:** Testes de Pressão Hidrostática (Detecto / Vigor Alimentos)  
**Controlador:** Allen-Bradley Micro850 (2080-L50E-48QBB)  
**Ambiente:** Ubuntu Desktop / Docker Compose  
**Data:** 14 de Outubro de 2026  

---

## 1. Visão Geral da Arquitetura

O sistema consiste em uma bancada de ensaios hidrostáticos automatizada, orquestrada via Docker Compose, com comunicação direta em rede industrial Ethernet com o CLP Rockwell Micro850.

```
+---------------------------------------------------------------------------------+
|                                 UBUNTU DESKTOP                                  |
|                                                                                 |
|  +--------------------+        +--------------------+      +-----------------+  |
|  |     Node-RED       | (HTTP) |      InfluxDB      | Flux |     Grafana     |  |
|  | (network_mode:host)|------->|      (v2.7.12)     |<-----|   (Porta 3000)  |  |
|  | (Porta 1880 /ui)   |        |    (Porta 8086)    |      +-----------------+  |
|  +---------+----------+        +--------------------+                           |
|            | (EtherNet/IP CIP Nativo - Porta 44818)                             |
+------------|--------------------------------------------------------------------+
             | Placa Física: enp58s0 (IP 192.168.1.100/24 - sem gateway)
             v
+---------------------------------------------------+
|     CLP Allen-Bradley Micro850 (2080-L50E)        |
|     IP: 192.168.1.33 | Modo: RUN | Slot: 0        |
+---------------------------------------------------+
```

### Componentes de Software:
* **Node-RED (`latest`):** IHM Supervisória (`/ui`), cliente de comunicação EtherNet/IP CIP e gerador de relatórios.
* **InfluxDB (`2.7`):** Banco de séries temporais. Organização: `vigor`, Bucket: `carrinho`.
* **Grafana (`latest`):** Dashboards analíticos e gráficos de pressão alimentados via Flux.

---

## 2. O Que Deu Errado: Problemas e Causas Raiz

Durante o desenvolvimento e comissionamento da bancada, foram identificados 5 problemas críticos:

### ❌ Problema 1: Conflito de Rota Padrão e Gateway Falso no Linux
* **Sintoma:** O comando `ping 192.168.1.33` falhava intermitentemente com mensagens como `Time to live exceeded` ou os pacotes tentavam sair pela conexão de internet (Wi-Fi).
* **Causa Raiz:** Para forçar o NetworkManager a salvar o IP estático na placa `enp58s0`, havia sido preenchido um gateway fictício (`192.168.1.1`). O Linux criava duas rotas default conflitantes com métricas concorrentes.

### ❌ Problema 2: Falha do NAT Docker com o CLP Micro850 (`EHOSTUNREACH`)
* **Sintoma:** Node-RED rodando na rede bridge padrão do Docker (`iot-network`) retornava `EHOSTUNREACH 192.168.1.33:44818` e `Socket Transmission Failure`.
* **Causa Raiz:** A linha Micro800 não possui pilha de rede para multi-hop avançado nem suporta travessia complexa de NAT industrial. O mascaramento de rede da bridge do Docker degradava e bloqueava as conexões.

### ❌ Problema 3: Incidente de Exclusão de Arquivos do Projeto (15:52)
* **Sintoma:** O arquivo `docker-compose.yml`, os fluxos `flows.json`, credenciais e módulos de nós foram apagados no host. O InfluxDB subiu desconfigurado (banco zerado).
* **Causa Raiz:** Exclusão acidental direta no disco (bypassando a lixeira para grande parte dos dados). 

### ❌ Problema 4: Incompatibilidade CIP da Linha Micro800 com Drivers Logix Padrão
* **Sintoma:** Mesmo com a rede física corrigida e porta 44818 acessível, o Node-RED retornava:
  ```
  [eth-ip endpoint] Error connecting to PLC: Error: TIMEOUT occurred while reading Controller Props.
  ```
* **Causa Raiz:** O pacote `node-red-contrib-cip-ethernet-ip` utiliza por baixo a biblioteca `ethernet-ip` (desenvolvida originalmente para ControlLogix/CompactLogix). ControlLogix utilizam rack com backplane físico (Porta 1, Slot X) e empacotam **todas** as mensagens em pacotes `Unconnected Send` com cabeçalho de roteamento. O Micro850 é um CLP compacto (*brick*), sem backplane e sem chassi modular; quando recebe uma requisição com rota de backplane, ele simplesmente ignora e descarta o pacote, gerando TIMEOUT de 10 segundos.

### ❌ Problema 5: Erro de Permissão ao Utilizar o Git
* **Sintoma:** Ao rodar `git add -A -- .`, o Git abortava com erro fatal:
  ```
  error: open("grafana_data/grafana.db"): Permission denied
  fatal: adding files failed
  ```
* **Causa Raiz:** As pastas de dados do Grafana e InfluxDB pertencem a usuários e grupos internos de contêineres (`UID 472` no Grafana). Além disso, bancos binários e senhas/tokens não devem ser salvos em repositórios de código.

---

## 3. O Que Deu Certo: Soluções e Implementações

###  Solução 1: Isolamento de Rede Físico com `nmcli`
A placa de rede cabeada foi reconfigurada para trabalhar estritamente como link local para o barramento do CLP, sem tentar ser saída para a internet:
```bash
nmcli con modify "Perfil 1" \
  ipv4.method manual \
  ipv4.addresses 192.168.1.100/24 \
  ipv4.gateway "" \
  ipv4.never-default yes \
  ipv4.route-metric 100 \
  connection.autoconnect yes

# Desativação do perfil dinâmico concorrente
nmcli con modify netplan-enp58s0 connection.autoconnect no
nmcli con up "Perfil 1"
```
* **Resultado:** Conexão direta estabelecida com o CLP em `0,3 ms` de latência média e porta 44818 aberta.

###  Solução 2: Adoção do `network_mode: host` no Node-RED
No [docker-compose.yml](file:///home/mec/clp_iot/docker-compose.yml), removemos o NAT para o Node-RED:
```yaml
services:
  nodered:
    image: nodered/node-red:latest
    container_name: nodered
    network_mode: host
    volumes:
      - ./nodered_data:/data
    restart: unless-stopped
```
* **Resultado:** O Node-RED passou a operar na mesma camada L2/L3 da placa física `enp58s0`, comunicando-se com o IP `192.168.1.33` como se fosse um processo nativo do Linux, acessando o InfluxDB via `http://localhost:8086`.

###  Solução 3: Recuperação de Dados e Reestruturação do InfluxDB
* O fluxo completo de 39 nós foi recuperado diretamente da memória ativa do processo do Node-RED via API `/flows` antes de reiniciar o contêiner.
* O `docker-compose.yml` foi reconstituído a partir de objetos do Git.
* O InfluxDB 2.7 foi reinicializado com segurança:
  * Organização: `vigor` | Bucket: `carrinho`.
  * Criação de tokens dedicados com permissões restritas (token RW para o Node-RED e token Read-Only para o Grafana).

###  Solução 4: O "Shim" de Compatibilidade Micro800 no `settings.js`
Para solucionar o erro de TIMEOUT de Controller Props sem precisar trocar de biblioteca, injetamos um interceptor no carregamento do [settings.js](file:///home/mec/clp_iot/nodered_data/settings.js):
```javascript
/*******************************************************************************
 * Micro800 (Micro850 2080-L50E @ 192.168.1.33) compatibility shim
 * Bypassa o roteamento de backplane e envia direto ao Message Router (CIP nativo)
 ******************************************************************************/
try {
    const { Controller } = require("/data/node_modules/ethernet-ip");
    const ENIP = Object.getPrototypeOf(Controller.prototype);
    Controller.prototype.write_cip = function (data, connected = false, timeout = 10, cb = null) {
        ENIP.write_cip.call(this, data, connected, timeout, cb);
    };
    console.log("[micro800-shim] ethernet-ip patched: direct Message Router (no backplane route)");
} catch (e) {
    console.warn("[micro800-shim] not applied:", e.message);
}
```
* **Impacto:** O tempo de resposta caiu de **10.000 ms (TIMEOUT)** para **4 ms**. Leitura instantânea e contínua de todas as tags simbólicas do CLP.

###  Solução 5: Criação do [.gitignore](file:///home/mec/clp_iot/.gitignore) Robusto
Criamos regras estritas para garantir que o versionamento contenha apenas código reproduzível:
* Ignora `grafana_data/` e `influxdb_data/` (evita conflitos de UID e protege os bancos).
* Ignora `influxdb_config/` (protege senhas e tokens).
* Ignora `nodered_data/node_modules/` e arquivos de credenciais cifradas.

###  Solução 6: Redesenho do Supervisório no Node-RED Dashboard (`/ui`)
A interface foi remodelada com foco operacional e ergonomia visual:
* **Grid de 12 colunas:** Todos os elementos distribuídos em múltiplos de 12 para alinhamento simétrico.
* **Chaves Manuais (`ui_switch`):** Substituição de botões soltos por chaves com indicação animada de status:
  * `MOTOR MANUAL` (largura 6) ➔ Conversão inteligente via nós `change` para acionar `on_node` / `off_node`.
  * `VALVULA MANUAL` (largura 6) ➔ Aciona `onval_node` / `offval_node`.
* **Sinalização Visual de Ciclo:**
  * Inclusão do nó `ui_led` (`TESTE RODANDO`), com transição vermelho (parado) e verde (em teste).
  * Botões `INICIAR TESTE` e `FINALIZAR TESTE` alinhados com o LED em 4 + 4 + 4 = 12 colunas.
* **Manômetro de Pressão (`ui_gauge`):** Reescalonado para `12 x 6`, recebendo a variável real `RETORNO_BAR`.

---

## 4. Mapeamento de Tags CIP (Micro850 <-> Node-RED)

| Tag no CLP | Tipo de Dado | Direção | Descrição no Sistema |
| :--- | :--- | :--- | :--- |
| `RETORNO_BAR` | `REAL` | Entrada (Read) | Leitura de pressão analógica (bar) exibida no Manômetro e salva no InfluxDB. |
| `_IO_EM_DO_00` | `BOOL` | Entrada (Read) | Status físico da saída digital (válvula solenóide principal). |
| `on_node` | `BOOL` | Saída (Write) | Pulso para ligar motor/bomba hidráulica. |
| `off_node` | `BOOL` | Saída (Write) | Pulso para desligar motor/bomba hidráulica. |
| `onval_node` | `BOOL` | Saída (Write) | Comando de abertura da válvula solenóide. |
| `offval_node` | `BOOL` | Saída (Write) | Comando de fechamento da válvula solenóide. |
| `setpoint_node`| `REAL` | Saída (Write) | Ajuste da pressão de teste (3 BAR, 6 BAR, 8 BAR). |
| `ciclo_node` | `BOOL` | Saída (Write) | Flag de controle do ciclo de teste hidrostático. |

---

## 5. Cuidados Essenciais para Operação Offline (Bancada sem Internet)

Se a bancada operar em local isolado sem acesso à internet, atente-se a:

1. **Imagens Docker:** Devem ser exportadas na máquina com internet antes de ir a campo:
   ```bash
   docker save -o imagens_scada.tar nodered/node-red:latest influxdb:2.7 grafana/grafana:latest
   # Na máquina de bancada:
   docker load -i imagens_scada.tar
   ```
2. **Dependências do Node-RED:** Não utilize apenas `git clone` em ambiente offline, pois a pasta `node_modules` não é versionada. Transporte o diretório integral `/home/mec/clp_iot` compactado em pendrive:
   ```bash
   tar -czvf clp_iot_bancada.tar.gz /home/mec/clp_iot
   ```
3. **Subir os serviços:**
   ```bash
   # Sempre use 'up -d' (NÃO use restart):
   docker compose up -d
   ```

---

## 6. URLs e Acessos do Sistema

* **Supervisório do Operador (IHM):** [http://localhost:1880/ui](http://localhost:1880/ui)
* **Engenharia de Fluxos (Node-RED):** [http://localhost:1880](http://localhost:1880)
* **Banco InfluxDB 2.7:** [http://localhost:8086](http://localhost:8086)
* **Painéis Analíticos Grafana:** [http://localhost:3000](http://localhost:3000)

# RESUMO DE EXECUÇÃO #06: CONTROLES DE 3 POSIÇÕES, ZERAMENTO NO SETPOINT, LEITURA FÍSICA DA BOMBA E RESPONSIVIDADE MOBILE

**Data:** 16 de Outubro de 2026  
**Ambiente:** Windows 10/11 (Docker Desktop / WSL2) & Linux (Ubuntu Nativo)  
**Controlador:** Rockwell Micro850 (2080-L50E-48QBB) via EtherNet/IP CIP nativo (`192.168.1.33:44818`)  
**Supervisório:** Node-RED 4.x / Dashboard 3.6.6 (`http://localhost:1880/ui`)  
**Regra de Ouro:** Operação 100% Offline (Air-gapped)

---

## 1. ESCOPO E OBJETIVOS DA INTERVENÇÃO

1. **Auditoria de Alterações Manuais:** Inspecionar e auditar o arquivo `nodered_data/flows.json` comparando via `git diff` as alterações feitas manualmente na IHM (reordenação de componentes e criação do indicador de pressão definida).
2. **Implementação de Controles Manuais de 3 Posições:** Alinhar o acionamento de `MOTOR MANUAL` e `VALVULA MANUAL` com a lógica das Linhas 1 a 9 do diagrama Ladder do CLP Micro850, permitindo ligar, desligar e desengatar/liberar o controle para as botoeiras e seletoras físicas do painel da bancada.
3. **Zeramento Automático de `on_node` no Setpoint:** Evitar que a bomba continue acionada ou religue acidentalmente pela oscilação de pressão na Linha 5/6 do CLP ao atingir o setpoint configurado.
4. **Leitura da Saída Física da Bomba (`_IO_EM_DO_01`):** Adicionar leitura CIP da tag física da bomba e implementar intertravamento estrito de partida antes de autorizar o ensaio hidrostático.
5. **Responsividade Mobile via CSS Isolado:** Implementar ajuste responsivo via `ui_template` restrito estritamente a `@media only screen and (max-width: 768px)`, garantindo visualização perfeita no smartphone sem nenhuma alteração no layout de PC.

---

## 2. AUDITORIA DAS ALTERAÇÕES MANUAIS NO FLUXO (`flows.json`)

A inspeção detalhada via `git diff` identificou:
* Reorganização de posições visuais (`order`) no grupo `ui_group_pressao` para acomodar os botões e seletores manuais.
* Redução de largura do display de tempo restante (`82d8edb1336a7da3`) de 12 para 6 colunas.
* Adição de novo nó `ui_text` (`9c879e7c29e0e8de`), rotulado como `"Pressão definida do teste:"`, recebendo o valor do setpoint digitado na tela (`c27f650072a158be`).
* **Conclusão da Auditoria:** Nenhuma variável de contexto essencial (`flow.*`), gravação no InfluxDB 2.7 ou rotina de geração de relatórios PDF com Chromium headless foi danificada.

---

## 3. IMPLEMENTAÇÕES DE ENGENHARIA REALIZADAS

### 3.1 Alinhamento com o Diagrama Ladder do Micro850 (Linhas 1 a 9)
No programa Ladder do controlador:
* **Linha 1:** `RETORNO_BAR >= setpoint_node` aciona `COMPARACAO`.
* **Linhas 2 e 3:** Botoeiras físicas `_IO_EM_DI_02` (Liga) e `_IO_EM_DI_01` (Desliga NF) acionam Set (S) e Reset (R) de `BOMBA_MANUAL`. `bar_auto`, `COMPARACAO` e `ciclo_node` também acionam Reset (R) de `BOMBA_MANUAL`.
* **Linhas 5 e 6:** `on_node` aciona Set (S) de `bar_auto`; `off_node`, `COMPARACAO` e `ciclo_node` acionam Reset (R) de `bar_auto`.
* **Linha 7:** `BOMBA_MANUAL` ou `bar_auto` acionam a saída física digital `_IO_EM_DO_01` (`BOMBA`).
* **Linhas 8 e 9:** Seletora física `_IO_EM_DI_03` ou `onval_node` acionam Set (S) de `_IO_EM_DO_00` (`VALVULA`); Seletora física `_IO_EM_DI_04`, `offval_node` ou `bar_auto` acionam Reset (R) de `_IO_EM_DO_00` (`VALVULA`).

### 3.2 Controles de 3 Posições na Interface (/ui)
Os switches binários anteriores prendiam as variáveis em `true` ou `false`, bloqueando a intervenção das botoeiras locais do painel elétrico. Foram substituídos por seletores de 3 posições (`ui_dropdown`) de largura 6 colunas cada:

1. **`MOTOR MANUAL` (`9641c0e83444adc3`):**
   * **1 - MOTOR LIGADO:** Envia `on_node = true` e `off_node = false`. Define `flow.set('motor_on', true)`.
   * **2 - MOTOR DESLIGADO:** Envia `on_node = false` e `off_node = true`. Define `flow.set('motor_on', false)`.
   * **3 - LIBERAR MANUAL:** Envia `on_node = false` e `off_node = false`, liberando o comando para as botoeiras físicas `_IO_EM_DI_02` / `_IO_EM_DI_01`. Define `flow.set('motor_on', false)`.

2. **`VALVULA MANUAL` (`f20962dfb01ffb40`):**
   * **1 - VÁLVULA ABERTA:** Envia `onval_node = true` e `offval_node = false`. Define `flow.set('valvula_manual_on', true)`.
   * **2 - VÁLVULA FECHADA:** Envia `onval_node = false` e `offval_node = true`. Define `flow.set('valvula_manual_on', false)`.
   * **3 - LIBERAR MANUAL:** Envia `onval_node = false` e `offval_node = false`, liberando o comando para as seletoras físicas `_IO_EM_DI_03` / `_IO_EM_DI_04`. Define `flow.set('valvula_manual_on', false)`.

### 3.3 Zeramento Automático de `on_node` ao Atingir o Setpoint
Implementado nó de função `fn_auto_cutoff_sp` conectado à leitura em tempo real de `RETORNO_BAR`:
* Sempre que `flow.get('motor_on') === true` e a pressão atinge ou supera o setpoint configurado (`pressao >= sp`):
  1. Envia imediatamente `{ payload: false }` para `on_node` e para `off_node` no CLP.
  2. Atualiza `flow.set('motor_on', false)`.
  3. Envia `{ payload: 3 }` para o dropdown `MOTOR MANUAL`, atualizando a indicação visual na tela para **"LIBERAR MANUAL"**.
* Além disso, na função de partida e bloqueio (`fn_ui_lock`), ao iniciar o ensaio, ao finalizar e durante o boot inicial, força os 4 comandos manuais (`on_node`, `off_node`, `onval_node`, `offval_node`) para `false` e ambos os seletores para `"LIBERAR MANUAL"`.

### 3.4 Leitura Física da Bomba (`_IO_EM_DO_01`) e Intertravamento Real
1. Tag `_IO_EM_DO_01` adicionada à tabela de variáveis do endpoint CIP (`da562bad96c4eafe`) como tipo `BOOL`.
2. Criado nó `eth-ip in` (`eth_in_bomba`) e nó `fn_cache_bomba` atualizando `flow.bomba_fisica`.
3. Intertravamento no nó `Inicia teste` (`49589c46b3396a0f`) atualizado com 4 validações estritas:
   * **Equipamento preenchido:** Impede início anônimo sem identificação técnica.
   * **Motor desligado:** Exige comando desativado (`flow.motor_on === false`) **E** saída física desligada (`flow.bomba_fisica === false`).
   * **Válvula fechada:** Exige comando fechado (`flow.valvula_manual_on === false`) **E** saída física fechada (`flow.valvula === false` lida via `_IO_EM_DO_00`).
   * **Setpoint válido:** Exige setpoint maior que 0 bar.

### 3.5 Ajuste CSS Responsivo para Celular (Isolado de PC)
Adicionado nó `ui_template` com escopo global injetando folha de estilos restrita:
```css
@media only screen and (max-width: 768px) {
    html, body {
        overflow-x: hidden !important;
        width: 100% !important;
        max-width: 100vw !important;
    }
    md-content.maincontent {
        overflow-x: hidden !important;
        padding: 4px !important;
        width: 100% !important;
        max-width: 100vw !important;
        box-sizing: border-box !important;
    }
    .nr-dashboard-cardpanel {
        max-width: 100vw !important;
        margin: 0 auto !important;
        padding: 4px !important;
        box-sizing: border-box !important;
    }
    @media only screen and (max-width: 650px) {
        .nr-dashboard-cardpanel {
            zoom: calc((100vw - 12px) / 642);
        }
    }
}
```
* **Comportamento em Mobile (< 768px):** O container do dashboard ajusta-se à largura da tela do smartphone conectado via Wi-Fi ao roteador da bancada, com redimensionamento proporcional e sem barra de rolagem horizontal indesejada.
* **Comportamento em Computador (>= 769px):** Regra não aplicada; layout 100% idêntico ao original de bancada.

---

## 4. MAPEAMENTO DE TAGS CIP VALIDADO NO MICRO850

| Tag no CLP | Tipo | Sentido | Função no Sistema | Status em Bancada |
| :--- | :---: | :---: | :--- | :---: |
| `RETORNO_BAR` | REAL | CLP -> Node-RED | Leitura da pressão analógica instantânea | Operacional (6.25 bar) |
| `_IO_EM_DO_00` | BOOL | CLP -> Node-RED | Feedback físico da Válvula solenoide | Operacional (`false`) |
| `_IO_EM_DO_01` | BOOL | CLP -> Node-RED | Feedback físico da Bomba hidráulica | Operacional (`false`) |
| `setpoint_node` | REAL | Bidirecional | Pressão alvo de ensaio | Operacional (7.0 bar) |
| `on_node` | BOOL | Node-RED -> CLP | Comando Liga Motor (Linha 5 Ladder) | Operacional |
| `off_node` | BOOL | Node-RED -> CLP | Comando Desliga Motor (Linha 6 Ladder) | Operacional |
| `onval_node` | BOOL | Node-RED -> CLP | Comando Abre Válvula (Linha 8 Ladder) | Operacional |
| `offval_node` | BOOL | Node-RED -> CLP | Comando Fecha Válvula (Linha 9 Ladder) | Operacional |
| `ciclo_node` | BOOL | Node-RED -> CLP | Intertravamento de Ensaio Ativo | Operacional |

---

## 5. CONCLUSÃO E APROVAÇÃO

Todas as 4 etapas da solicitação foram implementadas, validadas com o contêiner em execução e com o CLP Micro850 respondendo via rede EtherNet/IP CIP. O sistema continua 100% autônomo e offline.

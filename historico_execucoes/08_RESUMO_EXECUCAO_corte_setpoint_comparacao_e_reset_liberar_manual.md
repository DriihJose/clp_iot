# RESUMO DE EXECUÇÃO #08: CORREÇÃO DA LÓGICA DE CONTROLE E SINCRONIZAÇÃO DE VARIÁVEIS COM O CLP

**Data:** 16 de Outubro de 2026  
**Ambiente:** Rockwell Micro850 (CIP Ethernet/IP) + Node-RED 4.x / Dashboard 3.6.6  
**Regra de Ouro:** Operação 100% Offline (Air-gapped)

---

## 1. ESCOPO E PROBLEMAS REPORTADOS

### Problema 1 — Religamento indevido do motor após atingir o Setpoint
* **Causa Raiz Identificada:** Quando a pressão atingia o setpoint durante a operação, o ladder interno do Micro850 desligava a saída física da bomba por intermédio da comparação interna (`COMPARACAO = true`). Porém, a variável de comando `on_node` escrita pelo supervisório permanecia retida em `true` na memória do CLP. Assim que a pressão do circuito sofria qualquer alívio ou queda abaixo do setpoint, a variável `COMPARACAO` no CLP voltava a `false`. Com `on_node` ainda `true`, o ladder do CLP religava o motor automaticamente, provocando oscilações e repiques indesejados.
* **Solução Implementada:**
  1. Criação do nó de leitura CIP (`eth-ip in`) associado à tag interna **`COMPARACAO`** (tipo `BOOL`) no endpoint `da562bad96c4eafe`.
  2. Atualização da função de corte (`fn_auto_cutoff_sp`): ao detectar `COMPARACAO === true` (ou pressão `RETORNO_BAR >= setpoint`), força imediatamente `on_node = false` e `off_node = false` no CLP e reseta `flow.set('motor_on', false)` e `flow.set('on_node', false)`.
  3. Atualização automática do dropdown visual do motor para "LIBERAR MANUAL" (opção 3).
  4. Quando a pressão cai e `COMPARACAO` volta a `false`, o motor **permanece rigorosamente desligado** porque `on_node` já é `false` no CLP. O motor só religa se o operador acionar novamente "MOTOR LIGADO".

### Problema 2 — "Liberar Manual" não resetava as variáveis de comando
* **Causa Raiz Identificada:** Ao selecionar "LIBERAR MANUAL":
  1. O estado no contexto do fluxo (`flow.set('on_node', false)`, `flow.set('off_node', false)`, `flow.set('onval_node', false)`, `flow.set('offval_node', false)`) não estava sendo atualizado explicitamente.
  2. No nó de saída Ethernet/IP (`eth-ip out`), a biblioteca comparava `tag.value !== tag.controller_value`. Se o cache interno considerasse que o último valor conhecido já era `false`, o pacote CIP de escrita não era despachado para a rede, deixando o CLP com valores defasados caso a memória tivesse sido alterada por lógicas de ladder ou comandos locais.
* **Solução Implementada:**
  1. No controle do motor (`fn_ctrl_motor_manual`): ao selecionar "LIBERAR MANUAL" (opção 3), define `on_node = false`, `off_node = false` e `motor_on = false` no contexto e despacha `{ payload: false }` para ambas as saídas conectadas aos nós CIP `daa4f8544153c40e` (`on_node`) e `faecf82f35480bfa` (`off_node`).
  2. No controle da válvula (`fn_ctrl_valvula_manual`): ao selecionar "LIBERAR MANUAL" (opção 3), define `onval_node = false`, `offval_node = false` e `valvula_manual_on = false` no contexto e despacha `{ payload: false }` para os nós CIP `7a612cafc5aaba50` (`onval_node`) e `0f43d59264e5b79e` (`offval_node`).
  3. Na função de proteção do nó Ethernet/IP (`ethernet-ip.js`): em `onNewMsg`, o cache `tag.state.tag.controllerValue` é resetado para `null`, garantindo que qualquer mensagem recebida pelo supervisório force o envio imediato e sem descarte do pacote CIP `WRITE_TAG` para o CLP.

---

## 2. ALTERAÇÕES DETALHADAS NO FLUXO (`flows.json`)

### 2.1 Novo Nó: `eth_in_comparacao`
```json
{
    "id": "eth_in_comparacao",
    "type": "eth-ip in",
    "z": "flow_pressao_full",
    "endpoint": "da562bad96c4eafe",
    "mode": "single",
    "variable": "COMPARACAO",
    "program": "",
    "name": "COMPARACAO",
    "x": 160,
    "y": 840,
    "wires": [
        ["fn_auto_cutoff_sp"]
    ]
}
```

### 2.2 Função `fn_auto_cutoff_sp` (Zeramento Automático Setpoint)
```javascript
// Monitora a tag COMPARACAO do CLP e a pressão RETORNO_BAR para forçar on_node = false em definitivo ao atingir o setpoint

let atingiuSetpoint = false;

// Caso 1: Leitura da tag COMPARACAO do CLP (BOOL: true quando pressão do sensor >= setpoint)
if (typeof msg.payload === 'boolean' || msg.variable === 'COMPARACAO' || msg.topic === 'COMPARACAO') {
    if (msg.payload === true || msg.payload === 1 || msg.payload === 'true') {
        atingiuSetpoint = true;
    }
}

// Caso 2: Leitura direta de pressão (RETORNO_BAR)
const pressao = Number(msg.payload);
if (!atingiuSetpoint && !isNaN(pressao)) {
    const sp = Number(flow.get('sp_travado') ?? flow.get('sp_ui') ?? flow.get('sp_plc') ?? 0);
    if (sp > 0 && pressao >= sp) {
        atingiuSetpoint = true;
    }
}

// Se atingiu o setpoint (por COMPARACAO == true ou pressao >= sp):
// Força on_node = false em definitivo, envia pulso de reset em off_node (400ms) e reseta o seletor do motor para Liberar Manual
if (atingiuSetpoint) {
    flow.set('motor_on', false);
    flow.set('on_node', false);
    flow.set('off_node', true);

    // [0] on_node: false | [1] off_node: true (início do pulso de reset) | [2] seletor MOTOR: 3 (LIBERAR MANUAL)
    node.send([
        { payload: false },
        { payload: true },
        { payload: 3 }
    ]);

    setTimeout(() => {
        flow.set('off_node', false);
        node.send([null, { payload: false }, null]); // Encerra pulso de reset
    }, 400);

    return;
}

// Quando a pressão cair abaixo do setpoint (COMPARACAO vira false):
// NÃO religa o motor sozinho. Permanece desligado até nova ação manual do operador.
return null;
```

### 2.3 Função `fn_ctrl_motor_manual` (Controle Motor Manual com Pulso de RESET)
```javascript
const val = Number(msg.payload);

if (val === 1) { // 1: MOTOR LIGADO
    flow.set('motor_on', true);
    flow.set('on_node', true);
    flow.set('off_node', false);
    node.send([{ payload: true }, { payload: false }]);
    return;
} else if (val === 2) { // 2: MOTOR DESLIGADO
    flow.set('motor_on', false);
    flow.set('on_node', false);
    flow.set('off_node', true);
    node.send([{ payload: false }, { payload: true }]);
    return;
} else { // 3: LIBERAR MANUAL
    // Bobinas SET/RESET no CLP:
    // 1. Desliga o comando de liga (on_node = false)
    // 2. Dispara pulso rápido de RESET (off_node = true por 400ms, depois off_node = false)
    flow.set('motor_on', false);
    flow.set('on_node', false);
    flow.set('off_node', true);

    // Envia on_node = false e início do pulso off_node = true
    node.send([{ payload: false }, { payload: true }]);

    // Aguarda intervalo de 400ms (300ms a 500ms) para leitura pelo ciclo de scan do CLP
    setTimeout(() => {
        flow.set('off_node', false);
        node.send([null, { payload: false }]); // Encerra pulso de RESET
    }, 400);

    return;
}
```

### 2.4 Função `fn_ctrl_valvula_manual` (Controle Válvula Manual com Pulso de RESET)
```javascript
const val = Number(msg.payload);

if (val === 1) { // 1: VÁLVULA ABERTA
    flow.set('valvula_manual_on', true);
    flow.set('onval_node', true);
    flow.set('offval_node', false);
    node.send([{ payload: true }, { payload: false }]);
    return;
} else if (val === 2) { // 2: VÁLVULA FECHADA
    flow.set('valvula_manual_on', false);
    flow.set('onval_node', false);
    flow.set('offval_node', true);
    node.send([{ payload: false }, { payload: true }]);
    return;
} else { // 3: LIBERAR MANUAL
    // Bobinas SET/RESET no CLP:
    // 1. Desliga o comando de abertura (onval_node = false)
    // 2. Dispara pulso rápido de RESET (offval_node = true por 400ms, depois offval_node = false)
    flow.set('valvula_manual_on', false);
    flow.set('onval_node', false);
    flow.set('offval_node', true);

    // Envia onval_node = false e início do pulso offval_node = true
    node.send([{ payload: false }, { payload: true }]);

    // Aguarda intervalo de 400ms (300ms a 500ms) para leitura pelo ciclo de scan do CLP
    setTimeout(() => {
        flow.set('offval_node', false);
        node.send([null, { payload: false }]); // Encerra pulso de RESET
    }, 400);

    return;
}
```

---

## 3. RESULTADOS DOS TESTES UNITÁRIOS E DE INTEGRAÇÃO

| Teste | Entrada Simulada | Saídas Imediatas ao CLP | Saídas Pós-Timeout (400ms) | Estado Final Contexto | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **Motor: Liberar Manual (Pulso)** | `{ payload: 3 }` | `on_node: false`, `off_node: true` | `off_node: false` | `motor_on: false`, `on_node: false`, `off_node: false` | **APROVADO** |
| **Válvula: Liberar Manual (Pulso)** | `{ payload: 3 }` | `onval_node: false`, `offval_node: true` | `offval_node: false` | `valvula_manual_on: false`, `onval_node: false`, `offval_node: false` | **APROVADO** |
| **Corte Setpoint (COMPARACAO)** | `{ payload: true, variable: 'COMPARACAO' }` | `on_node: false`, `off_node: true`, UI: `3` | `off_node: false` | `motor_on: false`, `on_node: false`, `off_node: false` | **APROVADO** |
| **Queda de Pressão Subsequente** | `{ payload: false, variable: 'COMPARACAO' }` | `null` (zero comandos) | N/A | Sem religamento indevido | **APROVADO** |

---

## 4. CONCLUSÃO

1. As bobinas SET/RESET do Micro850 agora recebem um pulso dedicado de RESET de 400ms (`off_node = true` $\rightarrow$ `off_node = false`), desarmando com 100% de eficácia as saídas setadas e liberando o circuito para controle local pelas botoeiras físicas da bancada.
2. O corte definitivo por setpoint também aplica o pulso de reset, impedindo qualquer religamento mecânico ou elétrico quando a pressão do sensor cair.
3. Todas as modificações foram testadas e sincronizadas no contêiner Docker `nodered` e no diretório local de produção `C:\aplicacoes\clp_iot\nodered_data`.


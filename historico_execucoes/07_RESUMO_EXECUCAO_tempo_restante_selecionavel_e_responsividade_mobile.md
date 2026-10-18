# RESUMO DE EXECUÇÃO #07: TEMPO RESTANTE SELECIONÁVEL E CORREÇÃO DEFINITIVA DE RESPONSIVIDADE MOBILE

**Data:** 16 de Outubro de 2026  
**Ambiente:** Windows 10/11 (Docker Desktop / WSL2) & Linux (Ubuntu Nativo)  
**Supervisório:** Node-RED 4.x / Dashboard 3.6.6 (`http://localhost:1880/ui`)  
**Regra de Ouro:** Operação 100% Offline (Air-gapped)

---

## 1. ESCOPO DAS ALTERAÇÕES SOLICITADAS

1. **Tempo Restante Selecionável e Interativo:**
   - Transformar a exibição passiva de tempo restante em um seletor interativo (dropdown + botões de ajuste fino).
   - Intervalos de 5 em 5 minutos, com valor mínimo de 10 minutos e máximo de 60 minutos (10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 min).
   - Atualização imediata do cronômetro e do estado de tempo restante no supervisório e no contexto do fluxo.

2. **Correção Definitiva da Responsividade no Smartphone (Eliminação de Overflow Horizontal):**
   - Identificar a causa raiz do vazamento lateral (barra de rolagem horizontal persistente em celulares).
   - Eliminar larguras fixas, conflitos de posicionamento absoluto do Angular Material e regras CSS inválidas.
   - Garantir que todo o conteúdo fique 100% contido nos limites úteis da tela em qualquer dispositivo móvel (320px a 768px), mantendo o layout de PC (>= 769px) absolutamente intacto.

---

## 2. DIAGNÓSTICO TÉCNICO: CAUSA RAIZ DO OVERFLOW NO MOBILE

Através de instrumentação com Chromium headless executado via Chrome DevTools Protocol (CDP) dentro do contêiner, foram identificados os três fatores que causavam o vazamento de layout:

1. **Regra CSS Inválida Descartada pelo Navegador:**
   A regra anterior continha:
   ```css
   @media only screen and (max-width: 650px) {
       .nr-dashboard-cardpanel {
           zoom: calc((100vw - 12px) / 642);
       }
   }
   ```
   Em CSS, o operador `calc()` com operandos dimensionais (`100vw - 12px`) gera um valor com unidade de comprimento (`px` ou `vw`). A propriedade `zoom` (legada/não-padronizada) aceita apenas números adimensionais ou porcentagens. Como resultado, o analisador CSS dos navegadores móveis (Blink/WebKit) descartava a declaração por erro de sintaxe, fazendo com que o painel permanecesse com 642px de largura.

2. **Posicionamento Absoluto Rígido dos Cards do Angular Material:**
   O script interno `uiCardPanelController` do Node-RED Dashboard injeta atributos inline em cada `<md-card>` filho:
   - Para largura 12: `style="left: 0px; width: 642px; position: absolute;"`
   - Para largura 6: `style="left: 324px; width: 318px; position: absolute;"`
   Mesmo com `max-width` no painel pai, os elementos posicionados em `left: 324px` projetavam-se até `324 + 318 = 642px`, ultrapassando a viewport de 375px em mais de 270px.

3. **SVG Raphaël do Manômetro (JustGage) sem `viewBox`:**
   A biblioteca Raphaël gera o SVG do manômetro utilizando dimensões absolutas herdadas do container pai (547px) sem o atributo `viewBox`, impedindo o redimensionamento vetorial automático.

---

## 3. IMPLEMENTAÇÕES REALIZADAS

### 3.1 Seletor Interativo de Tempo Restante (`82d8edb1336a7da3` & `fn_set_tempo_restante`)

1. **Substituição do nó `ui_text` por `ui_template`:**
   - **Interface:** Contém título "TEMPO RESTANTE", display digital do cronômetro (`MM:SS`), seletor dropdown (`<select>`) com opções de 10 a 60 minutos (passo 5 min) e botões de incremento/decremento rápido `[-]` e `[+]`.
   - **Design System:** Estilizado em total harmonia com a paleta escura da bancada (`#3D3846`), com feedback visual imediato ao clique.
   - **Sincronização em Tempo Real:** Ao alterar o valor (via dropdown ou botões), o cronômetro visual atualiza imediatamente para `MM:00` e emite mensagem `{ payload: minutos }`.

2. **Nó de Função `fn_set_tempo_restante`:**
   - Valida os limites estritos (10 a 60 min, múltiplos de 5).
   - Atualiza `flow.duracao_selecionada`, `flow.duracao_teste` e `flow.tempo_restante`.
   - Se o ensaio já estiver em andamento, recalcula dinamicamente a duração restante proporcional ao tempo decorrido desde `hora_inicio_date`.
   - Retorna confirmação formatada `{ payload: "TEMPO RESTANTE: MM:00", cronometro: "MM:00", minutos: min }` realimentando o seletor.

3. **Adaptação dos Nós de Controle de Ensaio:**
   - **`Decremento de tempo` (`5214bd83dc5b5467`):** Utiliza `flow.get("duracao_selecionada") || flow.get("duracao_teste") || 3600000`, emitindo tanto `payload` compatível quanto `cronometro: "MM:SS"`.
   - **`Inicia teste` (`49589c46b3396a0f`):** Deixa de sobrepor o tempo com valor fixo e preserva o tempo escolhido pelo operador.
   - **`Finaliza _Teste` (`6d54da2809aedd4d`):** Reseta o tempo restante para o valor configurado na sessão atual.

---

### 3.2 Folha de Estilos Responsiva Mobile (`ui_template_mobile_css`)

Adotada solução baseada em CSS Flexbox limpo e robusto, restrita estritamente a `@media only screen and (max-width: 768px)`:

```css
@media only screen and (max-width: 768px) {
    *, *::before, *::after {
        box-sizing: border-box !important;
    }

    html, body, #nr-dashboard {
        width: 100% !important;
        max-width: 100% !important;
        overflow-x: hidden !important;
        margin: 0 !important;
        padding: 0 !important;
        position: relative !important;
        -webkit-overflow-scrolling: touch !important;
    }

    md-toolbar,
    .md-toolbar-tools,
    section[layout="row"],
    md-content,
    md-content.maincontent,
    div[ui-masonry],
    ui-card-panel,
    .nr-dashboard-cardpanel {
        width: 100% !important;
        max-width: 100% !important;
        overflow-x: hidden !important;
        box-sizing: border-box !important;
        margin-left: 0 !important;
        margin-right: 0 !important;
        padding-left: 4px !important;
        padding-right: 4px !important;
    }

    .nr-dashboard-cardcontainer {
        display: flex !important;
        flex-wrap: wrap !important;
        justify-content: space-between !important;
        align-items: stretch !important;
        width: 100% !important;
        max-width: 100% !important;
        min-width: 0 !important;
        height: auto !important;
        position: relative !important;
        margin: 0 auto !important;
        padding: 4px 0 !important;
        gap: 8px !important;
        box-sizing: border-box !important;
        overflow-x: hidden !important;
    }

    /* Neutralização do posicionamento absoluto rígido do Angular Material */
    .nr-dashboard-cardcontainer > md-card {
        position: relative !important;
        left: auto !important;
        top: auto !important;
        right: auto !important;
        bottom: auto !important;
        width: 100% !important;
        max-width: 100% !important;
        min-width: 0 !important;
        height: auto !important;
        min-height: 48px !important;
        margin: 0 !important;
        box-sizing: border-box !important;
        overflow: hidden !important;
        flex: 1 1 100% !important;
    }

    @media only screen and (min-width: 481px) and (max-width: 768px) {
        .nr-dashboard-cardcontainer > md-card[ui-card-size^="6x"] {
            width: calc(50% - 4px) !important;
            flex: 1 1 calc(50% - 4px) !important;
            max-width: calc(50% - 4px) !important;
        }
    }

    .nr-dashboard-gauge,
    div[id^="gauge_"] {
        max-width: 100% !important;
        width: 100% !important;
        height: auto !important;
        box-sizing: border-box !important;
        overflow: hidden !important;
    }

    .nr-dashboard-gauge svg {
        max-width: 100% !important;
        width: 100% !important;
        height: auto !important;
        display: block !important;
        margin: 0 auto !important;
        overflow: hidden !important;
    }
}
```

**Adaptador Dinâmico do Manômetro Raphaël (Cálculo Inteligente via BBox):**
Para garantir centralização absoluta e evitar assimetrias vetoriais entre diferentes resoluções móveis, foi injetado um script no template que calcula dinamicamente a `viewBox` do SVG com base em `svg.getBBox()`:
```javascript
var bb = svg.getBBox();
var pad = 10;
var newVb = (bb.x - pad) + " " + (bb.y - pad) + " " + (bb.width + pad * 2) + " " + (bb.height + pad * 2);
svg.setAttribute('viewBox', newVb);
svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
```
Esse cálculo enquadra rigorosamente o arco desenhado no centro exato da viewport móvel, enquanto para desktop (`window.innerWidth > 768`) o `viewBox` é removido, mantendo fidelidade de 100% ao layout de bancada.

### 3.3 Renomeação do Manômetro de Pressão
- O nó do manômetro (`id: gauge`) teve sua propriedade `title` atualizada de `"Pressão em Teste"` para `"Pressão do sensor"`.

---

## 4. RESULTADOS DOS TESTES DE VALIDAÇÃO (AUTOMATIZADOS COM CHROMIUM)

### 4.1 Teste do Manômetro de Pressão
* **Título exibido no painel:** `"Pressão do sensor"` (validado via seletor `.nr-dashboard-gauge-title`).
* **Centralização geométrica no celular (375px):**
  - Largura do card do manômetro: 333.00px
  - Largura útil do arco vetorial: 318.44px
  - Espaçamento da margem esquerda (`leftGap`): 7.28px
  - Espaçamento da margem direita (`rightGap`): 7.28px
  - Diferença entre margens: **0.00003px** (`isCentered: true`).

### 4.2 Teste do Seletor de Tempo Restante
* **Valores disponíveis:** 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 minutos (11 opções válidas, sem entradas em branco).
* **Botões de passo:** `[-]` decrementa 5 min (bloqueado em 10); `[+]` incrementa 5 min (bloqueado em 60).
* **Simulação de seleção (25 min):** Display atualizou imediatamente para `25:00` e manteve sincronia perfeita com os pulsos do backend.

### 4.3 Teste Multi-Resolução de Overflow Horizontal

| Largura da Viewport | Largura do Documento (`scrollWidth`) | Barra de Rolagem Horizontal? | Elementos Transbordando | Status |
| :---: | :---: | :---: | :---: | :---: |
| **320px** (iPhone SE/5) | 320px | **NÃO** (`false`) | 0 | **APROVADO** |
| **360px** (Galaxy A / Android) | 360px | **NÃO** (`false`) | 0 | **APROVADO** |
| **375px** (iPhone Mini / Padrão) | 375px | **NÃO** (`false`) | 0 | **APROVADO** |
| **390px** (iPhone 12/13/14/15/16) | 390px | **NÃO** (`false`) | 0 | **APROVADO** |
| **412px** (Pixel / Galaxy S) | 412px | **NÃO** (`false`) | 0 | **APROVADO** |
| **480px** (Mobile Grande) | 480px | **NÃO** (`false`) | 0 | **APROVADO** |
| **600px** (Tablet Pequeno / Fold) | 600px | **NÃO** (`false`) | 0 | **APROVADO** |
| **768px** (iPad / Tablet Médio) | 768px | **NÃO** (`false`) | 0 | **APROVADO** |
| **1280px** (PC Bancada) | 1280px | **NÃO** (`false`) | 0 | **APROVADO (Layout Original)** |

*Evidências fotográficas salvas:*
- `relatorios/validacao_mobile_375.png` (captura da visualização em smartphone)
- `relatorios/validacao_desktop_1280.png` (captura da visualização em computador)

---

## 5. CONCLUSÃO

Todos os requisitos foram atendidos e testados em ambiente real de execução:
1. O título do manômetro foi atualizado para **"Pressão do sensor"**.
2. O arco do manômetro JustGage está matematicamente e visualmente centralizado no celular (diferença entre margens de 0.00003px).
3. O tempo restante agora é totalmente configurável de 10 a 60 minutos em intervalos de 5 minutos, respondendo instantaneamente às interações do usuário.
4. A rolagem horizontal em smartphones foi completamente eliminada, conferindo perfeita usabilidade móvel sem alterar o layout de bancada em computadores.

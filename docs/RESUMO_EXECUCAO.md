# Resumo de Execução - Bancada de Testes de Pressão Hidrostática
**Status do Projeto:** Ativo, Auditado e Homologado em Bancada  
**Versão Atual:** [09 - Gráfico SVG Dinâmico A4 Paisagem, Sincronia Imediata de Setpoint (Shim CIP 4 Camadas) e InfluxDB Windows](historico_execucoes/09_RESUMO_EXECUCAO_grafico_dinamico_sincronia_setpoint_e_influx_windows.md)  
**Data da Última Intervenção:** 30 de Outubro de 2026  
**Documento Mestre de Engenharia:** [DOSSIE_TECNICO_MANUTENCAO.md](DOSSIE_TECNICO_MANUTENCAO.md)  

---

> [!NOTE]  
> **POLÍTICA DE HISTÓRICO PERMANENTE:**  
> Este documento funciona como um **ponteiro central**. Os relatórios técnicos detalhados de cada execução e intervenção são mantidos permanentemente na pasta [`historico_execucoes/`](historico_execucoes/), garantindo rastreabilidade histórica auditável.

---

## 📌 Execução Mais Recente: Versão 09

Para acessar o relatório técnico completo da última intervenção, abra:  
👉 **[historico_execucoes/09_RESUMO_EXECUCAO_grafico_dinamico_sincronia_setpoint_e_influx_windows.md](historico_execucoes/09_RESUMO_EXECUCAO_grafico_dinamico_sincronia_setpoint_e_influx_windows.md)**

### Destaques da Versão 09:
* **Laudo PDF A4 Paisagem de Página Única e Gráfico SVG Dinâmico (`10 a 60 min`):** Escala horizontal adaptativa do eixo X sem repetição de rótulos `HH:mm`, retenção histórica dinâmica (`duracao_travada + 2 min`) e bloqueio multinível (3 camadas) do seletor de tempo durante o ensaio;
* **Eliminação do Atraso de `0,5 bar` no Setpoint e Shim CIP de 4 Camadas:** Remoção do zeramento prematuro de `controllerValue` em `ethernet-ip.js`, despacho forçado via `write_ready` (`stage_write`), supressão de leituras pré-escrita, confirmação pós-escrita com `Math.fround` Float32 em `settings.js` e sincronia bidirecional anti-eco (`1500 ms`) em `fn_cache_setpoint_plc`;
* **Correção do InfluxDB / Grafana no Windows Multiplataforma:** Remoção de `extra_hosts` no serviço `nodered` de `docker-compose.windows.yml`, resolvendo `host.docker.internal:8086` diretamente pelo alias DNS da `iot-network` (`172.18.0.2`) sem `ETIMEDOUT 192.168.65.254:8086` e mantendo o mesmo `flows.json` para Windows e Linux;
* **Higiene do Fluxo e Sincronização Integral dos Dossiês:** Exclusão da escrita duplicada `PT-010` (`bb3820654f2359db`), desempilhamento do nó `COMPARACAO` para `(160, 620)` e atualização integral dos 16 nós `function` e arquivos de infraestrutura nos Dossiês Técnicos.

---

## 📚 Histórico Completo de Execuções

Consulte o sumário cronológico completo no arquivo:  
👉 **[historico_execucoes/README.md](historico_execucoes/README.md)**

1. [**Execução 01 (14/10/2026):** Comissionamento de Rede, Gateway Linux e Shim CIP Micro800](historico_execucoes/01_RESUMO_EXECUCAO_comissionamento_rede_shim_cip.md)
2. [**Execução 02 (15/10/2026):** Arquitetura Multiplataforma Docker, Chromium Headless e Influx/Grafana](historico_execucoes/02_RESUMO_EXECUCAO_multiplataforma_docker_pdf.md)
3. [**Execução 03 (15/10/2026):** Intertravamentos, Bloqueio de UI, Tag `ciclo_node`, Laudo Único e Grafana](historico_execucoes/03_RESUMO_EXECUCAO_intertravamentos_laudo_individual_grafana.md)
4. [**Execução 04 (15/10/2026):** Auditoria Final, Remoção de Legados (PCCC/Órfãos) e Dossiê Técnico](historico_execucoes/04_RESUMO_EXECUCAO_auditoria_limpeza_dossie.md)
5. [**Execução 05 (16/10/2026):** Homologação de Operação 100% Offline (Air-Gapped) em Windows e Linux](historico_execucoes/05_RESUMO_EXECUCAO_operacao_100pct_offline_windows_linux.md)
6. [**Execução 06 (16/10/2026):** Controles de 3 Posições, Zeramento no Setpoint, Leitura Física da Bomba e Mobile](historico_execucoes/06_RESUMO_EXECUCAO_controles_3_posicoes_intertravamento_fisico_mobile.md)
7. [**Execução 07 (16/10/2026):** Tempo Restante Selecionável (10 a 60 min) e Responsividade Mobile](historico_execucoes/07_RESUMO_EXECUCAO_tempo_restante_selecionavel_e_responsividade_mobile.md)
8. [**Execução 08 (16/10/2026):** Corte de Setpoint via Tag CIP `COMPARACAO` e Pulso de Reset `400 ms`](historico_execucoes/08_RESUMO_EXECUCAO_corte_setpoint_comparacao_e_reset_liberar_manual.md)
9. [**Execução 09 (30/10/2026):** Gráfico SVG Dinâmico A4 Paisagem, Sincronia de Setpoint e InfluxDB Windows](historico_execucoes/09_RESUMO_EXECUCAO_grafico_dinamico_sincronia_setpoint_e_influx_windows.md) *(Atual)*

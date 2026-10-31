# Resumo de Execução - Bancada de Testes de Pressão Hidrostática
**Status do Projeto:** Ativo, Auditado e Homologado em Bancada  
**Versão Atual:** [10 - Auditoria Profunda, Hardening Metrológico (±0,5 bar & ZOH), Shim CIP 7 Camadas, Supervisão CLP e Desempenho](../historico_execucoes/10_RESUMO_EXECUCAO_auditoria_hardening_metrologia_cip_desempenho.md)  
**Data da Última Intervenção:** 31 de Outubro de 2026  
**Documento Mestre de Engenharia:** [DOSSIE_TECNICO_MANUTENCAO.md](DOSSIE_TECNICO_MANUTENCAO.md)  

---

> [!NOTE]  
> **POLÍTICA DE HISTÓRICO PERMANENTE:**  
> Este documento funciona como um **ponteiro central**. Os relatórios técnicos detalhados de cada execução e intervenção são mantidos permanentemente na pasta [`historico_execucoes/`](../historico_execucoes/), garantindo rastreabilidade histórica auditável.

---

## 📌 Execução Mais Recente: Versão 10

Para acessar o relatório técnico completo da última intervenção, abra:  
👉 **[historico_execucoes/10_RESUMO_EXECUCAO_auditoria_hardening_metrologia_cip_desempenho.md](../historico_execucoes/10_RESUMO_EXECUCAO_auditoria_hardening_metrologia_cip_desempenho.md)**

### Destaques da Versão 10:
* **Metrologia Exata e Tolerância Simétrica Bilateral (`Setpoint ± 0,5 bar`):** Suporte integral a `0,00 bar` (zeramento do manômetro e reprovação em ruptura catastrófica), semeadura da pressão inicial em `t = inicio`, keepalive estacionário de `2 s`, **média ponderada no tempo por retenção de ordem zero (ZOH)** sobre `historicoFiltrado` e reprovação bilateral tanto por queda (`< SP - 0,5 bar`) quanto por sobrepressão severa (`> SP + 0,5 bar`);
* **Shim CIP de 7 Camadas e Supervisão Online/Offline do CLP:** Reassemblagem de stream TCP EtherNet/IP (`_rxBuf`), guarda sequencial in-flight (`_write_seq` / `_inflight_seq`) para pulsos de `400 ms`, limpeza de timers em `promiseTimeout`, eliminação da tempestade de 21.600 escritas CIP/hora com motor desligado, bloqueio de partida com CLP offline e re-sincronização automática de `ciclo_node` na reconexão;
* **Alta Performance de Runtime e Robustez de PDF / Grafana:** Poda amortizada $O(1)$ do histórico em `Coleta pressão` (**58,9x** a **1.086x** mais rápida), deduplicação de WebSocket ocioso, UID determinístico `InfluxDB-Flux` no Grafana (`influxdb.yaml`), Chromium Headless blindado com `--disable-dev-shm-usage`, timeout de `30 s`, HTML temporário isolado em `/tmp` e verificação `fn_verifica_pdf`;
* **Higiene Estrutural e Pinagem Offline:** Remoção da dependência órfã `node-red-contrib-ui-led`, centralização única da documentação em `docs/`, pinagem determinística das imagens locais (`nodered/node-red:5.0.8`, `influxdb:2.7.12`, `grafana/grafana:13.2.4`) e sincronização 100% verbatim dos 18 nós `function`.

---

## 📚 Histórico Completo de Execuções

Consulte o sumário cronológico completo no arquivo:  
👉 **[historico_execucoes/README.md](../historico_execucoes/README.md)**

1. [**Execução 01 (14/10/2026):** Comissionamento de Rede, Gateway Linux e Shim CIP Micro800](../historico_execucoes/01_RESUMO_EXECUCAO_comissionamento_rede_shim_cip.md)
2. [**Execução 02 (15/10/2026):** Arquitetura Multiplataforma Docker, Chromium Headless e Influx/Grafana](../historico_execucoes/02_RESUMO_EXECUCAO_multiplataforma_docker_pdf.md)
3. [**Execução 03 (15/10/2026):** Intertravamentos, Bloqueio de UI, Tag `ciclo_node`, Laudo Único e Grafana](../historico_execucoes/03_RESUMO_EXECUCAO_intertravamentos_laudo_individual_grafana.md)
4. [**Execução 04 (15/10/2026):** Auditoria Final, Remoção de Legados (PCCC/Órfãos) e Dossiê Técnico](../historico_execucoes/04_RESUMO_EXECUCAO_auditoria_limpeza_dossie.md)
5. [**Execução 05 (16/10/2026):** Homologação de Operação 100% Offline (Air-Gapped) em Windows e Linux](../historico_execucoes/05_RESUMO_EXECUCAO_operacao_100pct_offline_windows_linux.md)
6. [**Execução 06 (16/10/2026):** Controles de 3 Posições, Zeramento no Setpoint, Leitura Física da Bomba e Mobile](../historico_execucoes/06_RESUMO_EXECUCAO_controles_3_posicoes_intertravamento_fisico_mobile.md)
7. [**Execução 07 (16/10/2026):** Tempo Restante Selecionável (10 a 60 min) e Responsividade Mobile](../historico_execucoes/07_RESUMO_EXECUCAO_tempo_restante_selecionavel_e_responsividade_mobile.md)
8. [**Execução 08 (16/10/2026):** Corte de Setpoint via Tag CIP `COMPARACAO` e Pulso de Reset `400 ms`](../historico_execucoes/08_RESUMO_EXECUCAO_corte_setpoint_comparacao_e_reset_liberar_manual.md)
9. [**Execução 09 (30/10/2026):** Gráfico SVG Dinâmico A4 Paisagem, Sincronia de Setpoint e InfluxDB Windows](../historico_execucoes/09_RESUMO_EXECUCAO_grafico_dinamico_sincronia_setpoint_e_influx_windows.md)
10. [**Execução 10 (31/10/2026):** Auditoria Profunda, Hardening Metrológico (±0,5 bar & ZOH), Shim CIP 7 Camadas e Desempenho](../historico_execucoes/10_RESUMO_EXECUCAO_auditoria_hardening_metrologia_cip_desempenho.md) *(Atual)*

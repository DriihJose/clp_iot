# Resumo de Execução - Bancada de Testes de Pressão Hidrostática
**Status do Projeto:** Ativo, Auditado e Homologado em Bancada  
**Versão Atual:** [08 - Corte de Setpoint via Tag CIP COMPARACAO e Reset Efetivo de Liberar Manual](historico_execucoes/08_RESUMO_EXECUCAO_corte_setpoint_comparacao_e_reset_liberar_manual.md)  
**Data da Última Intervenção:** 16 de Outubro de 2026  
**Documento Mestre de Engenharia:** [DOSSIE_TECNICO_MANUTENCAO.md](DOSSIE_TECNICO_MANUTENCAO.md)  

---

> [!NOTE]  
> **POLÍTICA DE HISTÓRICO PERMANENTE:**  
> Este documento funciona como um **ponteiro central**. Os relatórios técnicos detalhados de cada execução e intervenção são mantidos permanentemente na pasta [`historico_execucoes/`](historico_execucoes/), garantindo rastreabilidade histórica auditável.

---

## 📌 Execução Mais Recente: Versão 08

Para acessar o relatório técnico completo da última intervenção, abra:  
👉 **[historico_execucoes/08_RESUMO_EXECUCAO_corte_setpoint_comparacao_e_reset_liberar_manual.md](historico_execucoes/08_RESUMO_EXECUCAO_corte_setpoint_comparacao_e_reset_liberar_manual.md)**

### Destaques da Versão 08:
* **Corte Definitivo no Setpoint via Tag CIP `COMPARACAO`:** Eliminação do religamento automático do motor após atingir o setpoint. Nó `eth_in_comparacao` lê a tag `COMPARACAO` do Micro850 e força `on_node = false` e `off_node = false` no CLP e reseta `motor_on = false` e a interface para "LIBERAR MANUAL". Ao cair a pressão, o motor não religa sozinho;
* **Reset Efetivo ao "Liberar Manual":** No controle do motor e da válvula, selecionar "LIBERAR MANUAL" define `on_node = false`, `off_node = false`, `onval_node = false` e `offval_node = false` tanto no estado de contexto quanto fisicamente no CLP via CIP;
* **Despacho Forçado CIP no `eth-ip out`:** Otimização no tratador `onNewMsg` anulando o cache `controllerValue` para assegurar que qualquer mensagem de comando recebida pelo supervisório seja efetivamente transmitida via CIP sem supressão de duplicatas.

---

## 📚 Histórico Completo de Execuções

Consulte o sumário cronológico completo no arquivo:  
👉 **[historico_execucoes/README.md](historico_execucoes/README.md)**

1. [**Execução 01 (14/10/2026):** Comissionamento de Rede, Gateway Linux e Shim CIP Micro800](historico_execucoes/01_RESUMO_EXECUCAO_comissionamento_rede_shim_cip.md)
2. [**Execução 02 (15/10/2026):** Arquitetura Multiplataforma Docker, Chromium Headless e Influx/Grafana](historico_execucoes/02_RESUMO_EXECUCAO_multiplataforma_docker_pdf.md)
3. [**Execução 03 (15/10/2026):** Intertravamentos, Bloqueio de UI, Tag `ciclo_node`, Laudo Único e Grafana](historico_execucoes/03_RESUMO_EXECUCAO_intertravamentos_laudo_individual_grafana.md)
4. [**Execução 04 (15/10/2026):** Auditoria Final, Remoção de Legados (PCCC/Órfãos) e Dossiê Técnico](historico_execucoes/04_RESUMO_EXECUCAO_auditoria_limpeza_dossie.md)
5. [**Execução 05 (16/10/2026):** Homologação de Operação 100% Offline (Air-Gapped) em Windows e Linux](historico_execucoes/05_RESUMO_EXECUCAO_operacao_100pct_offline_windows_linux.md)
6. [**Execução 06 (16/10/2026):** Controles de 3 Posições, Zeramento no Setpoint, Leitura Física da Bomba e Mobile](historico_execucoes/06_RESUMO_EXECUCAO_controles_3_posicoes_intertravamento_fisico_mobile.md) *(Atual)*


# Resumo de Execução - Bancada de Testes de Pressão Hidrostática
**Status do Projeto:** Ativo, Auditado e Homologado em Bancada  
**Versão Atual:** [06 - Controles de 3 Posições, Zeramento no Setpoint, Leitura Física da Bomba e Responsividade Mobile](historico_execucoes/06_RESUMO_EXECUCAO_controles_3_posicoes_intertravamento_fisico_mobile.md)  
**Data da Última Intervenção:** 16 de Outubro de 2026  
**Documento Mestre de Engenharia:** [DOSSIE_TECNICO_MANUTENCAO.md](DOSSIE_TECNICO_MANUTENCAO.md)  

---

> [!NOTE]  
> **POLÍTICA DE HISTÓRICO PERMANENTE:**  
> Este documento funciona como um **ponteiro central**. Os relatórios técnicos detalhados de cada execução e intervenção são mantidos permanentemente na pasta [`historico_execucoes/`](historico_execucoes/), garantindo rastreabilidade histórica auditável.

---

## 📌 Execução Mais Recente: Versão 06

Para acessar o relatório técnico completo da última intervenção, abra:  
👉 **[historico_execucoes/06_RESUMO_EXECUCAO_controles_3_posicoes_intertravamento_fisico_mobile.md](historico_execucoes/06_RESUMO_EXECUCAO_controles_3_posicoes_intertravamento_fisico_mobile.md)**

### Destaques da Versão 06:
* **Controles Manuais de 3 Posições (`ui_dropdown`):** Substituição dos switches binários de Motor e Válvula por seletores de 3 posições ("LIGADO/ABERTO", "DESLIGADO/FECHADO", "LIBERAR MANUAL"), alinhados com as Linhas 1 a 9 do programa Ladder do Micro850 e desengatando sinais lógicos para permitir operação pelas botoeiras/seletoras físicas da bancada.
* **Zeramento Automático de `on_node` no Setpoint:** Nó `fn_auto_cutoff_sp` monitora `RETORNO_BAR` e, ao atingir ou ultrapassar o setpoint configurado com o motor manual ativo, reseta `on_node` e `off_node` para `false`, desliga o estado em memória e atualiza a interface para "LIBERAR MANUAL".
* **Leitura Física da Bomba (`_IO_EM_DO_01`):** Adicionada a leitura direta da saída física da Bomba via CIP no endpoint do Micro850, armazenada em `flow.bomba_fisica`.
* **Intertravamento Estrito em `Inicia teste`:** Bloqueio da partida caso o nome do Equipamento esteja vazio, a bomba esteja ligada (em comando ou na saída física), a válvula esteja aberta (em comando ou na saída física `_IO_EM_DO_00`), ou o setpoint seja inválido.
* **Responsividade Mobile via CSS Isolado:** Injeção de CSS via `ui_template` restrito a `@media only screen and (max-width: 768px)`, com escala proporcional de zoom para celulares (< 650px), mantendo o layout de computadores (>= 769px) 100% inalterado.
* **Comunicação CIP Multi-Tag:** Validação de 9 tags CIP ativas simultaneamente no Micro850 em modo 100% offline.

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


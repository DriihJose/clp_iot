# Resumo de Execução - Bancada de Testes de Pressão Hidrostática
**Status do Projeto:** Ativo, Auditado e Homologado em Bancada  
**Versão Atual:** [05 - Homologação de Operação 100% Offline (Air-Gapped) em Windows e Linux](historico_execucoes/05_RESUMO_EXECUCAO_operacao_100pct_offline_windows_linux.md)  
**Data da Última Intervenção:** 16 de Outubro de 2026  
**Documento Mestre de Engenharia:** [DOSSIE_TECNICO_MANUTENCAO.md](DOSSIE_TECNICO_MANUTENCAO.md)  

---

> [!NOTE]  
> **POLÍTICA DE HISTÓRICO PERMANENTE:**  
> Este documento funciona como um **ponteiro central**. Os relatórios técnicos detalhados de cada execução e intervenção são mantidos permanentemente na pasta [`historico_execucoes/`](historico_execucoes/), garantindo rastreabilidade histórica auditável.

---

## 📌 Execução Mais Recente: Versão 05

Para acessar o relatório técnico completo da última intervenção, abra:  
👉 **[historico_execucoes/05_RESUMO_EXECUCAO_operacao_100pct_offline_windows_linux.md](historico_execucoes/05_RESUMO_EXECUCAO_operacao_100pct_offline_windows_linux.md)**

### Destaques da Versão 05:
* **Remoção de `--build` Forçado:** Inicialização inteligente dos scripts `setup-windows.ps1` e `setup-linux.sh`, evitando chamadas ao gerenciador `apk` da Alpine em tempo de boot.
* **Diretiva `pull_policy: missing`:** Aplicada em todos os contêineres do `docker-compose.windows.yml` e `docker-compose.yml`, eliminando tentativas de resolução no Docker Hub.
* **Bloqueio de Telemetrias e Catálogos:** Node-RED (`catalogues: []`, telemetria desativada), Grafana (telemetria e feeds desligados) e InfluxDB (`INFLUXD_REPORTING_DISABLED=true`).
* **Scripts Operacionais e de Portabilidade:** Criação de `iniciar-sistema.bat`, `parar-sistema.bat` e `exportar-imagens-offline.bat` para transporte de imagens via pen drive.
* **Relatório Técnico Windows Atualizado:** Documento completo em [`RELATORIO_MIGRACAO_WINDOWS.md`](RELATORIO_MIGRACAO_WINDOWS.md) com orientações para ambiente industrial desconectado.

---

## 📚 Histórico Completo de Execuções

Consulte o sumário cronológico completo no arquivo:  
👉 **[historico_execucoes/README.md](historico_execucoes/README.md)**

1. [**Execução 01 (14/10/2026):** Comissionamento de Rede, Gateway Linux e Shim CIP Micro800](historico_execucoes/01_RESUMO_EXECUCAO_comissionamento_rede_shim_cip.md)
2. [**Execução 02 (15/10/2026):** Arquitetura Multiplataforma Docker, Chromium Headless e Influx/Grafana](historico_execucoes/02_RESUMO_EXECUCAO_multiplataforma_docker_pdf.md)
3. [**Execução 03 (15/10/2026):** Intertravamentos, Bloqueio de UI, Tag `ciclo_node`, Laudo Único e Grafana](historico_execucoes/03_RESUMO_EXECUCAO_intertravamentos_laudo_individual_grafana.md)
4. [**Execução 04 (15/10/2026):** Auditoria Final, Remoção de Legados (PCCC/Órfãos) e Dossiê Técnico](historico_execucoes/04_RESUMO_EXECUCAO_auditoria_limpeza_dossie.md)
5. [**Execução 05 (16/10/2026):** Homologação de Operação 100% Offline (Air-Gapped) em Windows e Linux](historico_execucoes/05_RESUMO_EXECUCAO_operacao_100pct_offline_windows_linux.md) *(Atual)*


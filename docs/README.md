# 📚 Documentação Técnica e Arquitetural do Sistema SCADA

Este diretório reúne todo o histórico de engenharia, relatórios de migração, especificações do supervisório e dossiê técnico de manutenção da Bancada de Testes de Pressão Hidrostática (CLP Allen-Bradley Micro850).

---

## 📑 Índice dos Documentos

| Documento | Descrição |
| :--- | :--- |
| **[`DOSSIE_TECNICO_MANUTENCAO.md`](DOSSIE_TECNICO_MANUTENCAO.md)** | **Dossiê completo de engenharia:** mapa detalhado de nós do Node-RED, tags CIP do CLP, fluxos de geração de PDF via Chromium headless, queries do InfluxDB 2.7 e painéis do Grafana. |
| **[`RELATORIO_MIGRACAO_WINDOWS.md`](RELATORIO_MIGRACAO_WINDOWS.md)** | **Relatório de transição Linux -> Windows:** diagnóstico e solução de dependências de internet, provisionamento de rede industrial e modo 100% offline (air-gapped). |
| **[`RESUMO_PROJETO_SCADA.md`](RESUMO_PROJETO_SCADA.md)** | **Visão executiva e operacional:** arquitetura de ponta a ponta, regras de tolerância de teste hidrostático e rotinas da IHM web. |
| **[`RESUMO_EXECUCAO.md`](RESUMO_EXECUCAO.md)** | **Registro de marcos de execução:** etapas cumpridas durante as fases de integração e testes de bancada. |

---

> Para instruções de como executar os contêineres e scripts, consulte a pasta [`../scripts`](../scripts/README.md).

# Histórico Permanente de Execuções e Intervenções Técnicas
**Projeto:** Sistema SCADA/IoT - Bancada de Testes de Pressão Hidrostática (Detecto / Vigor Alimentos)  
**Repositório:** `/home/mec/clp_iot`  
**Controlador:** Rockwell Automation Allen-Bradley Micro850 (2080-L50E-48QBB)  

Este diretório mantém o registro cronológico, auditável e cumulativo de todas as etapas de desenvolvimento, comissionamento e manutenção do sistema.

> **REGRA DE HISTÓRICO PERMANENTE:**  
> Nenhum relatório existente nesta pasta deve ser sobrescrito ou apagado. Cada nova rodada de alterações deve gerar um novo arquivo numerado sequencialmente (`04_...`, `05_...`), acompanhado da atualização deste índice.

---

## Linha do Tempo das Execuções

| N° | Data | Arquivo | Escopo Principal | Autor / Executor | Status |
| :-: | :-: | :--- | :--- | :--- | :-: |
| **01** | 14/10/2026 | [`01_RESUMO_EXECUCAO_comissionamento_rede_shim_cip.md`](01_RESUMO_EXECUCAO_comissionamento_rede_shim_cip.md) | Comissionamento de rede física (`enp58s0`), resolução de conflito de gateway Linux, recuperação após exclusão acidental e desenvolvimento do **Shim Micro800** para CIP Message Router direto (porta 44818). | Adriano J. / Antigravity | Aprovado |
| **02** | 15/10/2026 | [`02_RESUMO_EXECUCAO_multiplataforma_docker_pdf.md`](02_RESUMO_EXECUCAO_multiplataforma_docker_pdf.md) | Reestruturação multiplataforma (Linux nativo + Windows Docker Desktop), criação de `Dockerfile.nodered` com Chromium headless e provisionamento automatizado de InfluxDB 2.7 e Grafana. | Adriano J. / Antigravity | Aprovado |
| **03** | 15/10/2026 | [`03_RESUMO_EXECUCAO_intertravamentos_laudo_individual_grafana.md`](03_RESUMO_EXECUCAO_intertravamentos_laudo_individual_grafana.md) | Intertravamento de partida (Equipamento / Motor / Válvula), bloqueio seletivo de UI (`msg.enabled`), controle da tag `ciclo_node` no CLP, laudos PDF independentes com layout A4 e cartões superiores reorganizados no Grafana. | Adriano J. / Antigravity | Aprovado |
| **04** | 15/10/2026 | [`04_RESUMO_EXECUCAO_auditoria_limpeza_dossie.md`](04_RESUMO_EXECUCAO_auditoria_limpeza_dossie.md) | Auditoria linha por linha, remoção total de pacotes órfãos (`@flowfuse/node-red-dashboard`) e nós residuais, revisão multiplataforma e confecção do Dossiê Técnico Definitivo (`DOSSIE_TECNICO_MANUTENCAO.md`). | Adriano J. / Antigravity | Aprovado |
| **05** | 16/10/2026 | [`05_RESUMO_EXECUCAO_operacao_100pct_offline_windows_linux.md`](05_RESUMO_EXECUCAO_operacao_100pct_offline_windows_linux.md) | Homologação de operação 100% offline (air-gapped): remoção de `--build` forçado, diretiva `pull_policy: missing`, desativação de telemetria/catálogos, scripts batch de automação e exportador de imagens Docker `.tar`. | Adriano J. / Antigravity | Aprovado |

---

## Estrutura do Diretório

```
historico_execucoes/
├── README.md                                                             # Este sumário e linha do tempo
├── 01_RESUMO_EXECUCAO_comissionamento_rede_shim_cip.md                    # Execução 01
├── 02_RESUMO_EXECUCAO_multiplataforma_docker_pdf.md                      # Execução 02
├── 03_RESUMO_EXECUCAO_intertravamentos_laudo_individual_grafana.md       # Execução 03
├── 04_RESUMO_EXECUCAO_auditoria_limpeza_dossie.md                         # Execução 04
└── 05_RESUMO_EXECUCAO_operacao_100pct_offline_windows_linux.md           # Execução 05 (Atual)
```

O arquivo [`RESUMO_EXECUCAO.md`](../RESUMO_EXECUCAO.md) na raiz do repositório funciona como ponteiro de leitura rápida direcionando para a versão mais recente (**05**).


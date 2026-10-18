# 🚀 Scripts de Operação, Automação e Manutenção

Esta pasta agrupa todos os utilitários de execução e controle do ciclo de vida da aplicação SCADA para teste de bancada hidrostática com o CLP Allen-Bradley Micro850.

---

## 📂 Organização por Plataforma

```text
scripts/
├── windows/                # Scripts para Windows 10/11 (Docker Desktop / WSL2)
│   ├── iniciar-sistema.bat
│   ├── parar-sistema.bat
│   ├── setup-windows.ps1
│   ├── exportar-imagens-offline.bat
│   ├── enviar-github.bat
│   └── README.md           # Manual completo para Windows
└── linux/                  # Scripts para Linux Ubuntu / Debian Industrial
    ├── iniciar-sistema.sh
    ├── parar-sistema.sh
    ├── setup-linux.sh
    └── README.md           # Manual completo para Linux
```

---

## ⚡ Atalhos Rápidos na Raiz do Projeto
Para facilitar a rotina do operador no dia a dia, a raiz do projeto (`C:\aplicacoes\clp_iot`) conta com:
- **`iniciar-sistema.bat`** ➔ Chama `scripts/windows/iniciar-sistema.bat`
- **`parar-sistema.bat`**   ➔ Chama `scripts/windows/parar-sistema.bat`

Além disso, atalhos equivalentes e o acesso à pasta de relatórios foram disponibilizados diretamente na **Área de Trabalho**.

# ==============================================================================
# INICIALIZAÇÃO DO SISTEMA SCADA / IoT - BANCADA DE PRESSÃO HIDROSTÁTICA
# Ambiente: Windows (Docker Desktop com WSL2)
# ==============================================================================

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "   INICIALIZAÇÃO DO SISTEMA SCADA / IoT - BANCADA DE PRESSÃO     " -ForegroundColor Cyan
Write-Host "             Ambiente: Windows (Docker Desktop)                  " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# 1. Configuração do arquivo de variáveis de ambiente (.env)
if (-not (Test-Path ".env")) {
    Write-Host "[1/4] Criando arquivo .env a partir de .env.example..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host "       .env criado com sucesso." -ForegroundColor Green
} else {
    Write-Host "[1/4] Arquivo .env já existe. Mantendo configurações locais." -ForegroundColor Green
}

# 2. Criação das pastas locais necessárias
Write-Host "[2/4] Verificando e criando pastas locais..." -ForegroundColor Yellow
$pastas = @("nodered_data", "relatorios", "grafana_data", "influxdb_data", "influxdb_config")
foreach ($pasta in $pastas) {
    if (-not (Test-Path $pasta)) {
        New-Item -ItemType Directory -Path $pasta | Out-Null
    }
}
Write-Host "       Pastas locais verificadas." -ForegroundColor Green

# 3. Orientação e Verificação da Placa de Rede para o CLP Micro850
Write-Host "[3/4] Verificando adaptadores de rede Ethernet..." -ForegroundColor Yellow
try {
    $adaptadores = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" -and $_.MediaType -eq "802.3" }
    if ($adaptadores) {
        Write-Host "       Adaptador Ethernet ativo detectado: $($adaptadores[0].Name)" -ForegroundColor Cyan
        $ipAtual = Get-NetIPAddress -InterfaceAlias $adaptadores[0].Name -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -like "192.168.1.*" }
        if ($ipAtual) {
            Write-Host "       [OK] Adaptador ja possui IP na sub-rede 192.168.1.x: $($ipAtual.IPAddress)" -ForegroundColor Green
        } else {
            Write-Host "       [AVISO] Configure o IP estatico na placa cabeada do Windows:" -ForegroundColor Yellow
            Write-Host "               IP: 192.168.1.100 | Mascara: 255.255.255.0 | Gateway: (em branco)" -ForegroundColor Yellow
            Write-Host "       Deseja tentar configurar automaticamente agora? (Requer PowerShell como Administrador)" -ForegroundColor Gray
        }
    } else {
        Write-Host "       [INFO] Conecte o cabo Ethernet entre o computador e o CLP Micro850 (IP fixo 192.168.1.33)." -ForegroundColor Yellow
    }
} catch {
    Write-Host "       Não foi possível consultar os adaptadores automaticamente: $($_.Exception.Message)" -ForegroundColor Gray
}

# 4. Inicialização do Docker Compose no Windows
Write-Host "[4/4] Subindo contêineres via docker-compose.windows.yml..." -ForegroundColor Yellow
docker compose -f docker-compose.windows.yml up -d --build

Write-Host "=================================================================" -ForegroundColor Green
Write-Host "   SISTEMA SCADA EM EXECUÇÃO NO WINDOWS:                         " -ForegroundColor Green
Write-Host "   - Supervisório / IHM Operador : http://localhost:1880/ui      " -ForegroundColor Cyan
Write-Host "   - Editor de Fluxos Node-RED   : http://localhost:1880         " -ForegroundColor Cyan
Write-Host "   - InfluxDB 2.7 (Dados/Tokens) : http://localhost:8086         " -ForegroundColor Cyan
Write-Host "   - Grafana (Gráficos Flux)     : http://localhost:3000         " -ForegroundColor Cyan
Write-Host "   - Pasta de Relatórios PDF/HTML: .\relatorios                  " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Green

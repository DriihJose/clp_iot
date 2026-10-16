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

# 1.1 Configuração automática das credenciais do Node-RED para InfluxDB
$credPath = "nodered_data/flows_cred.json"
if (-not (Test-Path $credPath)) {
    Write-Host "       Provisionando credencial do InfluxDB para o Node-RED..." -ForegroundColor Yellow
    $token = "mDT86-v55lCtaReP2ECGeXKz0bdrsDg3Kn5693it6YOaI-ITNpMWW-MQqWi3X-YWkBwbSEvQMuT3SWAK13N8NA=="
    if (Test-Path ".env") {
        $envToken = Get-Content ".env" | Where-Object { $_ -match "^DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=(.*)$" } | ForEach-Object { $matches[1].Trim() }
        if ($envToken) { $token = $envToken }
    }
    $credJson = @{
        "235fd83d5ce9ea5d" = @{
            "token" = $token
        }
    } | ConvertTo-Json
    Set-Content -Path $credPath -Value $credJson -Encoding UTF8
    Write-Host "       flows_cred.json provisionado com sucesso." -ForegroundColor Green
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

# 3. Orientação e Verificação da Placa de Rede para o CLP Micro850 (100% Offline)
Write-Host "[3/4] Verificando adaptadores de rede e conectividade com o CLP..." -ForegroundColor Yellow
try {
    $adaptadores = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" -and $_.MediaType -eq "802.3" }
    if ($adaptadores) {
        Write-Host "       Adaptador Ethernet ativo detectado: $($adaptadores[0].Name)" -ForegroundColor Cyan
        $ipAtual = Get-NetIPAddress -InterfaceAlias $adaptadores[0].Name -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -like "192.168.1.*" }
        if ($ipAtual) {
            Write-Host "       [OK] Adaptador possui IP estático na sub-rede industrial (192.168.1.x): $($ipAtual.IPAddress)" -ForegroundColor Green
        } else {
            Write-Host "       [AVISO] Configure o IP estático na placa cabeada do Windows:" -ForegroundColor Yellow
            Write-Host "               IP: 192.168.1.100 ou 192.168.1.200 | Máscara: 255.255.255.0 | Gateway: (em branco)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "       [INFO] Conecte o cabo Ethernet entre o computador e o CLP Micro850 (IP fixo 192.168.1.33)." -ForegroundColor Yellow
    }

    # Teste de conectividade com o CLP (sem depender de DNS ou internet)
    $pingClp = Test-Connection -ComputerName "192.168.1.33" -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($pingClp) {
        Write-Host "       [OK] Comunicação com o CLP Micro850 (192.168.1.33) confirmada!" -ForegroundColor Green
    } else {
        Write-Host "       [INFO] CLP 192.168.1.33 ainda não respondeu ao ping (verifique cabo/alimentação)." -ForegroundColor Gray
    }
} catch {
    Write-Host "       Verificação automática de rede ignorada: $($_.Exception.Message)" -ForegroundColor Gray
}

# 4. Inicialização do Docker Compose no Windows (100% Offline)
Write-Host "[4/4] Verificando Docker e iniciando contêineres em modo 100% offline..." -ForegroundColor Yellow
$dockerOk = $false
try {
    $null = docker ps 2>&1
    if ($LASTEXITCODE -eq 0) { $dockerOk = $true }
} catch {}

if (-not $dockerOk) {
    Write-Host "       Docker não está respondendo. Iniciando Docker Desktop..." -ForegroundColor Yellow
    $dockerPaths = @(
        "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe",
        "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    )
    foreach ($p in $dockerPaths) {
        if (Test-Path $p) {
            Start-Process $p
            break
        }
    }
    Write-Host "       Aguardando o serviço do Docker iniciar..." -ForegroundColor Gray
    $tentativas = 0
    while ($tentativas -lt 20) {
        Start-Sleep -Seconds 3
        try {
            $null = docker ps 2>&1
            if ($LASTEXITCODE -eq 0) {
                $dockerOk = $true
                break
            }
        } catch {}
        $tentativas++
    }
}

# Carregamento automático de imagens offline (.tar) se existirem na pasta
$tarFiles = Get-ChildItem -Path "." -Filter "*.tar" -ErrorAction SilentlyContinue
foreach ($tar in $tarFiles) {
    Write-Host "       Carregando imagem offline: $($tar.Name)..." -ForegroundColor Cyan
    docker load -i $tar.FullName
}

# Execução offline: Se a imagem já existe no Docker local, NÃO recompila (evita chamadas apk/alpine)
$hasNodeRed = docker images -q clp_iot-nodered:latest
if ($hasNodeRed) {
    Write-Host "       [MODO OFFLINE] Imagem 'clp_iot-nodered:latest' encontrada no cache local." -ForegroundColor Green
    Write-Host "       Subindo serviços sem qualquer consulta à internet..." -ForegroundColor Green
    docker compose -f docker-compose.windows.yml up -d
} else {
    Write-Host "       [AVISO] Imagem 'clp_iot-nodered:latest' ausente no Docker." -ForegroundColor Yellow
    Write-Host "       Tentando compilação local (requer conexão ou cache de pacotes)..." -ForegroundColor Yellow
    docker compose -f docker-compose.windows.yml up -d --build
}

Write-Host "=================================================================" -ForegroundColor Green
Write-Host "   SISTEMA SCADA EM EXECUÇÃO NO WINDOWS (100% OFFLINE):          " -ForegroundColor Green
Write-Host "   - Supervisório / IHM Operador : http://localhost:1880/ui      " -ForegroundColor Cyan
Write-Host "   - Editor de Fluxos Node-RED   : http://localhost:1880         " -ForegroundColor Cyan
Write-Host "   - InfluxDB 2.7 (Dados/Tokens) : http://localhost:8086         " -ForegroundColor Cyan
Write-Host "   - Grafana (Gráficos Flux)     : http://localhost:3000         " -ForegroundColor Cyan
Write-Host "   - Pasta de Relatórios PDF/HTML: .\relatorios                  " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Green

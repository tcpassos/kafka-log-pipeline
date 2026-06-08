# Mede tempo de inicializacao de cada container — dado para slide de Performance
# Execute ANTES de subir o stack, ou use após 'docker compose down'

$root = Split-Path $PSScriptRoot -Parent

function Get-ElapsedSec { param([datetime]$start) [math]::Round(((Get-Date) - $start).TotalSeconds, 1) }

Write-Host "=== MEDIÇÃO DE STARTUP DO STACK ===" -ForegroundColor Cyan
Write-Host ""

# Sobe kafka-cluster
Write-Host "[1/3] Subindo kafka-cluster..." -ForegroundColor Yellow
$t1 = Get-Date
Set-Location "$root\kafka-cluster"
docker compose up -d 2>&1 | Out-Null

# Aguarda broker ficar healthy
Write-Host "      Aguardando broker..." -ForegroundColor DarkGray
do { Start-Sleep -Seconds 2 }
until ((docker inspect --format='{{.State.Health.Status}}' broker 2>$null) -eq 'healthy' -or
       (docker ps --filter "name=broker" --filter "status=running" -q 2>$null))

$tKafka = Get-ElapsedSec $t1
Write-Host "  kafka-cluster UP em $tKafka s" -ForegroundColor Green

# Sobe consumer stack
Write-Host "[2/3] Subindo consumer stack (ES + Kibana + Logstash)..." -ForegroundColor Yellow
$t2 = Get-Date
Set-Location "$root\logs-siger-consumer-es"
docker compose up -d 2>&1 | Out-Null

# Aguarda elasticsearch
Write-Host "      Aguardando Elasticsearch..." -ForegroundColor DarkGray
do { Start-Sleep -Seconds 3 }
until ((docker inspect --format='{{.State.Health.Status}}' elasticsearch 2>$null) -eq 'healthy')

$tES = Get-ElapsedSec $t2
Write-Host "  Elasticsearch healthy em $tES s" -ForegroundColor Green

do { Start-Sleep -Seconds 3 }
until ((docker inspect --format='{{.State.Health.Status}}' kibana 2>$null) -eq 'healthy')

$tKibana = Get-ElapsedSec $t2
Write-Host "  Kibana healthy em $tKibana s" -ForegroundColor Green
$tConsumer = Get-ElapsedSec $t2
Write-Host "  consumer stack UP em $tConsumer s" -ForegroundColor Green

# Sobe producer
Write-Host "[3/3] Subindo Filebeat (producer)..." -ForegroundColor Yellow
$t3 = Get-Date
Set-Location "$root\logs-siger-producer-filebeat"
docker compose up -d 2>&1 | Out-Null
Start-Sleep -Seconds 5
$tFilebeat = Get-ElapsedSec $t3
Write-Host "  Filebeat UP em $tFilebeat s" -ForegroundColor Green

$tTotal = Get-ElapsedSec $t1
Write-Host ""
Write-Host "=== RESUMO DE STARTUP ===" -ForegroundColor Cyan
Write-Host "  Kafka Cluster : $tKafka s"
Write-Host "  Elasticsearch : $tES s"
Write-Host "  Kibana        : $tKibana s"
Write-Host "  Filebeat      : $tFilebeat s"
Write-Host "  TOTAL         : $tTotal s"
Write-Host ""
Write-Host "Esses dados podem ser usados no slide de Performance." -ForegroundColor DarkGray

Set-Location $root

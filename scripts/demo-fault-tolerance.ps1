# Demo de tolerância a falhas: derruba broker2 e mostra que o pipeline continua
# Para usar durante o vídeo — cada passo é confirmado pelo usuário

function Pause-Demo {
    param([string]$msg)
    Write-Host ""
    Write-Host ">>> $msg" -ForegroundColor Yellow
    Write-Host "    [Pressione ENTER para continuar]" -ForegroundColor DarkGray
    Read-Host | Out-Null
}

Write-Host "=== DEMO: TOLERÂNCIA A FALHAS ===" -ForegroundColor Cyan
Write-Host ""

# Passo 1: Estado inicial
Write-Host "PASSO 1 — Estado inicial do cluster Kafka" -ForegroundColor Green
docker ps --filter "name=broker" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
Pause-Demo "Mostre na tela que ambos brokers estao UP"

# Passo 2: Verificar replicacao antes da falha
Write-Host "PASSO 2 — Replicação atual dos tópicos (antes da falha)" -ForegroundColor Green
docker exec broker kafka-topics --bootstrap-server broker:29092 --describe --topic logs_siger_java 2>$null
Pause-Demo "Mostre que logs_siger_java tem replicas em broker E broker2"

# Passo 3: Simular falha
Write-Host "PASSO 3 — Simulando falha: derrubando broker2..." -ForegroundColor Red
docker stop broker2
Start-Sleep -Seconds 3
docker ps --filter "name=broker" --format "table {{.Names}}\t{{.Status}}"
Pause-Demo "broker2 esta DOWN. Observe que broker1 ainda responde"

# Passo 4: Pipeline continua funcionando
Write-Host "PASSO 4 — Verificando que o Filebeat continua publicando no broker1" -ForegroundColor Green
docker logs filebeat-collector --tail 10 2>$null
Pause-Demo "Mostre logs do Filebeat — ele detecta a falha e usa o broker1"

# Passo 5: Verificar consumer
Write-Host "PASSO 5 — Logstash ainda consome do broker1" -ForegroundColor Green
docker logs logstash-sink --tail 10 2>$null
Pause-Demo "Mostre que o Logstash continua processando mensagens"

# Passo 6: Recuperacao
Write-Host "PASSO 6 — Recuperação: reiniciando broker2..." -ForegroundColor Green
docker start broker2
Start-Sleep -Seconds 10
docker ps --filter "name=broker" --format "table {{.Names}}\t{{.Status}}"
Pause-Demo "broker2 voltou. Mostre que ele faz resync automatico com broker1"

# Passo 7: Estado final
Write-Host "PASSO 7 — Estado final dos tópicos (após recuperação)" -ForegroundColor Green
docker exec broker kafka-topics --bootstrap-server broker:29092 --describe --topic logs_siger_java 2>$null

Write-Host ""
Write-Host "=== DEMO CONCLUÍDO ===" -ForegroundColor Cyan
Write-Host "Conceitos demonstrados: Replicação Kafka, Docker restart policy, resiliência de rede" -ForegroundColor Green

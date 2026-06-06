# Aplica o index template ES e (opcionalmente) deleta data streams antigos
# Uso:
#   .\scripts\apply-es-template.ps1            # apenas aplica template
#   .\scripts\apply-es-template.ps1 -Reset     # deleta data streams existentes antes (para que o novo template entre em vigor)

param(
    [switch]$Reset
)

$ErrorActionPreference = 'Stop'
$EsUrl = 'http://localhost:9200'
$TemplatePath = Join-Path $PSScriptRoot '..\logs-siger-consumer-es\elasticsearch\templates\logs-siger-template.json'

Write-Host "==> Verificando Elasticsearch em $EsUrl..."
try {
    $health = Invoke-RestMethod "$EsUrl/_cluster/health" -Method Get -TimeoutSec 5
    Write-Host "    Cluster status: $($health.status)"
} catch {
    Write-Error "Elasticsearch não respondeu. Suba o stack primeiro."
    exit 1
}

if ($Reset) {
    Write-Host "==> Deletando data streams antigos (logs-java-siger, logs-crash-siger)..."
    foreach ($ds in @('logs-java-siger', 'logs-crash-siger')) {
        try {
            Invoke-RestMethod "$EsUrl/_data_stream/$ds" -Method Delete | Out-Null
            Write-Host "    Deletado: $ds"
        } catch {
            Write-Host "    (sem alteração: $ds não existia)"
        }
    }
}

Write-Host "==> Aplicando index template 'logs-siger'..."
$body = Get-Content $TemplatePath -Raw
$resp = Invoke-RestMethod "$EsUrl/_index_template/logs-siger" -Method Put -ContentType 'application/json' -Body $body
Write-Host "    Acknowledged: $($resp.acknowledged)"

Write-Host "==> OK. Template ativo para 'logs-java-siger*' e 'logs-crash-siger*'."

# Monta a estrutura de diretórios esperada pelo Filebeat para o demo
# /logs/<client_id>/RLS/java/<arquivo.LOG>

$root = Split-Path $PSScriptRoot -Parent
$source = "$root\logs-siger-producer-filebeat\sample-logs-1"
$dest   = "$root\logs"

Write-Host "Limpando diretório de logs anterior..." -ForegroundColor Yellow
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }

Write-Host "Criando estrutura de logs para demo..." -ForegroundColor Cyan

Get-ChildItem $source -File | ForEach-Object {
    $file = $_

    # Extrai client_id do nome do arquivo:
    # SIGER_<ClientId>_<Machine>_<date>_<time>_<pid>.LOG
    # SigerCrashReport_<ClientId>_<Machine>_<date>_<time>_<pid>.log
    $parts = $file.BaseName -split '_'
    $clientId = if ($parts.Count -ge 2) { $parts[1] } else { "unknown" }

    $targetDir = "$dest\$clientId\RLS\java"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    Copy-Item $file.FullName -Destination "$targetDir\$($file.Name)" -Force
}

$clientDirs = Get-ChildItem $dest -Directory | Select-Object -ExpandProperty Name
Write-Host ""
Write-Host "Estrutura criada em: $dest" -ForegroundColor Green
Write-Host "Clientes encontrados: $($clientDirs -join ', ')" -ForegroundColor Green
Write-Host ""
Write-Host "Contagem de arquivos por cliente:" -ForegroundColor Green
Get-ChildItem $dest -Recurse -File | Group-Object { $_.FullName.Split('\')[-4] } |
    ForEach-Object { Write-Host "  $($_.Name): $($_.Count) arquivos" }

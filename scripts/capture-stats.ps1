# Captura docker stats por N segundos e salva CSV para gráficos da apresentação
param(
    [int]$DurationSeconds = 60,
    [string]$OutputFile = "$PSScriptRoot\..\stats-output.csv"
)

Write-Host "Capturando stats por $DurationSeconds segundos... (Ctrl+C para parar antes)" -ForegroundColor Cyan
Write-Host "Arquivo de saída: $OutputFile" -ForegroundColor Cyan

"timestamp,container,cpu_pct,mem_usage_mb,mem_limit_mb,net_in_kb,net_out_kb" | Out-File $OutputFile -Encoding utf8

$end = (Get-Date).AddSeconds($DurationSeconds)

while ((Get-Date) -lt $end) {
    $ts = (Get-Date).ToString("HH:mm:ss")

    $lines = docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}}" 2>$null

    foreach ($line in $lines) {
        if (-not $line) { continue }
        $parts = $line -split ','

        if ($parts.Count -lt 4) { continue }

        $name    = $parts[0].Trim()
        $cpu     = ($parts[1] -replace '%','').Trim()

        # MemUsage: "384MiB / 768MiB"
        $memParts = $parts[2] -split '/'
        $memUsed  = ($memParts[0].Trim() -replace '[^0-9\.]','')
        $memLimit = if ($memParts.Count -gt 1) { ($memParts[1].Trim() -replace '[^0-9\.]','') } else { '0' }

        # NetIO: "1.2kB / 3.4kB"
        $netParts  = $parts[3] -split '/'
        $netIn  = ($netParts[0].Trim() -replace '[^0-9\.]','')
        $netOut = if ($netParts.Count -gt 1) { ($netParts[1].Trim() -replace '[^0-9\.]','') } else { '0' }

        "$ts,$name,$cpu,$memUsed,$memLimit,$netIn,$netOut" | Out-File $OutputFile -Append -Encoding utf8
    }

    Start-Sleep -Seconds 3
}

Write-Host "Captura concluída. Arquivo salvo em: $OutputFile" -ForegroundColor Green

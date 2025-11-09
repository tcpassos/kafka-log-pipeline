#!/bin/bash
set -euo pipefail

# Cria o arquivo de log no volume compartilhado
LOG_FILE="/var/log/app/app.log"
mkdir -p /var/log/app && touch "$LOG_FILE"

# Define identificadores do cliente/instalação (permite sobrescrever via env)
if [[ -z "${CLIENT_CODE:-}" ]]; then
  CLIENT_CODE=$(printf "%05d" $(( (RANDOM % 90000) + 10000 )))
fi

if [[ -z "${INSTALLATION_SEQ:-}" ]]; then
  INSTALLATION_SEQ=$(printf "%03d" $(( (RANDOM % 900) + 100 )))
fi

CLIENT_INSTALLATION="${CLIENT_CODE}-${INSTALLATION_SEQ}"

# Loop infinito que gera logs
while true; do
  TS=$(date -Iseconds)
  echo "$TS [main] INFO com.empresa.ClienteService - Cliente '${CLIENT_INSTALLATION}' logado com sucesso." >> "$LOG_FILE"

  if [[ $((RANDOM % 10)) -eq 0 ]]; then
    THREAD_ID=$((RANDOM % 5))
    echo "$TS [thread-${THREAD_ID}] ERROR com.empresa.FaturaService - Cliente '${CLIENT_INSTALLATION}' falhou ao processar fatura: java.lang.NullPointerException: Fatura não encontrada" >> "$LOG_FILE"
    echo "    at com.empresa.FaturaService.processar(FaturaService.java:42)" >> "$LOG_FILE"
    echo "    at com.empresa.FaturaController.post(FaturaController.java:88)" >> "$LOG_FILE"
    echo "    ... 8 more" >> "$LOG_FILE"
  fi

  sleep 2
done
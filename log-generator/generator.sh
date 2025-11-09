#!/bin/bash
# Cria o arquivo de log no volume compartilhado
LOG_FILE="/var/log/app/app.log"
mkdir -p /var/log/app && touch $LOG_FILE

# Loop infinito que gera logs
while true; do
  TS=$(date -Iseconds)
  echo "$TS [main] INFO com.empresa.ClienteService - Cliente 'ID-$(($RANDOM % 1000))' logado com sucesso." >> $LOG_FILE
  
  if [ $(($RANDOM % 10)) -eq 0 ]; then
    echo "$TS [thread-$(($RANDOM % 5))] ERROR com.empresa.FaturaService - java.lang.NullPointerException: Fatura não encontrada" >> $LOG_FILE
    echo "    at com.empresa.FaturaService.processar(FaturaService.java:42)" >> $LOG_FILE
    echo "    at com.empresa.FaturaController.post(FaturaController.java:88)" >> $LOG_FILE
    echo "    ... 8 more" >> $LOG_FILE
  fi
  
  sleep 2
done
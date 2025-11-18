# 📝 Guia: Como Adicionar Logs para Teste

## 📂 Onde Colocar os Logs

### Cliente 1
```
logs-siger-producer-filebeat\sample-logs-1\
```

### Cliente 2
```
logs-siger-producer-filebeat\sample-logs-2\
```

## 📄 Padrões de Nome de Arquivo

### Logs Normais → Topic: `logs_java_siger`
```
SIGER_*_*_[0-9]*_[0-9]*_*.*
```
**Exemplos:**
- `SIGER_APP_LOG_20241117_143000_001.log`
- `SIGER_SYSTEM_DEBUG_20241117_140000_002.log`

### Logs de Crash → Topic: `logs_java_sigercrashreport` (Alerta Discord!)
```
SigerCrashReport_*_*_[0-9]*_[0-9]*_*.*
```
**Exemplos:**
- `SigerCrashReport_APP_ERROR_20241117_143500_001.log`
- `SigerCrashReport_SYSTEM_FATAL_20241117_141000_002.log`

## 📝 Formato do Log

```
ABCD 123456 789012 2024-11-17 14:30:00,001 INFO  com.example.MyClass Mensagem do log
│    │      │       │                       │     │                   │
│    │      │       │                       │     │                   └─ Mensagem
│    │      │       │                       │     └─ Logger/Classe
│    │      │       │                       └─ Level (INFO/WARNING/SEVERE)
│    │      │       └─ Timestamp (YYYY-MM-DD HH:mm:ss,SSS)
│    │      └─ Thread ID
│    └─ Sequence
└─ Session ID
```

### Levels Suportados
- `INFO` - Informações normais
- `WARNING` - Avisos (processado, sem alerta)
- `SEVERE` - Erros críticos (⚠️ **Gera alerta no Discord para CrashReport!**)

### Exemplo com Exception (Multiline)
```
ABCD 123456 789012 2024-11-17 14:30:10,123 SEVERE com.siger.database.DatabaseService Erro crítico
java.sql.SQLException: Connection timeout
	at com.siger.database.ConnectionPool.getConnection(ConnectionPool.java:45)
	at com.siger.service.UserService.findUser(UserService.java:67)
Caused by: java.net.SocketTimeoutException: Read timed out
	at java.net.SocketInputStream.socketRead0(Native Method)
```

## 🔄 Como o Filebeat Detecta

- **Scan Frequency**: A cada 30 segundos
- **Encoding**: CP1252 (Windows)
- **Multiline**: Stack traces Java são agrupados automaticamente

## 🧪 Testando

### 1. Adicionar Log Novo
Copie ou crie um arquivo `.log` nas pastas sample-logs:
```powershell
# Exemplo: criar log manualmente
notepad logs-siger-producer-filebeat\sample-logs-1\SIGER_TEST_20241117_150000_001.log
```

### 2. Aguardar Processamento
- Filebeat: Detecta em ~30s
- Kafka: Armazena imediatamente
- Logstash: Processa e envia

### 3. Verificar Resultados

**Elasticsearch/Kibana** (`:5601`)
```
http://localhost:5601
```
- Vá em "Discover"
- Selecione o data stream `logs-java-siger`

**Discord** (apenas logs SEVERE do CrashReport)
- Verifique o canal configurado no webhook
- Alerta aparece em segundos!

**Kafka UI** (`:8090`)
```
http://localhost:8090
```
- Veja mensagens nos tópicos `logs_java_siger` e `logs_java_sigercrashreport`

## 📊 Logs de Exemplo Criados

Já criei 4 arquivos de exemplo para você testar:

### ✅ Cliente 1 - sample-logs-1/
1. `SIGER_APP_LOG_20241117_143000_001.log`
   - Logs INFO e WARNING normais
   - Vai para Elasticsearch

2. `SigerCrashReport_APP_ERROR_20241117_143500_001.log`
   - Contém 2 logs SEVERE com exceptions
   - 🚨 **Vai gerar 2 alertas no Discord!**

### ✅ Cliente 2 - sample-logs-2/
3. `SIGER_APP_LOG_20241117_140000_002.log`
   - Logs INFO e WARNING do cliente2
   - Vai para Elasticsearch

4. `SigerCrashReport_APP_ERROR_20241117_141000_002.log`
   - Contém 2 logs SEVERE (PaymentService e OutOfMemoryError)
   - 🚨 **Vai gerar 2 alertas no Discord!**

## 🎯 Dica: Adicionar Log em Tempo Real

Para simular logs sendo gerados continuamente:

### PowerShell
```powershell
while ($true) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss,fff"
    $log = "ABCD 123456 789012 $timestamp INFO com.siger.test.TestClass Log de teste gerado"
    Add-Content -Path "logs-siger-producer-filebeat\sample-logs-1\SIGER_REALTIME_$(Get-Date -Format 'yyyyMMdd_HHmmss')_001.log" -Value $log
    Start-Sleep -Seconds 5
}
```

### Bash/Linux
```bash
while true; do
  timestamp=$(date '+%Y-%m-%d %H:%M:%S,%3N')
  echo "ABCD 123456 789012 $timestamp INFO com.siger.test.TestClass Log de teste" >> logs-siger-producer-filebeat/sample-logs-1/SIGER_REALTIME_$(date +%Y%m%d_%H%M%S)_001.log
  sleep 5
done
```

## ⚠️ Importante

- **Encoding CP1252**: Se copiar de outro sistema, certifique-se do encoding correto
- **Clean Inactive**: Logs inativos por 72h são removidos da monitoração
- **Close Inactive**: Após 1min sem alteração, o arquivo é fechado
- **Apenas SEVERE no Discord**: Logs INFO/WARNING não geram alertas

## 🔍 Troubleshooting

### Logs não aparecem no Elasticsearch?
```powershell
# Verificar logs do Filebeat
docker logs -f filebeat-cliente1

# Verificar logs do Logstash
docker logs -f logstash-sink
```

### Alertas não chegam no Discord?
```powershell
# Verificar logs do Logstash Discord
docker logs -f logstash-discord

# Verificar se há logs SEVERE no CrashReport
docker exec -it broker kafka-console-consumer --bootstrap-server localhost:9092 --topic logs_java_sigercrashreport --from-beginning
```

### Verificar tópicos Kafka
- Acesse: http://localhost:8090
- Ou use CLI:
```powershell
docker exec -it broker kafka-topics --bootstrap-server localhost:9092 --list
```

## 📚 Referências

- Filebeat config: `logs-siger-producer-filebeat/filebeat.yml`
- Logstash ES pipeline: `logs-siger-consumer-es/logstash-sink/pipeline/logstash.conf`
- Logstash Discord pipeline: `logs-siger-consumer-discord/logstash-discord/pipeline/logstash.conf`

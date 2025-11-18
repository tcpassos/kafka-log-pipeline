# Discord Alert Consumer

Consumer Logstash que envia notificações para o Discord quando detecta logs SEVERE no tópico `logs_java_sigercrashreport`.

## 🎯 Funcionalidade

- **Topic Kafka**: `logs_java_sigercrashreport`
- **Filtro**: Apenas logs com `level = SEVERE`
- **Output**: Webhook do Discord
- **Consumer Group**: `logstash-discord-consumer`

## 📨 Formato da Notificação

Quando um log SEVERE é detectado, o bot envia uma mensagem no Discord contendo:

```
🚨 **ALERTA: Log SEVERE no SigerCrashReport**

**Cliente:** cliente1
**Timestamp:** 2024-11-17 10:30:45,123
**Logger:** com.example.MyClass
**Tipo de Erro:** java.lang.RuntimeException
**Mensagem:** Descrição do erro

**Log Completo:**
```
ABCD 123456 789012 2024-11-17 10:30:45,123 SEVERE com.example.MyClass ...
```
```

## 🚀 Como Usar

### Iniciar apenas este consumer
```bash
cd logs-siger-consumer-discord
docker compose up -d
```

### Ver logs
```bash
docker logs -f logstash-discord
```

### Parar
```bash
docker compose down
```

## ⚙️ Configuração

### Webhook do Discord

O webhook está configurado na variável de ambiente `DISCORD_WEBHOOK_URL` no `docker-compose.yml`:

```yaml
environment:
  DISCORD_WEBHOOK_URL: "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"
```

### Alterar o Webhook

1. Edite o arquivo `docker-compose.yml`
2. Substitua a URL do webhook
3. Reinicie o container: `docker compose restart`

### Customizar o Bot

No arquivo `logstash.conf`, você pode personalizar:

- **Username**: `"username" => "SIGER Alert Bot"`
- **Avatar**: `"avatar_url" => "URL_DA_IMAGEM"`
- **Filtros**: Modificar condições na seção `filter`
- **Formato**: Ajustar o campo `discord_message`

## 🔧 Pipeline Logstash

### Input
```ruby
kafka {
  bootstrap_servers => "${KAFKA_BOOTSTRAP}"
  topics => ["logs_java_sigercrashreport"]
  group_id => "logstash-discord-consumer"
  codec => json
}
```

### Filter
1. **GROK Parse**: Extrai campos estruturados do log
2. **Drop Filter**: Descarta logs que não são SEVERE
3. **Error Extraction**: Identifica tipo e mensagem de exceções
4. **Date Conversion**: Ajusta timezone
5. **Message Formatting**: Monta mensagem Discord formatada
6. **Message Truncation**: Limita tamanho em 500 caracteres

### Output
```ruby
http {
  url => "${DISCORD_WEBHOOK_URL}"
  http_method => "post"
  format => "json"
  content_type => "application/json"
  mapping => {
    "content" => "%{discord_message}"
    "username" => "SIGER Alert Bot"
    "avatar_url" => "https://cdn-icons-png.flaticon.com/512/2569/2569194.png"
  }
}
```

## 📊 Métricas

- **Memory Limit**: 512MB
- **Java Heap**: 256MB-256MB
- **Consumer Threads**: 1
- **Network**: kafka-cluster-network

## 🔍 Troubleshooting

### Webhook não está funcionando
1. Verifique se a URL do webhook está correta
2. Teste o webhook manualmente:
```bash
curl -X POST "https://discord.com/api/webhooks/YOUR_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d '{"content": "Teste de webhook"}'
```

### Logs não estão sendo enviados
1. Verifique se há logs SEVERE no tópico
2. Verifique os logs do container: `docker logs -f logstash-discord`
3. Verifique se o Kafka está acessível

### Mensagens duplicadas
- O consumer group `logstash-discord-consumer` garante processamento único
- Se reiniciar com `docker compose down -v`, o offset é perdido

## ⚠️ Limitações do Discord

- **Rate Limit**: 5 mensagens por 2 segundos por webhook
- **Tamanho**: Máximo 2000 caracteres por mensagem
- **Embeds**: Máximo 10 embeds por mensagem

O pipeline já limita mensagens em 500 caracteres para evitar problemas.

## 🎨 Customização Avançada

### Usar Discord Embeds

Edite o `output` no `logstash.conf` para usar embeds:

```ruby
output {
  http {
    url => "${DISCORD_WEBHOOK_URL}"
    http_method => "post"
    format => "json"
    content_type => "application/json"
    mapping => {
      "embeds" => [{
        "title" => "🚨 ALERTA: Log SEVERE"
        "description" => "%{discord_message}"
        "color" => "15158332"
        "timestamp" => "%{@timestamp}"
      }]
      "username" => "SIGER Alert Bot"
    }
  }
}
```

### Adicionar Filtros Adicionais

```ruby
filter {
  # Exemplo: apenas alertar se contém palavras específicas
  if [log.message_full] !~ /NullPointerException|OutOfMemoryError/ {
    drop { }
  }
}
```

## 📝 Notas

- Este consumer é **independente** do consumer Elasticsearch
- Ambos podem rodar simultaneamente consumindo do mesmo tópico
- Logs são processados em tempo real
- Ideal para alertas críticos que precisam atenção imediata

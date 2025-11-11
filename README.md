# Kafka Log Pipeline

Pipeline completo de observabilidade que processa logs Java e armazena em um data stream do Elasticsearch, com visualização no Kibana.

## Visão Geral

1. **Ingestão**: `logstash-ingest` lê arquivos de log diretamente de um diretório local (configurável via `LOGS_SOURCE_PATH`), processa multiline e publica no Kafka ([logstash-ingest/pipeline/logstash.conf](logstash-ingest/pipeline/logstash.conf)).
2. **Buffer**: `kafka` armazena os eventos para consumo assíncrono.
3. **Sink**: `logstash-sink` consome o tópico `logs_java_siger` e grava em data stream do Elasticsearch ([logstash-sink/pipeline/logstash.conf](logstash-sink/pipeline/logstash.conf)).
4. **Visualização**: `kibana` acessa os dados em tempo real.

```
Logs locais → Logstash (ingest) → Kafka → Logstash (sink) → Elasticsearch → Kibana
```

## Requisitos

- Docker Engine ≥ 20.10
- Docker Compose Plugin ≥ 2.20
- 4 GB de RAM livre (mínimo recomendado)

## Como Executar

1. **(Opcional) Configure o caminho dos logs:**

Crie um arquivo `.env` na raiz do projeto:
```env
LOGS_SOURCE_PATH=C:\meus-logs
```

2. **Suba a stack completa:**

```bash
docker compose up -d
```

Aguarde alguns segundos até que Elasticsearch e Kibana finalizem o bootstrap.

3. **Coloque seus arquivos de log** no diretório configurado (ex: `C:\temp-logs`). Os arquivos devem seguir o padrão de nomenclatura:
```
<TIPO>_<USUARIO>_<HOSTNAME>_<YYYYMMDD>_<HHMMSS>_<SESSION_ID>.[lL][oO][gG]
```
Exemplo: `SIGER_Passos_R93700-06-PAS_20251107_093150_6798.LOG`

### Acessos

- Kibana: http://localhost:5601
- Elasticsearch (API): http://localhost:9200
- Kafka Broker: `kafka:9092` na rede `log-pipeline`

## Estrutura das Pastas

| Caminho | Descrição |
| ------- | --------- |
| [log-generator/](log-generator/) | *(Deprecado)* Gerador de logs de exemplo. Não é mais usado na pipeline principal. |
| [logstash-ingest/](logstash-ingest/) | Pipeline Logstash que lê arquivos locais, processa multiline e publica no Kafka. |
| [logstash-sink/](logstash-sink/) | Pipeline Logstash que consome do Kafka e envia ao Elasticsearch. |

## Formato dos Logs

Os logs devem seguir o formato Java com os seguintes campos por linha:

```
<SSID> <SEQNUM> <THREAD> <YYYY-MM-DD HH:mm:ss,SSS> <LEVEL> <logger.name> <Mensagem>
```

Exemplo:
```
ABCD 123456 THREAD1 2025-11-07 09:31:50,679 INFO com.example.MyClass Aplicação iniciada
```

Stack traces multiline são automaticamente unificadas pelo codec multiline do Logstash.

## Encerrando

```bash
docker compose down
```

Para limpar os volumes persistentes:

```bash
docker compose down -v
```
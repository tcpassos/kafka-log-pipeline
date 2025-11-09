# Kafka Log Pipeline

Pipeline completo de observabilidade que gera logs fictícios, processa e armazena em um data stream do Elasticsearch, com visualização no Kibana.

## Visão Geral

1. **Geração**: serviço `log-generator` cria logs Java simulados em `/var/log/app/app.log`.
2. **Coleta**: `filebeat` lê os arquivos e unifica stack traces multiline ([filebeat/filebeat.yml](filebeat/filebeat.yml)).
3. **Ingestão**: `logstash-ingest` recebe eventos Beats e publica no Kafka ([logstash-ingest/pipeline/logstash.conf](logstash-ingest/pipeline/logstash.conf)).
4. **Buffer**: `kafka` armazena os eventos para consumo assíncrono.
5. **Sink**: `logstash-sink` consome o tópico e grava em data stream do Elasticsearch ([logstash-sink/pipeline/logstash.conf](logstash-sink/pipeline/logstash.conf)).
6. **Visualização**: `kibana` acessa os dados em tempo real.

```
log-generator → Filebeat → Logstash (ingest) → Kafka → Logstash (sink) → Elasticsearch → Kibana
```

## Requisitos

- Docker Engine ≥ 20.10
- Docker Compose Plugin ≥ 2.20
- 4 GB de RAM livre (mínimo recomendado)

## Como Executar

```bash
docker compose up -d
```

Aguarde alguns segundos até que Elasticsearch e Kibana finalizem o bootstrap.

### Acessos

- Kibana: http://localhost:5601
- Elasticsearch (API): http://localhost:9200
- Kafka Broker: `kafka:9092` na rede `log-pipeline`

## Estrutura das Pastas

| Caminho | Descrição |
| ------- | --------- |
| [log-generator/](log-generator/) | Contém o gerador de logs (`generator.sh`, [Dockerfile](log-generator/Dockerfile)). |
| [filebeat/](filebeat/) | Configuração do Filebeat com multiline e saída Logstash. |
| [logstash-ingest/](logstash-ingest/) | Pipeline Logstash que publica no Kafka. |
| [logstash-sink/](logstash-sink/) | Pipeline Logstash que consome do Kafka e envia ao Elasticsearch. |

## Encerrando

```bash
docker compose down
```

Para limpar os volumes persistentes:

```bash
docker compose down -v
```
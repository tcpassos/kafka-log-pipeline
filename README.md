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

1. Suba a stack central (Kafka, Logstash, Elasticsearch, Kibana):

```bash
docker compose up -d zookeeper kafka logstash-ingest logstash-sink elasticsearch kibana
```

2. Ative os clientes simulados desejados (cada perfil representa um par `log-generator`+`filebeat`):

```bash
docker compose --profile client-12345 --profile client-67890 up -d --build
```

Aguarde alguns segundos até que Elasticsearch e Kibana finalizem o bootstrap e que os clientes comecem a gerar eventos.

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

## Clientes simulados

- Perfil `client-12345`: `CLIENT_CODE=12345`, `INSTALLATION_SEQ=001`, `INSTALLATION_UID=client-12345-001`.
- Perfil `client-67890`: `CLIENT_CODE=67890`, `INSTALLATION_SEQ=002`, `INSTALLATION_UID=client-67890-002`.
- Cada cliente monta volumes dedicados (`log-data-<id>`, `filebeat-data-<id>`) e compartilha a mesma rede/cluster central.
- Para adicionar novos clientes, replique os serviços no `docker-compose.yml`, alterando envs, volumes e profiles (ex.: `client-ABCDE`).

Os eventos publicados carregam os campos `labels.client_code`, `labels.installation_seq` e `labels.installation_uid`, permitindo filtrar tanto por identificadores mutáveis quanto pelo identificador estável da instalação no Kibana.

## Encerrando

```bash
docker compose down
```

Para limpar os volumes persistentes:

```bash
docker compose down -v
```
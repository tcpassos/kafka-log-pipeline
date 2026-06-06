# Kafka Log Pipeline

Pipeline distribuído de processamento de logs Java usando Apache Kafka como backbone central de mensageria.

## 📊 Arquitetura

```mermaid
graph TB
    subgraph "ORIGEM DOS DADOS"
        L1[📄 Logs SIGER<br/>SIGER_*.log]
        L2[📄 Logs Crash<br/>SigerCrashReport_*.log]
    end

    subgraph "PRODUCER STACK - Coleta"
        FB[🔍 Filebeat Collector<br/>filebeat-collector<br/>varre todos os clientes]
    end

    subgraph "KAFKA CLUSTER - Mensageria"
        ZK[🔧 Zookeeper<br/>:2181]
        K1[📨 Broker 1<br/>:9092]
        K2[📨 Broker 2<br/>:9093]
        SR[📋 Schema Registry<br/>:8081]
        
        subgraph "Tópicos Kafka"
            T1[📬 Topic: logs_siger_java]
            T2[📬 Topic: logs_siger_crash]
        end
        
        UI1[🖥️ Kafka UI<br/>:8090]
        UI2[🖥️ Control Center<br/>:9021]
    end

    subgraph "CONSUMER STACK - Processamento"
        LS[⚙️ Logstash Sink<br/>Pipelines: siger-java + siger-crash<br/>Groups: logstash-elastic-siger-java<br/>logstash-elastic-siger-crash]
    end

    subgraph "ARMAZENAMENTO E VISUALIZAÇÃO"
        ES[🗄️ Elasticsearch<br/>:9200<br/>Data Stream: logs-java-siger]
        KB[📊 Kibana<br/>:5601]
    end

    L1 -->|Scan 10s| FB
    L2 -->|Scan 10s| FB

    FB -->|Produz| T1
    FB -->|Produz| T2

    ZK -.->|Coordena| K1
    ZK -.->|Coordena| K2
    K1 -->|Replicação| K2
    K1 -.-> T1
    K1 -.-> T2
    K2 -.-> T1
    K2 -.-> T2

    T1 -->|Consome| LS
    T2 -->|Consome| LS
    
    LS -->|Parse & Filter| ES

    ES -->|Visualiza| KB

    K1 -.->|Monitora| UI1
    K2 -.->|Monitora| UI1
    K1 -.->|Monitora| UI2
    K2 -.->|Monitora| UI2

    classDef producer fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef kafka fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef consumer fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef storage fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    classDef logs fill:#fff3e0,stroke:#e65100,stroke-width:2px

    class L1,L2 logs
    class FB producer
    class ZK,K1,K2,SR,T1,T2,UI1,UI2 kafka
    class LS consumer
    class ES,KB storage
```

## 🎯 Visão Geral

Sistema de coleta, transmissão e armazenamento de logs Java (SIGER) com arquitetura baseada em:
- **Filebeat**: Coleta de logs de múltiplos clientes
- **Kafka**: Mensageria distribuída com alta disponibilidade
- **Logstash**: Processamento e transformação de logs
- **Elasticsearch**: Armazenamento indexado
- **Kibana**: Visualização e análise

## 🚀 Início Rápido

### Iniciar o Pipeline Completo
```bash
cd scripts
start-stack.bat
```

### Parar o Pipeline
```bash
cd scripts
stop-stack.bat
```

## 📦 Componentes

### 1. Kafka Cluster (`kafka-cluster/`)
Infraestrutura central de mensageria com alta disponibilidade:

- **Zookeeper** (`:2181`) - Coordenação do cluster
- **2 Brokers Kafka** (`:9092`, `:9093`) - Cluster com replicação
  - Replication Factor: 2
  - Min In-Sync Replicas: 2
  - 6 partições por tópico
- **Schema Registry** (`:8081`) - Gerenciamento de schemas Avro
- **Kafka Connect** (`:8083`) - Framework para conectores
- **Control Center** (`:9021`) - Interface Confluent
- **Kafka UI** (`:8090`) - Interface web alternativa
- **REST Proxy** (`:8082`) - API REST

### 2. Producer Stack (`logs-siger-producer-filebeat/`)
Coleta de logs com **1 container Filebeat único** (single-ingestor) varrendo todos os clientes:

**Filebeat Instance:**
- `filebeat-collector` — monta `../logs:/usr/share/logs:ro` (raiz com todos os clientes)
- `client_id` e `sequence` extraídos via processor `dissect` em `log.file.path`
- Suporta `<client_id>/<sequence>/RLS/java/...` e `<client_id>/RLS/java/...` (fallback `sequence="default"`)

**Configuração de Inputs:**
- **siger-java**: Logs Java → Topic `logs_siger_java`
  - Paths: `/usr/share/logs/*/RLS/java/SIGER_*` e `/usr/share/logs/*/*/RLS/java/SIGER_*`
- **siger-crash**: Crash reports → Topic `logs_siger_crash`
  - Paths: `/usr/share/logs/*/RLS/java/SigerCrashReport_*` e `/usr/share/logs/*/*/RLS/java/SigerCrashReport_*`

**Características:**
- Encoding CP1252 (Windows)
- Multiline parsing para stack traces Java
- `scan_frequency: 10s`, `close.on_state_change.inactive: 5m`, `harvester_limit: 500`
- `queue.mem` 16384 eventos / flush 2048 → batch grande para Kafka
- Kafka output com `compression: lz4`, `bulk_max_size: 4096`
- Particionamento por `client_id` (hash) — preserva ordem por cliente

### 3. Consumer Stack

#### 3.1 Elasticsearch Consumer (`logs-siger-consumer-es/`)
Processamento e armazenamento de logs:

**Logstash Sink (pipelines paralelos via `pipelines.yml`):**
- Pipeline `siger-java`: consome `logs_siger_java` → data stream `logs-java.siger` (2 workers)
- Pipeline `siger-crash`: consome `logs_siger_crash` → data stream `logs-crash.siger` (1 worker)
- Consumer groups: `logstash-elastic-siger-java`, `logstash-elastic-siger-crash`

**Pipeline de Processamento:**
1. **GROK Parsing** - Extrai campos estruturados:
   - `log.session_id`, `log.sequence`, `log.thread_id`
   - `log.timestamp_str`, `log.level`, `log.logger`
   - `log.message_full`

2. **Error Extraction** - Para logs SEVERE/WARNING:
   - Identifica tipo de exceção (`error.type`)
   - Captura mensagens de erro
   - Detecta "Caused by" chains

3. **Date Conversion**:
   - Formato: `YYYY-MM-dd HH:mm:ss,SSS`
   - Timezone: America/Sao_Paulo

4. **Field Cleanup** - Remove campos temporários

**Elasticsearch** (`:9200`)
- Data Stream: `logs-java-siger`
- Namespace: `siger`
- Dataset: `java`

**Kibana** (`:5601`)
- Interface de visualização e análise

#### 3.2 Crash Reports
O mesmo `logstash-sink` consome o tópico `logs_siger_crash` no pipeline `siger-crash` e grava na data stream `logs-crash.siger`.

## 🔄 Fluxo de Dados

### Fluxo Principal (Elasticsearch)
```
[Arquivos SIGER_*] 
    ↓ Filebeat (scan 10s, CP1252, multiline, lz4, queue 8192)
[Kafka Topic: logs_siger_java]
    ↓ Logstash Pipeline `siger-java` (2 workers)
[Parse GROK → Extract Errors → Convert Dates → Cleanup]
    ↓ Elasticsearch Output
[Data Stream: logs-java.siger]
    ↓ Query API
[Kibana Dashboard]
```

### Fluxo de Crash
```
[Arquivos SigerCrashReport_*]
    ↓ Filebeat
[Kafka Topic: logs_siger_crash]
    ↓ Logstash Pipeline `siger-crash`
[Data Stream: logs-crash.siger]
```

## 📝 Formato de Log Esperado

```
ABCD 123456 789012 2024-11-17 10:30:45,123 INFO  com.example.MyClass Mensagem do log
ABCD 123456 789012 2024-11-17 10:30:46,456 SEVERE com.example.MyClass Erro!
java.lang.RuntimeException: Descrição do erro
    at com.example.MyClass.method(MyClass.java:42)
    at com.example.Main.main(Main.java:10)
Caused by: java.lang.NullPointerException
    at com.example.Helper.process(Helper.java:15)
```

## 🌐 Portas Expostas

| Serviço | Porta | Descrição |
|---------|-------|-----------|
| Kafka Broker 1 | 9092 | Kafka externo |
| Kafka Broker 2 | 9093 | Kafka externo (replica) |
| Zookeeper | 2181 | Coordenação do cluster |
| Schema Registry | 8081 | API de schemas |
| Kafka Connect | 8083 | API de conectores |
| REST Proxy | 8082 | Kafka REST API |
| Kafka UI | 8090 | Interface web |
| Control Center | 9021 | Confluent Control Center |
| Elasticsearch | 9200 | API Elasticsearch |
| Kibana | 5601 | Interface de visualização |

## 🎛️ Monitoramento

- **Kafka UI**: http://localhost:8090
- **Control Center**: http://localhost:9021
- **Kibana**: http://localhost:5601
- **Elasticsearch**: http://localhost:9200

## ⚙️ Configurações Importantes

### Kafka
- **Replication Factor**: 2
- **Min In-Sync Replicas**: 2
- **Partições**: 6 por tópico
- **Required ACKs**: 1 (Filebeat)

### Filebeat
- **Scan Frequency**: 30s
- **Close Inactive**: 1m
- **Clean Inactive**: 72h
- **Encoding**: CP1252

### Logstash
- **Memory**: 256MB-512MB
- **Codec**: JSON
- **Timezone**: America/Sao_Paulo

### Elasticsearch
- **Mode**: Single-node
- **Memory**: 512MB-1GB
- **Security**: Desabilitada (desenvolvimento)

## 📁 Estrutura do Projeto

```
kafka-log-pipeline/
├── kafka-cluster/                    # Cluster Kafka + ferramentas
│   └── docker-compose.yml
├── logs/                              # Logs SIGER organizados por cliente
│   ├── 2114/                          # Cliente 2114
│   └── 2398/                          # Cliente 2398
├── logs-siger-producer-filebeat/     # Coleta de logs (1 container single-ingestor)
│   ├── docker-compose.yml
│   └── filebeat.yml
├── logs-siger-consumer-es/           # Processamento e armazenamento
│   ├── docker-compose.yml
│   └── logstash-sink/
│       ├── config/
│       │   └── pipelines.yml         # Pipelines paralelos
│       └── pipeline/
│           ├── siger-java.conf
│           └── siger-crash.conf
└── scripts/
│       └── pipeline/
│           └── logstash.conf
└── scripts/                          # Scripts de automação
    ├── start-stack.bat
    └── stop-stack.bat
```

## 🔧 Troubleshooting

### Verificar status dos containers
```powershell
docker ps
```

### Ver logs de um serviço específico
```powershell
docker logs -f <container_name>
```

### Verificar tópicos Kafka
Acesse Kafka UI em http://localhost:8090

### Verificar índices Elasticsearch
```powershell
curl http://localhost:9200/_cat/indices?v
```

### Limpar volumes e recomeçar
```bash
cd scripts
stop-stack.bat
docker volume prune -f
start-stack.bat
```

## 🎯 Casos de Uso

- **Centralização de Logs**: Coleta de logs de múltiplos servidores/clientes
- **Análise em Tempo Real**: Processamento e indexação contínua
- **Troubleshooting**: Busca e análise de erros com Kibana
- **Auditoria**: Histórico completo de logs com timestamps precisos
- **Monitoramento**: Dashboards de métricas e alertas

## 📚 Tecnologias

- **Apache Kafka 7.5.0** (Confluent Platform)
- **Filebeat 8.11.1** (Elastic Beats)
- **Logstash 8.11.1** (Elastic Stack)
- **Elasticsearch 8.11.1** (Elastic Stack)
- **Kibana 8.11.1** (Elastic Stack)
- **Docker & Docker Compose**

## 🔒 Notas de Segurança

⚠️ **Atenção**: Esta configuração é para ambiente de **desenvolvimento**. Para produção:

- Habilitar autenticação no Elasticsearch
- Configurar TLS/SSL no Kafka
- Implementar controle de acesso (ACLs)
- Configurar backup dos volumes
- Ajustar limites de recursos
- Habilitar autenticação no Schema Registry e Connect

## 📄 Licença

Este projeto é um exemplo educacional/demonstrativo do sistema de logs SIGER.

# Roteiro do Vídeo — Docker Container Pipeline

**Duração alvo:** ~11:00 min  
**Projeto:** Pipeline de logs SIGER com Filebeat → Kafka → Logstash → Elasticsearch → Kibana  
**Foco:** Primitivas Docker — Compose, imagens, cgroups, namespaces, volumes, restart policy, healthcheck, escalabilidade

> **Nota de planejamento:** A apresentação total é de 20 min.
> Planejar ~9 min de slides (teoria) + ~11 min de vídeo integrado.

---

## Distribuição de Cenas

| Cena | Tema | Tempo | Conceito Docker |
|------|------|-------|-----------------|
| 0 | Introdução e topologia | 0:00 – 0:50 | Visão geral |
| 1 | Estrutura de configuração | 0:50 – 2:30 | Compose + imagens + bind mounts + camadas |
| 2 | Deploy e inspeção de namespaces | 2:30 – 4:00 | Namespaces de rede + PID + port mapping |
| 3 | Monitoramento e desempenho sob carga | 4:00 – 5:30 | cgroups + I/O de disco + comportamento sob carga |
| 4 | Restart policy e healthcheck | 5:30 – 6:45 | Restart policy + healthcheck |
| 5 | Named volumes e DNS interno | 6:45 – 7:45 | Named volumes + DNS Docker |
| 6 | Escalabilidade horizontal | 7:45 – 8:45 | docker compose --scale |
| 7 | Métricas de startup e conclusão | 8:45 – 10:45 | Avaliação de desempenho |

---

## Cena 0 — Introdução: O Problema e a Topologia (0:00 – 0:50)

**Tela:** imagem estática do diagrama abaixo (exportar como PNG)

```mermaid
graph LR
    HOST[/"Host\nd:/logs\nLog files SIGER"/]
    BROWSER(["Browser\nlocalhost:5601\nlocalhost:8090"])

    subgraph DOCKER["Docker Engine — 3 Compose stacks · 12 containers"]

        subgraph S1["logs-siger-producer-filebeat"]
            FB["filebeat-collector\nFilebeat 8.11"]
        end

        subgraph KNET["kafka-cluster-network  (bridge)"]
            subgraph S2["kafka-cluster"]
                direction TB
                ZK["zookeeper"]
                B1["broker\n:29092"]
                B2["broker2\n:29092"]
                ZK -. coordena .-> B1
                ZK -. coordena .-> B2
                B1 <-->|replica| B2
            end
            KUI["kafka-ui\n:8090"]
        end

        subgraph LNET["log-consumer-network  (bridge)"]
            subgraph S3["logs-siger-consumer-es"]
                direction TB
                LS["logstash-sink\nLogstash 8.11"]
                ES["elasticsearch\n:9200"]
                KB["kibana\n:5601"]
            end
        end

    end

    HOST   -- "bind mount :ro"  --> FB
    FB     -- "publica eventos" --> B1
    FB     -->                     B2
    B1     -- "consome"         --> LS
    B2     -->                     LS
    LS     -- "indexa (HTTP)"   --> ES
    ES     -->                     KB
    KB     -->                     BROWSER
    KUI    -->                     BROWSER

    style DOCKER fill:#f0f0f8,stroke:#3949ab,stroke-width:2px,color:#000
    style KNET   fill:#d4edda,stroke:#2e7d32,stroke-width:1.5px,stroke-dasharray:5 3,color:#000
    style LNET   fill:#cce5ff,stroke:#1565c0,stroke-width:1.5px,stroke-dasharray:5 3,color:#000
    style S1     fill:#ffecd0,stroke:#b34700,color:#000
    style S2     fill:#c3e6cb,stroke:#1b5e20,color:#000
    style S3     fill:#b8daff,stroke:#003f7f,color:#000
    style HOST   fill:#ffffff,stroke:#555,color:#000
    style BROWSER fill:#ffffff,stroke:#555,color:#000
    style FB     fill:#ffffff,stroke:#b34700,color:#000
    style ZK     fill:#ffffff,stroke:#1b5e20,color:#000
    style B1     fill:#ffffff,stroke:#1b5e20,color:#000
    style B2     fill:#ffffff,stroke:#1b5e20,color:#000
    style KUI    fill:#ffffff,stroke:#1b5e20,color:#000
    style LS     fill:#ffffff,stroke:#003f7f,color:#000
    style ES     fill:#ffffff,stroke:#003f7f,color:#000
    style KB     fill:#ffffff,stroke:#003f7f,color:#000
```

**Narração:**

> "O sistema que vamos demonstrar é um pipeline de coleta e análise de logs em produção.
> O SIGER é um sistema Java utilizado por múltiplos clientes, cada um gerando arquivos de
> log continuamente no servidor.
>
> Nossa solução conecta quatro componentes em cadeia: o **Filebeat** lê os arquivos e publica
> no **Kafka**. O **Logstash** consome, parseia e indexa no **Elasticsearch**. O **Kibana**
> fecha com visualização em tempo real. São 12 containers orquestrados pelo Docker Compose
> em três stacks independentes — e vamos começar pelo que define tudo isso: os arquivos
> de configuração."

---

## Cena 1 — Estrutura de Configuração: Compose e Imagens (0:50 – 2:30)

**Tela inicial:** VS Code com o Explorer lateral aberto na pasta `kafka-log-pipeline`.  
Recolha todos os arquivos abertos — só a árvore de pastas deve estar visível.

---

### BLOCO A — Os três stacks (~0:50)

**Ação:** Mostre a árvore de pastas sem abrir nada ainda.

> *Fala:* "O projeto é dividido em três stacks independentes, cada um com seu próprio
> arquivo Compose. O `kafka-cluster` é o backbone: ele cria a rede e sobe os brokers.
> Os outros dois — o consumer e o producer — se conectam a essa infraestrutura sem
> precisar conhecer os detalhes internos dela."

---

### BLOCO B — A rede bridge e o `external: true` (~1:00)

**Ação:** Abra [kafka-cluster/docker-compose.yml](../kafka-cluster/docker-compose.yml).
Role direto para o **final** do arquivo. Ignore os serviços por enquanto — foque só no bloco `networks`:

```yaml
networks:
  kafka-cluster-network:
    driver: bridge
    name: kafka-cluster-network
```

> *Fala:* "O driver `bridge` cria uma interface de rede virtual isolada no host. Todos os
> containers conectados a ela se enxergam pelo nome, mas são invisíveis para qualquer
> outro processo fora dessa rede. O campo `name` fixa o nome da rede — sem ele o Docker
> usaria um prefixo automático e os outros Compose files não conseguiriam referenciar ela."

**Ação:** Agora abra [logs-siger-consumer-es/docker-compose.yml](../logs-siger-consumer-es/docker-compose.yml).
Role até o final, bloco `networks`:

```yaml
networks:
  kafka-cluster-network:
    external: true
    name: kafka-cluster-network
```

> *Fala:* "`external: true` diz ao Docker: essa rede já existe, não a crie, apenas conecte
> meus containers a ela. Se o kafka-cluster não estiver rodando quando esse stack subir,
> o Docker retorna erro — o que é o comportamento correto, porque sem a rede os serviços
> não teriam como se comunicar."

---

### BLOCO C — Anatomia completa do serviço Elasticsearch (~1:20)

**Ação:** No mesmo arquivo `logs-siger-consumer-es/docker-compose.yml`, role para o topo
e abra o serviço `elasticsearch`. Percorra cada campo devagar, pausando 2-3 segundos em cada um:

```yaml
elasticsearch:
  image: docker.elastic.co/elasticsearch/elasticsearch:8.11.1
```
> *Fala:* "A imagem vem de um registry externo — o Docker faz o pull automaticamente
> se não existir localmente."

```yaml
  networks:
    - log-consumer-network
```
> *Fala:* "Qual namespace de rede esse container habita. Só containers na mesma rede
> conseguem resolver esse nome."

```yaml
  volumes:
    - es-data:/usr/share/elasticsearch/data
```
> *Fala:* "Volume nomeado — o Docker gerencia onde os dados ficam no host. O container
> pode ser destruído e recriado que os índices persistem. Vamos provar isso na Cena 5."

```yaml
  mem_limit: 1300m
```
> *Fala:* "Limite de memória traduzido diretamente para um cgroup do kernel Linux.
> Não é uma checagem do Docker em userspace — é o kernel que impede qualquer alocação
> acima desse teto. Vamos ver esse número aparecer no `/sys/fs/cgroup` mais à frente."

```yaml
  restart: unless-stopped
```
> *Fala:* "Política de recuperação. O daemon reinicia o container em qualquer falha,
> mas respeita um `docker stop` intencional do operador."

```yaml
  healthcheck:
    test: ["CMD-SHELL", "curl -fsS http://localhost:9200/_cluster/health >/dev/null"]
    interval: 20s
    retries: 5
```
> *Fala:* "O critério de 'saudável' não é o container existir — é esse comando sair com
> exit code zero. O curl com `-f` retorna erro se o HTTP status for 4xx ou 5xx.
> Outros serviços que dependem do ES via `depends_on` só sobem depois desse check passar."

---

### BLOCO D — Bind mounts vs named volumes no Filebeat (~1:55)

**Ação:** Abra [logs-siger-producer-filebeat/docker-compose.yml](../logs-siger-producer-filebeat/docker-compose.yml).
Destaque o bloco `volumes` do serviço `filebeat-collector`:

```yaml
volumes:
  - ../logs:/usr/share/logs:ro
  - ./filebeat.yml:/config/filebeat.yml:ro
  - filebeat-collector-data:/usr/share/filebeat/data
```

> *Fala:* "As duas primeiras linhas são bind mounts: um caminho real do host mapeado
> dentro do container. O Filebeat lê os arquivos de log do SIGER diretamente do sistema
> de arquivos da máquina. A flag `:ro` — read only — impede qualquer escrita acidental
> dentro do container no diretório do host."
>
> "A terceira linha é diferente: `filebeat-collector-data` é um named volume. O Docker
> decide onde armazenar no host. Aqui o Filebeat guarda o offset de leitura — a posição
> até onde já leu em cada arquivo. Se esse volume for deletado, o Filebeat perde o estado
> e reprocessa tudo desde o início — e é exatamente isso que vamos fazer na Cena 3 para
> gerar o burst de carga."

---

### BLOCO E — Imagens e camadas no terminal (~2:10)

**Ação:** Abra o terminal integrado do VS Code (`Ctrl + '`). Execute:

```powershell
docker image ls --format "table {{.Repository}}`t{{.Tag}}`t{{.Size}}"
```

> *Fala:* "O Elasticsearch pesa 1,4 GB porque carrega uma JVM completa. O Filebeat tem
> 323 MB — é um agente leve, sem runtime pesado. Essas imagens são os artefatos imutáveis
> que o Compose vai instanciar como containers."

Execute:

```powershell
docker image history docker.elastic.co/elasticsearch/elasticsearch:8.11.1
```

> *Fala:* "Cada linha aqui é uma instrução do Dockerfile original que gerou essa imagem —
> empilhadas em um union filesystem. Quando dois containers compartilham camadas iguais,
> como a base Debian, o Docker armazena uma única vez no disco. Isso é o que torna os
> containers tão mais leves que máquinas virtuais: a imagem não é um disco inteiro,
> é um conjunto de deltas reutilizáveis."

---

### Ao terminar a Cena 1

**Pause a gravação.** Antes de gravar a Cena 2 execute:

```powershell
cd c:\dev\kafka-log-pipeline
.\scripts\stop-stack.bat
```

A Cena 2 começa com o stack derrubado para mostrar o deploy do zero.

---

## Cena 2 — Deploy e Inspeção de Namespaces (2:30 – 4:00)

**Tela inicial:** terminal integrado do VS Code, diretório `c:\dev\kafka-log-pipeline`.  
**Pré-requisito:** stack derrubado com `stop-stack.bat` ao final da Cena 1.

---

### BLOCO A — Deploy do stack (~2:30)

**Ação:** Execute o script de start e deixe o output aparecer na tela enquanto fala:

```powershell
.\scripts\start-stack.bat
```

O output vai mostrar os três stacks subindo em sequência. Aguarde terminar (~5 segundos para o script retornar, containers continuam inicializando em background).

> *Fala:* "Com um único comando subimos os três stacks em ordem. O Compose processa
> o `kafka-cluster` primeiro — ele cria a rede `kafka-cluster-network`. Só depois sobe
> o consumer stack, que encontra a rede já existente e conecta seus containers a ela.
> Por último o Filebeat, que também precisa da rede Kafka para publicar eventos."

**Ação:** Liste os containers em execução:

```powershell
docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Image}}"
```

> *Fala:* "Doze containers, três stacks, um único comando. Cada linha aqui é um processo
> isolado rodando no kernel do host — sem nenhum sistema operacional convidado."

---

### BLOCO B — Namespaces de rede: dois espaços de endereçamento (~2:55)

**Ação:** Liste as redes Docker:

```powershell
docker network ls
```

> *Fala:* "O Docker criou duas redes bridge para este projeto. Cada rede é um namespace
> de rede isolado no kernel — interfaces, endereços IP e rotas próprias, completamente
> separados entre si e do host."

**Ação:** Inspecione a rede do Kafka:

```powershell
docker network inspect kafka-cluster-network `
  --format "{{range .Containers}}{{.Name}} -> {{.IPv4Address}}{{println}}{{end}}"
```

> *Fala:* "Na `kafka-cluster-network` estão o Zookeeper, os dois brokers e o Kafka-UI —
> cada um com seu próprio IP dentro desse namespace."

**Ação:** Inspecione a rede do consumer:

```powershell
docker network inspect log-consumer-network `
  --format "{{range .Containers}}{{.Name}} -> {{.IPv4Address}}{{println}}{{end}}"
```

> *Fala:* "Na `log-consumer-network` estão o Elasticsearch e o Kibana. Perceba que o
> Logstash aparece nas **duas** listas — ele tem uma interface em cada namespace, porque
> precisa consumir do Kafka e escrever no Elasticsearch ao mesmo tempo."

---

### BLOCO C — Prova de isolamento entre redes (~3:20)

**Ação:** Tente alcançar o Elasticsearch a partir do broker:

```powershell
docker exec broker bash -c "timeout 2 bash -c 'cat /dev/null > /dev/tcp/elasticsearch/9200' 2>&1 && echo 'CONECTADO' || echo 'INACESSIVEL: elasticsearch nao existe neste namespace de rede'"
```

O comando vai retornar `INACESSIVEL`.

> *Fala:* "O broker não consegue alcançar o `elasticsearch` — não porque há um firewall,
> mas porque esse hostname simplesmente não existe dentro do namespace de rede do Kafka.
> O DNS interno do Docker só resolve nomes de containers que estão na mesma rede.
> Dois processos na mesma máquina física, completamente invisíveis um para o outro."

---

### BLOCO D — Port mapping: o namespace aberto para o host (~3:35)

**Ação:** Mostre o mapeamento de portas de todos os containers:

```powershell
docker ps --format "table {{.Names}}`t{{.Ports}}"
```

Aponte três linhas específicas no output:

| O que apontar | Por que é relevante |
|---|---|
| `kibana: 0.0.0.0:5601->5601/tcp` | porta interna = porta externa |
| `elasticsearch: 0.0.0.0:9200->9200/tcp` | idem |
| `kafka-ui: 0.0.0.0:8090->8080/tcp` | **porta interna diferente da externa** |

> *Fala:* "O mapeamento de portas é o namespace sendo seletivamente aberto para o host
> via NAT. O Kibana escuta na 5601 dentro do namespace, e o Docker cria uma regra que
> redireciona qualquer conexão externa à 5601 do host para dentro do container.
> O Kafka-UI é o exemplo mais claro: a aplicação escuta na 8080 internamente, mas
> decidimos expor como 8090 no host. Sem esse mapeamento no Compose, o container
> seria completamente invisível para qualquer processo fora do namespace."

---

### BLOCO E — Namespace de PID: processos isolados (~3:48)

**Ação:** Liste os processos dentro do container do Elasticsearch:

```powershell
docker exec elasticsearch ps aux
```

> *Fala:* "Dentro do container, `ps aux` mostra apenas a JVM do Elasticsearch como
> PID 1, seguido das threads internas dela. O container não enxerga nenhum dos outros
> onze containers rodando na mesma máquina — é a ilusão completa de isolamento que
> o namespace de PID cria."

**Ação:** Mostre o PID real de cada container no host:

```powershell
docker ps -q | ForEach-Object { docker inspect $_ --format "{{.Name}}: PID {{.State.Pid}}" }
```

> *Fala:* "Do lado do host, cada container é simplesmente um processo com seu próprio
> PID. O mesmo processo que se vê como PID 1 lá dentro tem um número completamente
> diferente aqui fora. Dois sistemas de numeração paralelos, independentes, sem
> nenhuma virtualização de hardware — só primitivas do kernel Linux."

---

### Ao terminar a Cena 2

**Não derrube o stack** — a Cena 3 usa o pipeline já rodando para gerar o burst de carga.  
Deixe os containers rodando e me avise para detalhar a Cena 3.

---

## Cena 3 — Monitoramento e Desempenho sob Carga (4:00 – 5:30)

**Tela inicial:** janela dividida — Kibana (`localhost:5601`) na esquerda, terminal na direita.  
**Pré-requisito:** stack rodando desde a Cena 2. Kibana com a Data View `logs-java-siger` aberta no Discover.

---

### BLOCO A — Gerar o burst de carga (~4:00)

O Filebeat guarda um offset de leitura em seu volume de estado. Ao apagar esse volume,
ele perde o registro e reprocessa todos os arquivos do zero — gerando um burst imediato no pipeline.

**Ação:** Execute os três comandos em sequência:

```powershell
docker stop filebeat-collector
```

> *Fala:* "Vamos forçar uma situação de carga real. O Filebeat armazena um registro de
> até onde leu em cada arquivo de log — o offset de leitura — dentro de um named volume.
> Vamos apagar esse volume."

```powershell
docker volume rm logs-siger-producer-filebeat_filebeat-collector-data
```

> *Fala:* "Volume removido. O Filebeat não tem mais nenhum estado salvo."

```powershell
docker compose -f c:\dev\kafka-log-pipeline\logs-siger-producer-filebeat\docker-compose.yml up -d
```

> *Fala:* "Ao subir de novo sem o volume, o Filebeat trata todos os arquivos como novos
> e envia tudo de uma vez ao Kafka. Os brokers recebem uma rajada — e o Logstash começa
> a processar um batch massivo."

**Aguarde ~15 segundos** para o pipeline começar a fluir antes do próximo bloco.

---

### BLOCO B — Observar métricas com docker stats (~4:20)

**Ação:** Execute e deixe o output atualizar na tela enquanto narra. Não pressione Ctrl+C ainda.

```powershell
docker stats --format "table {{.Name}}`t{{.CPUPerc}}`t{{.MemUsage}}`t{{.NetIO}}`t{{.BlockIO}}"
```

O output atualiza a cada 2 segundos. Aponte cada linha enquanto fala:

**1 — Elasticsearch memória (linha mais importante):**

> *Fala:* "O ponto mais impactante está aqui: o Elasticsearch está com **1,27 GiB de 1,27 GiB**
> — praticamente no teto exato do cgroup declarado no Compose com `mem_limit: 1300m`.
> O processo está usando todo o heap disponível sem conseguir ultrapassar. O kernel
> bloquearia qualquer alocação adicional acima desse limite."

**2 — Elasticsearch CPU e BLOCK I/O:**

> *Fala:* "CPU acima de 40% e o BLOCK I/O crescendo — é o Elasticsearch escrevendo os
> índices Lucene em disco, passando pelo namespace de mount do container até o volume
> gerenciado pelo Docker no host."

**3 — Logstash memória:**

> *Fala:* "O Logstash está em ~543 MiB dos 768 permitidos — 71% do limite. Essa folga
> é intencional: o Logstash precisa de espaço para absorver picos de parsing de stack
> traces Java sem ser interrompido pelo kernel."

**Ação:** Pressione `Ctrl+C` para parar o stats.

---

### BLOCO C — Provar o cgroup diretamente no kernel (~5:00)

**Ação:** Execute dentro do container do Elasticsearch:

```powershell
docker exec elasticsearch cat /sys/fs/cgroup/memory.max
```

O output será o número `1363148800`.

> *Fala:* "Esse número é 1.363.148.800 bytes — exatamente 1300 megabytes. O Docker
> traduziu `mem_limit: 1300m` do arquivo Compose em uma entrada no subsistema
> cgroup v2 do kernel Linux. Não é uma checagem do Docker em userspace: é o próprio
> kernel que aplica essa restrição. Qualquer `malloc` que o processo tente acima
> desse valor é bloqueado diretamente pelo kernel, sem que a aplicação perceba de onde
> veio a restrição."

---

### BLOCO D — Inspecionar os mounts do container (~5:15)

**Ação:** Inspecione os volumes montados no Filebeat — ele tem os dois tipos lado a lado:

```powershell
docker inspect filebeat-collector `
  --format "{{range .Mounts}}{{.Type}} | {{.Source}} -> {{.Destination}}{{println}}{{end}}"
```

O output mostrará três linhas:

```
bind  | C:\dev\kafka-log-pipeline\logs -> /usr/share/logs
bind  | C:\dev\kafka-log-pipeline\logs-siger-producer-filebeat\filebeat.yml -> /config/filebeat.yml
volume | /var/lib/docker/volumes/.../_data -> /usr/share/filebeat/data
```

> *Fala:* "O `inspect` revela os dois tipos de mount lado a lado. As entradas `bind`
> são caminhos reais do host mapeados dentro do namespace de mount do container —
> o Filebeat lê os logs do SIGER diretamente do sistema de arquivos da máquina.
> A entrada `volume` é o named volume gerenciado pelo Docker: o caminho interno no
> host é opaco para a aplicação, mas o Docker garante que persiste independente
> do ciclo de vida do container. Foi exatamente esse volume que apagamos para
> gerar o burst."

---

### Ao terminar a Cena 3

**Não derrube o stack.** A Cena 4 usa o Logstash e o Kafka-UI rodando.  
Abra `localhost:8090` no browser e navegue até a aba **Consumer Groups** antes de gravar a Cena 4.

---

## Cena 4 — Restart Policy e Healthcheck (5:30 – 6:45)

**Tela inicial:** Kafka-UI (`localhost:8090`) na aba **Consumer Groups** na esquerda, terminal na direita.  
**Pré-requisito:** Consumer group `logstash` visível com 1 membro ativo consumindo partições.

> **ATENÇÃO:** Após o `kill` o Logstash reinicia em ~3-5 segundos. Tenha o Kafka-UI visível
> **antes** de executar o kill — a janela para ver o lag crescer é curta.

---

### BLOCO A — Identificar o container e confirmar a restart policy (~5:30)

**Ação:** Execute em sequência:

```powershell
docker ps --filter "name=logstash" --format "{{.Names}}"
```

O output será `logs-siger-consumer-es-logstash-sink-1`.

> *Fala:* "O Logstash está rodando com um nome gerado automaticamente pelo Compose —
> projeto, serviço e índice. Isso é intencional: sem um `container_name` fixo no YAML,
> o Compose consegue criar múltiplas instâncias numeradas do mesmo serviço.
> Com nome fixo, só poderia existir uma."

```powershell
docker inspect logs-siger-consumer-es-logstash-sink-1 `
  --format "RestartPolicy: {{.HostConfig.RestartPolicy.Name}}"
```

> *Fala:* "O `inspect` confirma a restart policy declarada no Compose: `unless-stopped`.
> Isso é uma instrução direta ao Docker daemon — reinicie o container sempre que ele
> terminar com um código de saída diferente de zero, mas respeite quando um operador
> para intencionalmente com `docker stop`."

---

### BLOCO B — Demonstrar crash+restart com container standalone (~5:50)

Containers gerenciados pelo Compose têm um "desired state" próprio que pode conflitar com
a restart policy do daemon. Para demonstrar o restart automático por crash de forma
**confiável e limpa**, use um container standalone — sem interferência da camada Compose.

**Ação 1 — Criar um container que crashea sozinho após 3 segundos:**

```powershell
docker run -d --restart unless-stopped --name restart-demo alpine sh -c "echo iniciando; sleep 3; exit 1"
```

> *Fala:* "Criamos um container standalone com a mesma política `unless-stopped`.
> Ele vai imprimir uma mensagem, esperar 3 segundos e encerrar com exit code 1 —
> simulando uma falha da aplicação."

**Ação 2 — Observar o ciclo crash → restart (aguarde ~4 segundos):**

```powershell
docker ps -a --filter name=restart-demo --format "{{.Names}}: {{.Status}}"
# → restart-demo: Exited (1) 1 second ago

# Aguarde mais 2 segundos e execute novamente:
docker ps -a --filter name=restart-demo --format "{{.Names}}: {{.Status}} — RestartCount: {{.RunningFor}}"
# → restart-demo: Up 1 second
```

> *Fala:* "Exit code 1 — o daemon avalia a política. `unless-stopped`: saída foi falha,
> não foi um stop intencional — reinicia. O container voltou automaticamente sem nenhuma
> intervenção. O Kafka-UI mostra o mesmo comportamento para o Logstash: quando o processo
> falha em produção, o daemon detecta o exit code diferente de zero e reinicia o container
> na rede interna, sem que os outros serviços precisem ser notificados."

**Ação 3 — Mostrar o restart count e limpar:**

```powershell
docker inspect restart-demo --format "RestartCount: {{.RestartCount}}"
# → RestartCount: 2  (ou mais, dependendo de quantos ciclos passaram)

docker rm -f restart-demo
```

> *Fala:* "O `RestartCount` registra quantas vezes o daemon reiniciou esse container.
> O Docker aplica um backoff exponencial entre restarts — espera 100ms, depois 200ms,
> 400ms — para não sobrecarregar o sistema em caso de falha persistente."

---

### BLOCO C — Healthcheck: exit codes, não HTTP (~6:20)

**Ação:** Mostre o status de saúde e a configuração do healthcheck:

```powershell
docker inspect elasticsearch --format "{{.State.Health.Status}}"
# → healthy
```

> *Fala:* "O healthcheck não funciona com protocolos — ele funciona com exit codes.
> O daemon executa o comando configurado dentro do container em intervalos regulares.
> Se o comando retorna zero: healthy. Se retorna qualquer valor diferente de zero: unhealthy."

```powershell
docker inspect elasticsearch `
  --format "Cmd: {{index .Config.Healthcheck.Test 1}}"
```

> *Fala:* "O comando do healthcheck usa `curl -f` — a flag `-f` instrui o curl a retornar
> exit code diferente de zero quando o servidor responde com HTTP 4xx ou 5xx. Sem o `-f`,
> o curl retorna zero mesmo com erro HTTP, e o daemon nunca saberia que o serviço está
> com problema. O `curl -f` traduz a resposta HTTP em exit code para o daemon interpretar."

---

### BLOCO D — Provar o `unless` de `unless-stopped`: parada intencional não reinicia (~6:35)

Este é o ponto central da política — o que a diferencia de `always`. Mostre o Kafka-UI
**antes** de parar o Logstash para o lag aparecer durante a pausa.

**Ação 1 — Pare o Logstash com `docker stop`:**

```powershell
docker stop logs-siger-consumer-es-logstash-sink-1
```

> *Fala:* "`docker stop` envia SIGTERM — o processo tem chance de fazer cleanup e encerra
> com exit code zero, indicando parada limpa. O daemon avalia: exit code zero, política
> `unless-stopped` — não reinicia. O operador parou intencionalmente."

**Ação 2 — Confirmar que fica parado (aguarde 10 segundos e verifique):**

```powershell
docker ps -a --filter "name=logstash" --format "{{.Names}}: {{.Status}}"
# → logs-siger-consumer-es-logstash-sink-1: Exited (0) 10 seconds ago
```

> *Fala:* "Dez segundos depois — continua parado. Com `restart: always`, o daemon teria
> reiniciado imediatamente. O `unless-stopped` respeita a intenção do operador.
> No Kafka-UI o lag do consumer group está crescendo: os eventos continuam chegando
> pelo Filebeat, mas não há consumidor ativo para drenar as partições."

**Ação 3 — Volte a subir e observe o lag caindo:**

```powershell
docker compose -f c:\dev\kafka-log-pipeline\logs-siger-consumer-es\docker-compose.yml up -d logstash-sink
```

> *Fala:* "Ao subir novamente, o Logstash retoma do offset salvo no Kafka e começa
> a drenar o backlog acumulado. O lag no Kafka-UI cai."

---

### Ao terminar a Cena 4

**Não derrube o stack.** A Cena 5 mata o Elasticsearch e observa o Logstash e o volume.  
Abra `localhost:5601` (Kibana Discover) no browser antes de gravar — você vai recarregar a página durante a cena.

---

## Cena 5 — Named Volumes e DNS Interno (6:45 – 7:45)

**Tela inicial:** Kibana (`localhost:5601`) na esquerda, terminal na direita.  
**Pré-requisito:** Logstash ativo, Kibana mostrando documentos no Discover.

---

### BLOCO A — Kill no Elasticsearch: o Logstash sobrevive (~6:45)

**Ação 1 — Kill no Elasticsearch:**

```powershell
docker kill elasticsearch
```

> *Fala:* "Vamos destruir o container do Elasticsearch abruptamente — sem aviso, sem
> graceful shutdown. O que acontece com o Logstash, que depende dele para indexar?"

**Ação 2 — Mostrar o Logstash registrando erros mas continuando:**

```powershell
docker logs logs-siger-consumer-es-logstash-sink-1 --tail 10
# → Connection refused to elasticsearch:9200
# → Retrying connection...
```

> *Fala:* "O Logstash registra falha de conexão, mas não encerra. Ele continua tentando
> `elasticsearch:9200` em loop. Isso funciona porque `elasticsearch` não é um IP fixo —
> é um nome DNS resolvido pelo DNS interno da rede Docker. O registro DNS do container
> persiste na rede enquanto o serviço está declarado no Compose, mesmo com o container
> parado. Quando o Elasticsearch voltar, o mesmo nome resolverá para o novo IP."

**Ação 3 — Confirmar exit code 137:**

```powershell
docker ps -a --filter name=elasticsearch --format "{{.Names}}: {{.Status}}"
# → elasticsearch: Exited (137) X seconds ago
```

> *Fala:* "137 de novo — SIGKILL. O container está destruído. Mas o volume de dados
> não está."

---

### BLOCO B — Volume intacto após destruição do container (~7:05)

**Ação:** Inspecione o volume `es-data`:

```powershell
docker volume inspect es-data --format "Mountpoint: {{.Mountpoint}}"
```

O output mostrará o caminho no host (dentro da VM WSL2).

> *Fala:* "O volume `es-data` existe independente do container que o usava. O filesystem
> do container foi destruído com o `docker kill`, mas o Mountpoint no host permanece
> intacto — os índices do Elasticsearch estão lá, exatamente como foram escritos."

```powershell
docker volume ls --filter name=es-data
```

> *Fala:* "Note que o nome `es-data` é exato — sem prefixo de projeto. Isso porque no
> Compose declaramos `name: es-data` explicitamente. Volumes sem esse campo recebem o
> prefixo automático do projeto, como vimos com o volume do Filebeat."

---

### BLOCO C — Reiniciar o ES, Logstash reconecta, Kibana mostra o pico (~7:20)

**Ação 1 — Subir somente o Elasticsearch:**

```powershell
docker compose -f c:\dev\kafka-log-pipeline\logs-siger-consumer-es\docker-compose.yml up -d elasticsearch
```

> *Fala:* "Subimos apenas o Elasticsearch. O Logstash não foi tocado — ele continuou
> tentando reconectar durante toda a interrupção."

**Ação 2 — Aguardar healthcheck e confirmar DNS via Logstash:**

```powershell
docker inspect elasticsearch --format "Health: {{.State.Health.Status}}"
# → Health: healthy
```

```powershell
docker exec logs-siger-consumer-es-logstash-sink-1 curl -s http://elasticsearch:9200/_cluster/health
# → {"status":"green",...}
```

> *Fala:* "O healthcheck passou — `healthy`. E o Logstash consegue resolver
> `elasticsearch:9200` de dentro do seu próprio container. O DNS interno do Docker
> atualizou o registro assim que o novo container subiu. Do ponto de vista do Logstash,
> foi uma reconexão normal."

**Ação 3 — Recarregar o Kibana e apontar o pico no gráfico:**

Recarregue `localhost:5601` → Discover → observe o histograma de eventos.

> *Fala:* "O Kibana confirma: todos os eventos que se acumularam no Kafka durante a
> interrupção foram indexados assim que o Logstash reconectou. O pico no gráfico é
> o backlog sendo drenado de uma vez.
>
> O isolamento entre ciclo de vida do container e ciclo de vida dos dados é exatamente
> isso: você pode destruir e recriar o container quantas vezes precisar — os dados
> no volume permanecem intactos, e o DNS interno garante que os outros serviços
> reconectam pelo nome, sem precisar saber o IP do novo container."

---

### Ao terminar a Cena 5

**Não derrube o stack.** A Cena 6 escala o Logstash horizontalmente.  
Abra `localhost:8090` (Kafka-UI) na aba **Consumer Groups** antes de gravar a Cena 6.

---

## Cena 6 — Escalabilidade Horizontal (7:45 – 8:45)

**Tela inicial:** Kafka-UI (`localhost:8090`) na aba **Consumer Groups** na esquerda, terminal na direita.  
**Pré-requisito:** 1 consumer ativo no grupo `logstash`, consumindo as 6 partições do tópico.

---

### BLOCO A — Confirmar baseline: 1 consumer, 6 partições (~7:45)

No Kafka-UI, clique no consumer group do Logstash. Mostre na tela:

> *Fala:* "Uma instância do Logstash consumindo todas as 6 partições do tópico. O Kafka
> distribui as mensagens entre as partições para paralelismo — mas só há um consumidor
> para processar todas elas. Se o volume de logs aumentar, esse único container será
> o gargalo."

**Ação:** Confirme no terminal:

```powershell
docker ps --filter "name=logstash" --format "{{.Names}}: {{.Status}}"
# → logs-siger-consumer-es-logstash-sink-1: Up X minutes
```

> *Fala:* "Uma instância. Sem nenhuma mudança nos arquivos YAML, vamos escalar
> horizontalmente com um único parâmetro do Compose."

---

### BLOCO B — Escalar para 2 instâncias (~8:00)

**Ação:**

```powershell
docker compose -f c:\dev\kafka-log-pipeline\logs-siger-consumer-es\docker-compose.yml `
  up -d --scale logstash-sink=2 --no-recreate
```

> *Fala:* "`--scale logstash-sink=2` instrui o Compose a manter duas instâncias desse
> serviço. O Docker sobe um segundo container com a mesma imagem, conectado às mesmas
> redes, com a mesma configuração. `--no-recreate` garante que o primeiro container
> não seja destruído e recriado — apenas o segundo é adicionado."

**Ação:** Confirme os dois containers:

```powershell
docker ps --filter "name=logstash" --format "table {{.Names}}`t{{.Status}}"
# → logs-siger-consumer-es-logstash-sink-1   Up X minutes
# → logs-siger-consumer-es-logstash-sink-2   Up X seconds
```

> *Fala:* "Note os nomes: índice 1 e índice 2. É por isso que o serviço não pode ter
> `container_name` fixo no Compose — com nome fixo, o Docker recusaria criar a segunda
> instância por conflito de nome."

---

### BLOCO C — Mostrar redistribuição de partições no Kafka-UI (~8:15)

Volte ao Kafka-UI → aba Consumer Groups → clique no grupo do Logstash.

> *Fala:* "O Kafka detectou o novo consumer no grupo e disparou um rebalanceamento de
> partições automaticamente. Em vez de uma instância processar todas as 6 partições,
> agora cada uma ficou com 3. O throughput de indexação no Elasticsearch dobrou
> proporcionalmente — sem nenhuma reconfiguração do cluster Kafka, sem restart de
> serviços."

Aponte na tela as duas linhas de consumer, cada uma com 3 partições atribuídas.

---

### BLOCO D — Escalar de volta para 1 (~8:35)

**Ação:**

```powershell
docker compose -f c:\dev\kafka-log-pipeline\logs-siger-consumer-es\docker-compose.yml `
  up -d --scale logstash-sink=1 --no-recreate
```

```powershell
docker ps --filter "name=logstash" --format "{{.Names}}: {{.Status}}"
# → logs-siger-consumer-es-logstash-sink-1: Up X minutes
```

> *Fala:* "Reduzimos de volta para 1. O Kafka rebalanceou novamente — as 6 partições
> voltaram para o consumidor restante. Em produção, esse mesmo parâmetro é gerenciado
> por orquestradores como Kubernetes, que escalam baseado em métricas de lag do consumer
> group ou CPU — sem intervenção manual."

---

### Ao terminar a Cena 6

O stack pode continuar rodando para a Cena 7, mas você vai precisar exibir os números
de startup que foram **pré-medidos**. Abra o arquivo `video\startup-results.txt` em um
editor ou tenha o terminal com o output salvo pronto para mostrar.

---

## Cena 7 — Métricas de Startup e Conclusão (8:45 – 10:45)

**Tela inicial:** terminal mostrando o conteúdo do `startup-results.txt` (ou a saída pré-salva
do `measure-startup.ps1`).  
**Pré-requisito:** os números já medidos antes da gravação — não execute o script ao vivo, pois
leva 75+ segundos de espera.

---

### BLOCO A — Startup times: medir pelo healthcheck, não pelo container (~8:45)

**Ação:** Mostre o resumo de startup no terminal:

```powershell
Get-Content c:\dev\kafka-log-pipeline\video\startup-results.txt
```

O output mostrará:

```
SEGUNDA EXECUÇÃO — cache quente (usar para slide e Cena 7)
  Kafka Cluster :   5.2 s
  Elasticsearch :  24.1 s
  Kibana        :  63.4 s
  Filebeat      :   6.8 s
  TOTAL         :  75.4 s
```

> *Fala:* "Medimos o tempo de startup pelo critério correto: não quando o container
> existe no `docker ps`, mas quando o **healthcheck passa** — quando o serviço está
> de fato pronto para receber conexões. Um container pode estar `Up` por 10 segundos
> e ainda estar inicializando internamente."

Aponte para cada linha enquanto comenta:

> *Fala:* "O Kafka sobe em 5 segundos — é um processo Java leve esperando conexões
> de broker. O Elasticsearch leva 24 — ele inicializa índices, abre shards, verifica
> integridade do volume. O Kibana é o mais lento com 63 segundos — ele aguarda o
> Elasticsearch estar healthy antes de completar o próprio startup. Total: 75 segundos
> para 12 containers com isolamento completo de rede, limites de recurso e persistência
> de dados."

---

### BLOCO B — Conectar os números aos conceitos demonstrados (~9:15)

**Ação:** Mostre as métricas de pico do burst:

```powershell
Get-Content c:\dev\kafka-log-pipeline\video\startup-results.txt | Select-Object -Last 5
```

```
MÉTRICAS DE PICO (burst — stats-burst-peak.csv)
  Logstash CPU pico    :  12.1 %
  Logstash MEM         : 543 MiB / 768 MiB  (71% do teto do cgroup)
  Elasticsearch CPU    :  44.6 %
  Elasticsearch MEM    : 1.268 GiB / 1.27 GiB  (99.8% do teto do cgroup)
```

> *Fala:* "Esses números conectam tudo que demonstramos. O Elasticsearch chegou a
> 99.8% do limite de memória — o cgroup do kernel impediu que o processo ultrapassasse
> 1,3 GB mesmo com carga total. Sem esse limite, o Elasticsearch poderia consumir toda
> a RAM do host e derrubar os outros containers. O Logstash ficou em 71% — folga
> intencional para absorver bursts de parsing sem pressionar o teto."

---

### BLOCO C — Union filesystem: camadas de imagem (~9:40)

**Ação:** Mostre as camadas da imagem do Elasticsearch:

```powershell
docker image history elasticsearch:8.11.1 --format "table {{.CreatedBy}}`t{{.Size}}" | Select-Object -First 8
```

> *Fala:* "O sistema de arquivos em camadas é a terceira primitiva do kernel que o
> Docker usa. Cada linha é uma camada imutável — o resultado de um comando no
> Dockerfile. Quando subimos dois containers da mesma imagem, como os dois Logstash
> da cena anterior, eles **compartilham todas essas camadas em leitura**. Cada container
> tem apenas uma camada de escrita própria, no topo. É por isso que subir uma segunda
> instância é instantâneo — não há cópia de imagem, apenas uma nova camada de escrita."

**Ação:** Confirme o driver de union filesystem:

```powershell
docker inspect elasticsearch --format "GraphDriver: {{.GraphDriver.Name}}"
# → GraphDriver: overlay2
```

> *Fala:* "`overlay2` — o driver de union filesystem do kernel Linux usado pelo Docker.
> É ele que empilha as camadas somente-leitura da imagem com a camada de escrita
> do container, apresentando um único sistema de arquivos unificado para o processo."

---

### BLOCO D — Fechamento: três primitivas, três arquivos, 75 segundos (~10:10)

**Ação:** Mostre os três arquivos Compose lado a lado:

```powershell
Get-ChildItem c:\dev\kafka-log-pipeline -Recurse -Filter "docker-compose.yml" |
  Select-Object DirectoryName
```

> *Fala:* "Três arquivos YAML. Toda a infraestrutura que demonstramos — 12 serviços,
> duas redes bridge com isolamento entre elas, volumes nomeados com persistência
> independente do container, limites de recurso aplicados pelo kernel, restart
> automático por política declarativa, escalabilidade horizontal sem reconfiguração
> — está descrita nesses três arquivos e sobe em 75 segundos numa única máquina."

Pausa curta, olhe para a câmera:

> *Fala:* "O Docker não inventa nada novo no kernel. Ele organiza três primitivas que
> já existiam no Linux: **namespaces** para isolar a visibilidade entre processos —
> cada container enxerga apenas sua própria rede, seu próprio filesystem, seus
> próprios processos. **cgroups** para limitar quanto de CPU e memória cada processo
> pode consumir — o kernel aplica os limites diretamente, sem intermediário.
> E o **sistema de arquivos em camadas** para separar a imagem imutável compartilhada
> do estado mutável de cada instância.
>
> O Compose é a camada declarativa que orquestra essas três primitivas em arquivos
> legíveis, versionáveis e reproduzíveis — sem exigir configuração manual de cada
> namespace, cada cgroup ou cada mount. É isso que torna possível descrever uma
> pipeline de dados de produção em menos de 200 linhas de YAML."

---

## Checklist de Preparação (antes de gravar)

- [ ] **[OBRIGATÓRIO]** Rodar `.\scripts\setup-demo-logs.ps1` para criar o diretório `logs/` com a estrutura esperada pelo Filebeat (bind mount `../logs`)
- [ ] Verificar `KAFKA_ADVERTISED_HOST_IP` em `kafka-cluster/.env` (valor atual: `192.168.1.5` — atualizar se o IP do host mudou)
- [ ] Subir o stack e configurar Kibana Discover com o índice `logs-java-siger` (salvar a view)
- [ ] Deixar logs fluindo por ~3 minutos antes de gravar a Cena 3
- [ ] Abrir Kafka-UI (`localhost:8090`) na aba Consumer Groups antes da Cena 4
- [ ] **[CENA 4]** Ter o Kafka-UI aberto e visível ANTES do `kill` — o auto-restart acontece em ~3-5s, a janela para ver o lag crescer é curta
- [ ] **Pré-executar** `.\scripts\measure-startup.ps1` com o stack derrubado e salvar o output para reproduzir na Cena 7
- [ ] Resetar volume de estado do Filebeat antes da Cena 3 para gerar burst de carga:
      `docker stop filebeat-collector && docker volume rm logs-siger-producer-filebeat_filebeat-collector-data`
- [ ] **Pré-executar** `.\scripts\capture-stats.ps1 -DurationSeconds 60` durante o burst e salvar CSV para slides
- [ ] Fazer dry-run completo sem gravar para ajustar timings da narração

---

## Conceitos Docker Cobertos

| Primitiva Docker | Onde aparece | Tópico da disciplina |
|------------------|-------------|----------------------|
| Compose declarativo | Anatomia do serviço ES campo por campo — Cena 1 | Arquiteturas Virtualizadas |
| Imagens de registry + camadas | `docker image ls` + `docker image history` — Cena 1 | Arquiteturas Virtualizadas |
| Union filesystem (camadas) | `docker image history elasticsearch` — Cena 1 | Hierarquia de Memória |
| Bind mounts vs named volumes | Filebeat compose com ambos os tipos lado a lado — Cena 1 | Arquiteturas Virtualizadas |
| Redes externas entre stacks | `external: true` nos três compose files — Cena 1 | Virtualização de Rede |
| Namespaces de rede | `docker network inspect` + teste de conectividade — Cena 2 | Arquiteturas Virtualizadas |
| Namespace de PID | `docker exec ps aux` (vê só seus processos) vs PID real no host — Cena 2 | Arquiteturas Virtualizadas |
| Port mapping (NAT namespace→host) | `docker ps --format Ports` + Kafka-UI porta 8090→8080 — Cena 2 | Virtualização de Rede |
| cgroups (memória) | `mem_limit` no Compose + `docker stats` — Cenas 1 e 3 | Arquiteturas Virtualizadas |
| cgroups no kernel | `cat /sys/fs/cgroup/memory.max` — Cena 3 | Hierarquia de Memória |
| cgroups (memlock) | `ulimits.memlock: -1` + `bootstrap.memory_lock` — Cena 1 | Hierarquia de Memória |
| Multi-network routing | Logstash com duas interfaces, ES sem acesso ao Kafka — Cena 2 | Virtualização de Rede |
| Named volumes | `es-data` persiste após `docker kill` — Cenas 3 e 5 | Hierarquia de Memória |
| Restart policy | `unless-stopped` + exit code 137 + auto-restart — Cena 4 | Tolerância a Falhas |
| Healthcheck | `curl` no ES + `depends_on` controlando startup — Cenas 1 e 4 | Avaliação de Desempenho |
| DNS interno Docker | `elasticsearch:9200` resolvido após restart — Cena 5 | Virtualização de Rede |
| Startup performance | `measure-startup.ps1` aguardando healthchecks — Cena 7 | Avaliação de Desempenho |

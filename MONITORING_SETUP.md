# Prometheus e Grafana - Setup e Queries para Morea IoT

## Deploy do Monitoring Stack

### Pré-requisito
O Traefik e stack principal (morea) já devem estar rodando.

### Deploy
No fog-manager:

```bash
cd /path/to/morea-ds-web

# Deploy stack de monitoramento
docker stack deploy -c docker-stack-monitoring.yml monitoring

# Verificar
docker stack ps monitoring
docker service ls | grep monitoring
```

Saída esperada:
```
ID          NAME                      IMAGE                      STATUS
abc123      monitoring_prometheus     prom/prometheus:latest     Running
def456      monitoring_grafana        grafana/grafana:latest     Running
ghi789      monitoring_cadvisor       gcr.io/cadvisor/cadvisor   Running
...         monitoring_node-exporter  prom/node-exporter         Running (global mode, em cada node)
```

### Acessar serviços

- **Prometheus**: http://192.168.1.80:9090 (ou https://prometheus.seu-dominio.com se Traefik usar HTTPS)
- **Grafana**: http://192.168.1.80:3000 (ou https://grafana.seu-dominio.com)
- **cAdvisor**: http://192.168.1.80:8081

## Configuração do Prometheus

### Arquivo de configuração
O arquivo `prometheus/prometheus.yml` já está configurado com:
- **Node Exporter**: coleta métricas do SO (CPU, RAM, disco)
- **cAdvisor**: métricas de containers Docker
- **Django**: endpoint `/metrics` da aplicação (se habilitado)
- **Service Discovery**: auto-descobre services do Swarm

### Queries úteis do Prometheus

Acessar: http://localhost:9090/graph

#### 1. **CPU por node**
```promql
node_cpu_seconds_total{mode="system"}
```

#### 2. **Memória disponível (%)**
```promql
100 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100)
```

#### 3. **Disco usado (%)**
```promql
100 - (node_filesystem_avail_bytes{fstype="ext4"} / node_filesystem_size_bytes{fstype="ext4"} * 100)
```

#### 4. **Containers rodando**
```promql
count(container_last_seen)
```

#### 5. **CPU do container morea_web**
```promql
rate(container_cpu_usage_seconds_total{name=~".*morea.*"}[5m])
```

#### 6. **Memória do container morea_web (MB)**
```promql
container_memory_working_set_bytes{name=~".*morea.*"} / 1024 / 1024
```

#### 7. **Taxa de requisições (se prometheus_requests_total em Django)**
```promql
rate(django_http_requests_total[5m])
```

## Configuração do Grafana

### Login padrão
- URL: http://192.168.1.80:3000
- Email/User: `admin`
- Senha: valor de `GRAFANA_ADMIN_PASSWORD` no `.env` (padrão: `admin`)

### Primeiro acesso - trocar senha
1. Login com admin/admin
2. Menu (canto inferior esquerdo) → Settings → Users
3. Seu perfil → Change password

### Adicionar Data Source (Prometheus)

1. Menu (canto esquerdo) → Connections → Data Sources
2. Clique "Add new data source"
3. Selecionar "Prometheus"
4. Configurar:
   - **Name**: Morea Prometheus
   - **URL**: http://prometheus:9090 (usar nome do service Swarm)
   - **Access**: Server (default)
   - Clique "Save & Test"

### Criar Dashboard

#### Opção 1: Usar template pré-existente
1. Menu → Dashboards → Browse
2. Procurar por "Node Exporter" ou "Docker"
3. Importar um dashboard existente

#### Opção 2: Criar dashboard customizado

1. Menu → Dashboards → Create Dashboard → Add panel
2. Selecionar data source: "Morea Prometheus"
3. Adicionar queries (exemplos abaixo)
4. Salvar dashboard como "Morea IoT Monitoring"

### Exemplos de Panels

#### Panel 1: CPU por Node (Gauge)
- **Title**: CPU Usage (%)
- **Query**:
  ```promql
  100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance) * 100)
  ```
- **Type**: Gauge
- **Threshold**: 0-50 (green), 50-80 (yellow), 80-100 (red)

#### Panel 2: RAM Livre (Timeseries)
- **Title**: Memory Available
- **Query**:
  ```promql
  node_memory_MemAvailable_bytes / 1024 / 1024 / 1024
  ```
- **Type**: Time series
- **Unit**: GB

#### Panel 3: Disco Usado (Gauge)
- **Title**: Disk Usage (%)
- **Query**:
  ```promql
  100 - (node_filesystem_avail_bytes{fstype="ext4"} / node_filesystem_size_bytes{fstype="ext4"} * 100)
  ```
- **Type**: Gauge

#### Panel 4: Containers rodando (Stat)
- **Title**: Running Containers
- **Query**:
  ```promql
  count(container_last_seen)
  ```
- **Type**: Stat

#### Panel 5: Requisições HTTP (Rate)
- **Title**: Requests/sec
- **Query**:
  ```promql
  rate(container_network_receive_bytes_total{name=~".*morea.*"}[1m])
  ```
- **Type**: Time series

#### Panel 6: Data colhida (se implementar métrica customizada em Django)
- **Title**: IoT Data Points Received
- **Query**:
  ```promql
  rate(django_morea_data_points_total[5m])
  ```

## Alertas (opcional)

### Criar regra de alerta no Grafana
1. Dashboard → Alert rules → New alert rule
2. Exemplo: CPU > 80%
   ```promql
   avg(rate(node_cpu_seconds_total{mode!="idle"}[5m])) > 0.8
   ```
3. Configurar notificação (email, Slack, webhook)

## Integração com Portainer

Se estiver usando Portainer (já instalado):
- URL: http://192.168.1.80:9000
- Portainer não interfere com Prometheus/Grafana
- Você pode monitorar Swarm tanto via Portainer quanto via Grafana

## Exportar/Importar dashboards

### Exportar
1. Dashboard → Menu (canto superior direito) → Export
2. Salvar JSON

### Importar
1. Dashboard → Import
2. Colar JSON ou fazer upload do arquivo
3. Selecionar data source

## Problemas comuns

### "No data" no Prometheus
1. Verificar se targets estão acessíveis:
   - http://192.168.1.80:9090/targets
2. Se mostra "DOWN", verificar:
   ```bash
   docker service logs monitoring_prometheus -f
   ```

### Grafana não vê Prometheus
1. Verificar data source:
   - http://192.168.1.80:3000/connections/datasources
2. Testar conexão ("Test connection" button)
3. Verificar logs:
   ```bash
   docker service logs monitoring_grafana -f
   ```

### cAdvisor não coleta métricas
1. Verificar se está rodando:
   ```bash
   docker service logs monitoring_cadvisor -f
   ```
2. Se erro de permissão, verificar volumes em docker-stack-monitoring.yml

## Próximos passos

1. **Custom metrics em Django**: implementar prometheus_client para rastrear dados de IoT colhidos
2. **Alertas**: configurar notificações para CPU/RAM críticos
3. **Backup de dashboards**: exportar JSONs regularmente
4. **Logs centralizados**: integrar ELK ou Loki para logs agregados

## Exemplo: Adicionar métrica customizada ao Django

No `app/views.py`, ao receber POST em `/api/store-data`:

```python
from prometheus_client import Counter, Histogram

# Métricas
data_points_received = Counter('morea_data_points_received', 'Total data points received', ['device_type'])
data_store_duration = Histogram('morea_data_store_duration_seconds', 'Time to store data')

@api_view(['POST'])
def storeData(request):
    # ... código existente ...
    
    with data_store_duration.time():
        # guardar dados
        for i in measure:
            device = Device.objects.get(api_token=apiToken)
            data_points_received.labels(device_type=device.get_type_display()).inc()
            # ... rest of code ...
```

Depois expor em `/metrics`:

```python
from prometheus_client import generate_latest
from django.http import HttpResponse

def prometheus_metrics(request):
    return HttpResponse(generate_latest(), content_type='text/plain')

# Em urls.py:
# path('metrics', prometheus_metrics)
```

---

**Diagrama final:**

```
┌──────────────────────────────────────────────────────┐
│           Monitoring Stack (Swarm)                   │
│  ┌────────────────────────────────────────────────┐  │
│  │ Prometheus (9090)                              │  │
│  │ - Coleta métricas de Node Exporter, cAdvisor  │  │
│  │ - Armazena em TSDB                            │  │
│  └────────────────────────────────────────────────┘  │
│            ↓                                          │
│  ┌────────────────────────────────────────────────┐  │
│  │ Grafana (3000)                                 │  │
│  │ - Visualiza dashboards                        │  │
│  │ - Define alertas                              │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  cAdvisor (8081) - Cada node                        │
│  Node Exporter (9100) - Cada node                   │
└──────────────────────────────────────────────────────┘
        ↓ (metrics)
┌──────────────────────────────────────────────────────┐
│           Morea IoT Stack                            │
│  - Django Web (8000)                                 │
│  - Traefik (80, 443)                                 │
│  - Portainer (9000)                                  │
└──────────────────────────────────────────────────────┘
```


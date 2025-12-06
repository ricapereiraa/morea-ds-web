# Monitoring IoT - Guia Prático Rápido

## Setup rápido (5 minutos)

### 1. Deploy da stack
```bash
cd /path/to/morea-ds-web

# Deploy
docker stack deploy -c docker-stack-monitoring.yml monitoring

# Verificar
docker stack ps monitoring
```

### 2. Acessar
- **Prometheus**: http://192.168.1.80:9090
- **Grafana**: http://192.168.1.80:3000 (admin/admin por padrão)

### 3. Configurar Grafana

#### 3.1 Adicionar Data Source Prometheus
1. Login em Grafana
2. Menu (canto esquerdo) → **Connections** → **Data Sources**
3. **Add new data source**
4. Selecione **Prometheus**
5. Configure:
   - **Name**: Morea Prometheus
   - **URL**: http://prometheus:9090
   - Clique **Save & Test**

#### 3.2 Criar Dashboard
1. Menu → **Dashboards** → **Create Dashboard** → **Add panel**
2. Selecionar data source "Morea Prometheus"
3. Adicionar as queries abaixo
4. Clique **Save dashboard**

## Queries práticas (copiar-colar em Grafana)

### CPU % por node
```promql
100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance))
```

### RAM disponível (%)
```promql
100 * (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
```

### Disco usado (%)
```promql
100 * (1 - node_filesystem_avail_bytes{fstype="ext4"} / node_filesystem_size_bytes{fstype="ext4"})
```

### Containers ativos
```promql
count(container_last_seen{id!="/"})
```

### Requisições HTTP/seg (se implementar metrics em Django)
```promql
rate(morea_data_points_received_total[1m])
```

### Latência de armazenamento (ms)
```promql
morea_data_store_duration_seconds_bucket{le="0.1"} * 1000
```

## Adicionar métricas customizadas do Morea

### Passo 1: Instalar prometheus-client
```bash
# Já adicionado em requirements.txt
pip install prometheus-client==0.19.0
```

### Passo 2: Implementar métricas (opção simplificada)

Editar `app/views.py` e adicionar ao storeData():

```python
from app.metrics import track_data_received, track_store_duration
import time

@api_view(['POST'])
def storeData(request):
    # ... código existente ...
    
    start = time.time()
    
    # ... guardar dados ...
    
    # Rastrear
    track_data_received(device_type, measure_type)
    track_store_duration(device_type, time.time() - start)
    
    return Response({'message': 'data stored.'}, status=status.HTTP_200_OK)
```

### Passo 3: Expor endpoint /metrics
Adicionar em `app/urls.py`:

```python
from django.http import Response
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST

def prometheus_metrics(request):
    return Response(
        generate_latest(),
        content_type=CONTENT_TYPE_LATEST
    )

urlpatterns = [
    # ... urls existentes ...
    path('metrics', prometheus_metrics),
]
```

### Passo 4: Configurar Prometheus para ler metrics do Django

Editar `prometheus/prometheus.yml` e adicionar:

```yaml
scrape_configs:
  - job_name: 'django'
    static_configs:
      - targets: ['morea_web:8000']
    metrics_path: '/metrics'
    scrape_interval: 30s
```

Recarregar configuração do Prometheus:
```bash
# Fazer um POST no endpoint de reload
curl -X POST http://192.168.1.80:9090/-/reload
```

## Dashboards prontos para importar

### Node Exporter Dashboard
1. Dashboard → Import
2. ID: 1860 (Node Exporter Full)
3. Select Prometheus data source
4. Import

### Docker Dashboard
1. Dashboard → Import
2. ID: 14981 (cAdvisor Docker)
3. Select Prometheus data source
4. Import

## Alertas básicos

### Criar alerta de CPU alta
1. Dashboard → Alert rules → New alert rule
2. Condition:
   ```promql
   100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance)) > 80
   ```
3. Set notification (email, Slack, webhook)

### Criar alerta de RAM baixa
```promql
100 * (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 20
```

## Visualizações recomendadas

### Panel 1: Status dos nodes (Stat)
- Query: `up{job="node-exporter"}`
- Type: Stat
- Show: Last

### Panel 2: Distribuição de CPU (Pie Chart)
- Query: `100 * (1 - avg(...) by (instance))`
- Type: Pie chart

### Panel 3: Timeline de containers (Time series)
- Query: `count(container_last_seen) by (instance)`
- Type: Time series

### Panel 4: Taxa de dados colhidos (Bar gauge)
- Query: `rate(morea_data_points_received_total[5m])`
- Type: Bar gauge

### Panel 5: Volume total água/gás (Stat)
- Query: `morea_total_data_volume_liters{device_type="Water"}`
- Type: Stat (big number)

### Panel 6: Energia consumida (Stat)
- Query: `morea_total_energy_consumed_kwh{device_type="Energy"}`
- Type: Stat

## Exportar dados

### Prometheus query diretamente
```bash
curl 'http://192.168.1.80:9090/api/v1/query?query=<PromQL>'
```

Exemplo:
```bash
curl 'http://192.168.1.80:9090/api/v1/query?query=morea_data_points_received_total' | jq
```

### Grafana dashboard export (JSON)
1. Dashboard → Menu → Export
2. Salvar JSON
3. Compartilhar ou fazer backup

## Performance e otimização

### Retenção de dados Prometheus
Editar `docker-stack-monitoring.yml`:
```yaml
command:
  - '--storage.tsdb.retention.time=30d'  # 30 dias
```

### Reduzir scrape interval em desenvolvimento
Em `prometheus/prometheus.yml`:
```yaml
global:
  scrape_interval: 5s  # Mais frequente para ver mudanças rápidas
```

## Troubleshooting

### Prometheus targets estão DOWN
1. Verificar: http://192.168.1.80:9090/targets
2. Se mostra erro, logs: `docker service logs monitoring_prometheus -f`
3. Testar conectividade: `docker exec -it <prometheus-container> ping <target>`

### Grafana não conecta ao Prometheus
1. Data Sources → Test → se falhar, verificar logs:
   ```bash
   docker service logs monitoring_grafana -f
   ```
2. Tentar usar `http://prometheus:9090` (nome do service) em vez de IP

### cAdvisor não coleta métricas
```bash
docker service logs monitoring_cadvisor -f
# Se erro de permissão, verificar volumes em docker-stack-monitoring.yml
```

## Checklist de setup

- [ ] Stack monitoring deployado (`docker stack ps monitoring`)
- [ ] Prometheus acessível em :9090
- [ ] Grafana acessível em :3000
- [ ] Data source Prometheus adicionado em Grafana
- [ ] Dashboard importado ou criado
- [ ] Métricas customizadas do Morea implementadas (opcional)
- [ ] Endpoint `/metrics` do Django funcionando (optional)
- [ ] Alertas configurados (optional)

## Próximos passos

1. **Loki + Promtail**: agregar logs dos containers
2. **Alertmanager**: gerenciar alertas complexos
3. **Backup de dados**: exportar e arquivar dados históricos
4. **Webhooks**: enviar alertas para Slack/Teams

---

**Dúvidas?** Verifique logs: `docker service logs monitoring_<service> -f`

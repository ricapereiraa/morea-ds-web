# Morea IoT Data Collection - Docker Swarm Deployment Guide

## Visão geral da arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                   Fog Network (Swarm)                       │
│                   192.168.1.80 (Manager)                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Docker Swarm Manager                                 │   │
│  │ - Traefik (reverse proxy + HTTPS)                    │   │
│  │ - Morea Web Service (Django)                         │   │
│  └──────────────────────────────────────────────────────┘   │
│                         │                                    │
│  Networks:              │                                    │
│  - fog-network (overlay)│ (internal swarm)                   │
│  - morea-network ← ─ ─ ┼─── (overlay, bridge to IoT net)   │
└─────────────────────────────────────────────────────────────┘
                          │
         ┌────────────────┴────────────────┐
         │                                 │
    Ponte de Rede (VXLAN ou DHCP route)   │
         │                                 │
┌────────▼──────────────────────────────────────────────┐
│           Morea Network (IoT Devices)                │
│           192.168.1.122 (Host IP)                    │
│                                                      │
│  ┌─────────────────┐  ┌──────────────┐              │
│  │ Water Sensor    │  │ Gas Sensor   │              │
│  │ (ESP32)         │  │ (ESP32)      │              │
│  │ POST /api/store │  │ POST /api/   │              │
│  └─────────────────┘  └──────────────┘              │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## Pré-requisitos

1. **Docker Swarm inicializado** no manager (192.168.1.80):
   - O manager deve estar em um node Linux com Docker instalado.
   - Use `docker swarm init` para iniciar.

2. **Conectividade entre redes**:
   - Fog network (Swarm) e Morea network (IoT) precisam estar roteáveis.
   - Se forem redes separadas (subnets), certifique-se de:
     - Firewall permite tráfego entre 192.168.1.80 e 192.168.1.122.
     - Roteador/gateway encaminha pacotes entre subnets.
   - Se estiverem na mesma LAN, funcionará naturalmente.

3. **SSH/acesso ao manager** para executar comandos Docker.

## Passo 1: Preparar o ambiente (.env e Dockerfile)

### 1a. Copiar e configurar `.env`

```bash
cp .env.swarm .env
# ou rename no Windows:
# copy .env.swarm .env
```

Edite `.env` com seus valores:
- `SECRET_KEY`: Gere com `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"` ou use um gerador online.
- `DOMAIN`: Se usar Traefik com HTTPS (recomendado). Deixe vazio para pular (acesso apenas por IP).
- `MOREA_HOST_IP=192.168.1.122`: Não altere (referência para IoTs).
- `FOG_MANAGER_IP=192.168.1.80`: Não altere.
- `DBTYPE`: Use `SQLite3` para teste. Para produção, considere PostgreSQL.

Exemplo preenchido:
```env
SECRET_KEY=django-insecure-a_super_random_key_here
DEBUG=False
ENVIRONMENT=PROD
ALLOWED_HOSTS=192.168.1.122,192.168.1.80,localhost,morea-app.example.com
MOREA_HOST_IP=192.168.1.122
FOG_MANAGER_IP=192.168.1.80
DOMAIN=morea-app.example.com
TRAEFIK_EMAIL=admin@example.com
DBTYPE=SQLite3
```

### 1b. Verificar Dockerfile e docker-stack.yml

- `Dockerfile`: Deve estar na raiz do projeto. Ele faz build da imagem Python + Django.
- `docker-stack.yml`: Define serviços (Traefik, Web) e redes (fog-network, morea-network) em modo Swarm.

## Passo 2: Build da imagem Docker

### No host com Docker instalado (pode ser qualquer máquina ou o manager)

```bash
# Clonar/navegar até a pasta do projeto
cd /path/to/morea-ds-web

# Build da imagem
docker build -t morea-ds-web:latest .

# (Opcional) Se usar Docker Registry privado:
# docker tag morea-ds-web:latest your-registry.com/morea-ds-web:latest
# docker push your-registry.com/morea-ds-web:latest
```

**Alternativa (script):**
```bash
bash deploy-swarm.sh build
```

A imagem deve estar disponível no Docker daemon do manager (via `docker images`) ou em um registry acessível pelos nodes.

## Passo 3: Inicializar o Docker Swarm (no manager 192.168.1.80)

SSH/console no manager Linux:

```bash
# Se não for um swarm ainda:
docker swarm init --advertise-addr 192.168.1.80

# Verificar status:
docker info | grep "Swarm:"
# Deve mostrar: Swarm: active
```

Se houver outros nodes que precisam se juntar ao swarm:
```bash
# Gerar token de worker:
docker swarm join-token worker
# Saída: docker swarm join --token SWMTKN-... 192.168.1.80:2377

# Em outro node worker:
docker swarm join --token SWMTKN-... 192.168.1.80:2377
```

## Passo 4: Criar as redes overlay (no manager)

As redes são definidas no `docker-stack.yml`, mas você pode criá-las manualmente se desejar:

```bash
# Rede interna do Swarm (Fog)
docker network create --driver overlay --opt com.docker.network.driver.overlay.vxlan_list=4789 fog-network

# Rede para comunicação com IoTs (Morea)
docker network create --driver overlay --opt com.docker.network.driver.overlay.vxlan_list=4790 morea-network
```

(Opcional — o `docker stack deploy` cria as redes automaticamente se não existirem.)

## Passo 5: Deploy do stack (no manager)

SSH no manager e execute:

```bash
# Navegar até a pasta do projeto (onde estão .env e docker-stack.yml)
cd /path/to/morea-ds-web

# Deploy
docker stack deploy -c docker-stack.yml morea

# Verificar status:
docker stack ps morea
docker service ls
```

Esperado:
```
ID          NAME           IMAGE              NODE           DESIRED STATE
abc123      morea_traefik  traefik:v2.10      swarm-manager  Running
def456      morea_web      morea-ds-web:latest swarm-manager  Running
```

## Passo 6: Verificar acesso e conectividade

### 6a. Acesso local (no manager ou pela rede)

**Por IP (sem HTTPS):**
```bash
curl http://192.168.1.80:8000/
# ou
curl http://192.168.1.122:8000/  # Se o container responder nesse IP também
```

**Por domínio (com Traefik/HTTPS) — se `DOMAIN` foi definido:**
```bash
# Após DNS apontar seu domínio para 192.168.1.80:
curl https://morea-app.example.com/
```

### 6b. Acessar Django Admin

```
http://192.168.1.80:8000/admin/
```

Criar superuser (no manager):
```bash
docker exec -it $(docker ps -q -f "label=com.docker.swarm.service.name=morea_web") python manage.py createsuperuser
```

### 6c. Testar envio de dados (simular IoT)

**Via curl (no mesmo host ou pela rede):**
```bash
curl -X POST http://192.168.1.80:8000/api/store-data \
  -H "Content-Type: application/json" \
  -d '{
    "apiToken": "optional-token",
    "macAddress": "AA:BB:CC:DD:EE:FF",
    "measure": [
      {"type": 1, "value": 0.123},
      {"type": 2, "value": 0.05}
    ]
  }'
```

Resposta esperada:
```json
{"message":"data stored."}
```

## Passo 7: Configurar IoTs para enviar dados

### Para sensores ESP32 (Arduino)

Exemplo de código:

```cpp
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char* SERVER_IP = "192.168.1.122";  // Ou 192.168.1.80 se roteável
const int SERVER_PORT = 8000;
const char* DEVICE_MAC = "AA:BB:CC:DD:EE:FF";
const char* API_TOKEN = "token-from-server";  // Após autenticar

void setup() {
  Serial.begin(115200);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) delay(500);
  Serial.println("WiFi connected");
}

void sendData(float value1, float value2) {
  HTTPClient http;
  String url = "http://" + String(SERVER_IP) + ":" + String(SERVER_PORT) + "/api/store-data";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  
  StaticJsonDocument<256> doc;
  doc["apiToken"] = API_TOKEN;
  doc["macAddress"] = DEVICE_MAC;
  doc["measure"][0]["type"] = 1;
  doc["measure"][0]["value"] = value1;
  doc["measure"][1]["type"] = 2;
  doc["measure"][1]["value"] = value2;
  
  String payload;
  serializeJson(doc, payload);
  
  int httpCode = http.POST(payload);
  Serial.println("HTTP Code: " + String(httpCode));
  Serial.println(http.getString());
  
  http.end();
}

void loop() {
  // Ler sensores e enviar
  float water = readWaterSensor();
  float energy = readEnergySensor();
  
  sendData(water, energy);
  
  delay(60000);  // A cada 60s
}
```

## Passo 8: Monitorar logs e dados

### Ver logs do serviço web:
```bash
docker service logs morea_web -f
```

### Ver dados no Django Admin:
```
http://192.168.1.80:8000/admin/ → App → Data → (ver entries)
```

### Ver gráfico do dashboard:
```
http://192.168.1.80:8000/dashboard/
```

Os gráficos são gerados automaticamente pela cron job a cada 24h (veja `morea_ds/settings.py` → `CRONJOBS`). Para gerar manualmente:
```bash
docker exec -it $(docker ps -q -f "label=com.docker.swarm.service.name=morea_web") \
  python manage.py shell -c "from app.graphs import generateAllMotes24hRaw; generateAllMotes24hRaw()"
```

## Troubleshooting

### "Service not converging" ou estado "Pending"
```bash
docker service logs morea_web
docker inspect service morea_web
```
Verifique:
- Imagem está disponível (docker pull).
- Constraints (placement) estão corretos (hostname do node).
- Volumes existem e são acessíveis.

### IoTs não conseguem conectar ao servidor
1. Verifique IP de origem (esp32/sensor faz DNS resolve correto?).
2. Firewall: `iptables -L -n` ou firewall do manager.
3. Roteamento entre subnets: `route -n` (se em subnets diferentes).
4. Teste simples: `ping 192.168.1.80` do dispositivo IoT.

### "Port 8000 already in use"
Se o container tenta usar porta já ocupada:
```bash
# Liberar:
lsof -i :8000
kill -9 <PID>

# Ou redirecionar em docker-stack.yml:
ports:
  - target: 8000
    published: 8001  # Novo port
```

### Banco de dados não persiste entre redeploys
Se usar SQLite:
- O volume `morea-media` é montado em `/app/media`, não `/app/db.sqlite3`.
- Para persistência do DB, edite `docker-stack.yml` ou use PostgreSQL externo (recomendado).

## Segurança (Checklist Produção)

- [ ] `SECRET_KEY` é uma string longa e aleatória (não use o padrão).
- [ ] `DEBUG=False` no `.env`.
- [ ] HTTPS ativado (Traefik com Let's Encrypt via `DOMAIN`).
- [ ] Firewall restringe acesso apenas ao necessário (80, 443, IoT upload port).
- [ ] Banco de dados usa PostgreSQL ou MySQL com credenciais fortes (não SQLite em produção).
- [ ] Volumes de dados têm backups regulares.
- [ ] Logs são coletados (ELK, Splunk, ou arquivo remoto).

## Resumo de Comandos Úteis

```bash
# Verificar stack
docker stack ls
docker stack ps morea

# Remover stack
docker stack rm morea

# Escalar serviço (ex. 3 replicas)
docker service scale morea_web=3

# Logs
docker service logs morea_web -f
docker service logs morea_traefik -f

# Atualizar serviço (ex. nova imagem)
docker service update --image morea-ds-web:v2 morea_web

# Shell dentro do container
docker exec -it <CONTAINER_ID> /bin/sh
```

## Próximos passos

1. Testar com 1-2 sensores reais para validar fluxo de dados.
2. Ajustar políticas de restart e placement conforme necessidade.
3. Implementar backup do DB (se SQLite) ou migration para DB remoto (PostgreSQL).
4. Configurar monitoramento (Prometheus + Grafana opcional).
5. Documentar IPs de sensores e tokens em spreadsheet ou GitHub.

---

Dúvidas ou feedback? Consulte logs com `docker service logs` e o Django admin em `/admin/`.

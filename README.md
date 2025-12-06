# Morea IoT Data Collection System

Sistema de coleta de dados de sensores IoT (água, energia, gás) com interface web em Django, dashboard interativo e suporte a Docker Swarm para ambientes distribuídos.

## Quickstart (Docker Compose - Dev/Test)

```bash
# Copiar configuração
cp .env.example .env

# Editar .env com valores
# - SECRET_KEY (gerar novo)
# - ALLOWED_HOSTS
# - DEBUG=True para dev

# Build e run
docker-compose build
docker-compose up -d

# Criar superuser
docker-compose exec web python manage.py createsuperuser

# Acessar
# - Home: http://localhost:8000/
# - Admin: http://localhost:8000/admin/
# - Dashboard: http://localhost:8000/dashboard/
```

## Docker Swarm Deployment (Produção)

Para deployment em múltiplas máquinas com Docker Swarm (Fog + IoT networks):

**Veja: [SWARM_DEPLOYMENT.md](./SWARM_DEPLOYMENT.md)** para guia completo.

### Resumo rápido:

```bash
# 1. Configurar .env
cp .env.swarm .env
# Editar: SECRET_KEY, DOMAIN, MOREA_HOST_IP, FOG_MANAGER_IP

# 2. No manager Linux (192.168.1.80), initialize Swarm
docker swarm init --advertise-addr 192.168.1.80

# 3. Build image (Windows ou Linux)
docker build -t morea-ds-web:latest .

# 4. Deploy
docker stack deploy -c docker-stack.yml morea
# ou com PostgreSQL (produção):
docker stack deploy -c docker-stack-prod.yml morea

# 5. Verificar
docker stack ps morea
docker service logs morea_web -f
```

## Arquitetura

```
┌─────────────────────────────┐
│   Fog Network (Swarm)       │  192.168.1.80
│   - Django Web App          │
│   - Traefik + HTTPS         │
│   - PostgreSQL (opt.)       │
└──────────────┬──────────────┘
               │
               │ Docker Network (overlay)
               │
┌──────────────▼──────────────┐
│   Morea Network (IoT)       │  192.168.1.122
│   - Water Sensors           │
│   - Gas Sensors             │
│   - Energy Sensors          │
│   (Enviam POST a /api/store-data)
└─────────────────────────────┘
```

## API Endpoints

### Autenticar dispositivo
```
POST /api/authenticate
{
  "macAddress": "AA:BB:CC:DD:EE:FF",
  "deviceIp": "192.168.1.60"
}

Response:
{
  "api_token": "uuid-token",
  "deviceName": "device-name"
}
```

### Enviar medições
```
POST /api/store-data
{
  "apiToken": "token-from-authenticate",
  "macAddress": "AA:BB:CC:DD:EE:FF",
  "measure": [
    {"type": 1, "value": 0.123},  # Volume (L ou m³)
    {"type": 2, "value": 0.05}    # kWh (energia)
  ]
}

Response: {"message": "data stored."}
```

## Configuração IoT (ESP32 / Arduino)

Exemplo de envio via HTTPClient:

```cpp
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

const char* SERVER_IP = "192.168.1.122";  // ou 192.168.1.80
const int SERVER_PORT = 8000;
const char* API_ENDPOINT = "/api/store-data";

void sendData(float value1, float value2) {
  HTTPClient http;
  String url = "http://" + String(SERVER_IP) + ":" + String(SERVER_PORT) + API_ENDPOINT;
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  
  StaticJsonDocument<256> doc;
  doc["apiToken"] = API_TOKEN;
  doc["macAddress"] = DEVICE_MAC;
  doc["measure"][0]["type"] = 1;
  doc["measure"][0]["value"] = value1;
  
  String payload;
  serializeJson(doc, payload);
  
  int httpCode = http.POST(payload);
  Serial.println("Response: " + http.getString());
  http.end();
}
```

## Estrutura de Pastas

```
morea-ds-web/
├── Dockerfile                 # Build da imagem
├── docker-compose.yml         # Compose para dev/test
├── docker-stack.yml           # Swarm stack (SQLite)
├── docker-stack-prod.yml      # Swarm stack (PostgreSQL)
├── .env.example               # Exemplo de env vars
├── .env.swarm                 # Exemplo para Swarm
├── docker/
│   └── entrypoint.sh         # Script de inicialização
├── traefik/
│   └── README.md             # Notas Traefik
├── app/                       # Django app
│   ├── models.py             # Device, Data, Graph
│   ├── views.py              # API endpoints (authenticate, store-data)
│   ├── graphs.py             # Geração de gráficos
│   ├── urls.py               # Rotas
│   └── templates/            # HTML templates
├── morea_ds/                 # Django project
│   ├── settings.py           # Configurações
│   ├── urls.py               # URL principal
│   └── wsgi.py
├── manage.py
├── requirements.txt
├── SWARM_DEPLOYMENT.md       # Guia completo para Swarm
└── Deploy-SwarmWindows.ps1   # Script PowerShell (Windows → Swarm)
```

## Troubleshooting

### Container não inicia
```bash
docker-compose logs web
# ou
docker service logs morea_web -f
```

### IoTs não conseguem conectar
1. Verificar IP correto: `ipconfig` (Windows) ou `ifconfig` (Linux)
2. Firewall: liberar porta 8000/8001 conforme configuração
3. DNS: verificar que IP é alcançável via ping

### Banco de dados em erro
- SQLite: verifique permissões na pasta /app/db.sqlite3
- PostgreSQL: verifique variáveis DBUSER, DBPASSWORD, DBHOST

## Segurança (Produção)

- [ ] `SECRET_KEY` aleatório e seguro
- [ ] `DEBUG=False`
- [ ] HTTPS habilitado (Traefik com Let's Encrypt)
- [ ] Firewall restringe acesso
- [ ] Use PostgreSQL (não SQLite)
- [ ] Backups regulares

## Próximos passos

1. Configurar sensores IoT com endpoints do servidor
2. Monitorar dados no admin ou dashboard
3. Implementar Prometheus + Grafana para métricas avançadas
4. Configurar alertas e notificações

## Licença

Veja LICENSE no repositório.

---

**Dúvidas?**
- Verifique logs: `docker-compose logs -f` ou `docker service logs morea_web -f`
- Acesse Django Admin: http://HOST:8000/admin/
- Consulte SWARM_DEPLOYMENT.md para produção


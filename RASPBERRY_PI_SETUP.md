# Configuração Docker Swarm em 3 Raspberry Pi

Guia passo-a-passo para setup de um cluster Docker Swarm em 3 Raspberry Pi:
- **fog-manager** (192.168.1.80) - Manager + Traefik
- **fog-worker-01** (192.168.1.81) - Worker (roda replicas da web)
- **fog-worker-02** (192.168.1.82) - Worker (roda replicas da web)

## 1. Preparação Inicial (todos os 3 Raspberry)

### 1.1 Hardware recomendado
- Raspberry Pi 4B (4GB RAM mínimo, 8GB recomendado)
- Cartão microSD 64GB+ (classe 3, rápido)
- Alimentação 5V/3A estável
- Ethernet conectado (Wi-Fi não recomendado para Swarm)

### 1.2 Sistema Operacional
```bash
# Instalação recomendada: Raspberry Pi OS Lite (64-bit)
# Download: https://www.raspberrypi.com/software/

# Ou via rpi-imager (GUI):
# 1. Inserir cartão SD
# 2. Rodar rpi-imager
# 3. Selecionar Raspberry Pi 4, OS Lite 64-bit
# 4. Selecionar cartão SD e escrever

# Flash via SSH direto (alternativa):
# 1. Boot com SO padrão Raspberry Pi OS
# 2. SSH: ssh pi@<RPi-IP>
# 3. Executar comandos abaixo
```

### 1.3 Atualizar SO e instalar Docker
SSH em cada Raspberry (como `pi` ou `root`):

```bash
# Atualizar pacotes
sudo apt update
sudo apt upgrade -y

# Instalar Docker (script oficial)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Remover o script
rm get-docker.sh

# Adicionar user ao grupo docker (opcional, para não usar sudo)
sudo usermod -aG docker $USER
newgrp docker

# Verificar instalação
docker --version
docker ps
```

### 1.4 Configurar hostname e rede
SSH em cada Raspberry:

**fog-manager (192.168.1.80):**
```bash
sudo hostnamectl set-hostname fog-manager

# Editar /etc/hostname e /etc/hosts se necessário
sudo nano /etc/hostname
# Mudar "raspberrypi" para "fog-manager"

sudo nano /etc/hosts
# Adicionar: 192.168.1.80 fog-manager

sudo reboot
```

**fog-worker-01 (192.168.1.81):**
```bash
sudo hostnamectl set-hostname fog-worker-01
sudo nano /etc/hostname  # Mudar para fog-worker-01
sudo nano /etc/hosts     # Adicionar 192.168.1.81 fog-worker-01
sudo reboot
```

**fog-worker-02 (192.168.1.82):**
```bash
sudo hostnamectl set-hostname fog-worker-02
sudo nano /etc/hostname  # Mudar para fog-worker-02
sudo nano /etc/hosts     # Adicionar 192.168.1.82 fog-worker-02
sudo reboot
```

### 1.5 Verificar conectividade
De qualquer um dos nodes, testar ping:
```bash
ping fog-manager
ping fog-worker-01
ping fog-worker-02
```

## 2. Inicializar Docker Swarm

### 2.1 No fog-manager (192.168.1.80)
```bash
docker swarm init --advertise-addr 192.168.1.80
```

Saída esperada:
```
Swarm initialized: current node (...) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-... 192.168.1.80:2377

To add a manager to this swarm, run the following command:

    docker swarm join-token manager
```

**Salvar o token SWMTKN-... para usar nos workers.**

### 2.2 Nos workers (fog-worker-01 e fog-worker-02)
```bash
# Substituir SWMTKN-... pelo token do manager
docker swarm join --token SWMTKN-1-... 192.168.1.80:2377
```

Saída esperada:
```
This node joined a swarm as a worker.
```

### 2.3 Verificar cluster (no manager)
```bash
docker node ls
```

Saída esperada:
```
ID                            HOSTNAME        STATUS    AVAILABILITY   MANAGER STATUS
abc123...                     fog-manager     Ready     Active         Leader
def456...                     fog-worker-01   Ready     Active         
ghi789...                     fog-worker-02   Ready     Active         
```

## 3. Preparar repositório e configuração

### 3.1 Clonar projeto no manager
```bash
# SSH no fog-manager
ssh pi@192.168.1.80

cd /home/pi
git clone https://github.com/seu-repo/morea-ds-web.git
cd morea-ds-web
```

### 3.2 Configurar .env
```bash
cp .env.swarm .env

# Editar com valores
nano .env
```

Valores recomendados para seu ambiente:
```env
SECRET_KEY=seu_secret_key_super_aleatorio_e_seguro
DEBUG=False
ENVIRONMENT=PROD
ALLOWED_HOSTS=192.168.1.80,192.168.1.81,192.168.1.82,192.168.1.122,fog-manager,fog-worker-01,fog-worker-02,localhost

MOREA_HOST_IP=192.168.1.122
FOG_MANAGER_IP=192.168.1.80

DOMAIN=morea.seu-dominio.com.br
TRAEFIK_EMAIL=seu-email@example.com

DBTYPE=SQLite3
# Ou PostgreSQL para produção
# DBTYPE=MySQL
# DBNAME=morea
# DBUSER=morea_user
# DBPASSWORD=senha_segura
# DBHOST=postgres-service
# DBPORT=5432
```

## 4. Build da imagem Docker

### 4.1 No fog-manager ou em uma máquina com Docker
```bash
cd /home/pi/morea-ds-web

# Build (pode levar 5-10 min em Raspberry)
docker build -t morea-ds-web:latest .

# Verificar
docker images | grep morea-ds-web
```

Se desejar usar registry privado (para reutilizar em múltiplos nodes):
```bash
# Fazer push para registry (ex: Harbor, Docker Hub, or local registry)
docker tag morea-ds-web:latest seu-registry/morea-ds-web:latest
docker push seu-registry/morea-ds-web:latest

# Editar docker-stack.yml para usar:
# image: seu-registry/morea-ds-web:latest
```

### 4.2 Alternativa: Build em cada worker (se não usar registry)
Repita os passos 3.1-4.1 em fog-worker-01 e fog-worker-02.

(Recomendação: use um registry privado para evitar redundância.)

## 5. Deploy do Stack Swarm

### 5.1 Criar arquivo acme.json para Traefik
No fog-manager:
```bash
mkdir -p traefik/letsencrypt
touch traefik/letsencrypt/acme.json
chmod 600 traefik/letsencrypt/acme.json
```

### 5.2 Deploy
No fog-manager:
```bash
cd /home/pi/morea-ds-web

# Deploy stack
docker stack deploy -c docker-stack.yml morea

# Verificar status (leva ~30s para containers iniciarem)
docker stack ps morea
docker service ls
```

Saída esperada:
```
ID          NAME                    IMAGE                   NODE            STATUS
abc123      morea_traefik.1         traefik:v2.10           fog-manager     Running
def456      morea_web.1             morea-ds-web:latest     fog-worker-01   Running
ghi789      morea_web.2             morea-ds-web:latest     fog-worker-02   Running
```

### 5.3 Verificar logs
```bash
# Log do serviço web
docker service logs morea_web -f

# Log do Traefik
docker service logs morea_traefik -f

# Log de um node específico
docker node ps <node-id>
```

## 6. Testar acesso

### 6.1 Home
```bash
curl http://fog-manager:8000/
# ou
curl http://192.168.1.80:8000/
```

### 6.2 Admin (criar superuser primeiro)
```bash
# SSH em um dos containers rodando web
docker exec -it $(docker ps -q -f "label=com.docker.swarm.service.name=morea_web" | head -1) \
  python manage.py createsuperuser

# Acessar (via navegador):
# http://192.168.1.80:8000/admin/
```

### 6.3 API test
```bash
curl -X POST http://192.168.1.80:8000/api/store-data \
  -H "Content-Type: application/json" \
  -d '{
    "apiToken": "",
    "macAddress": "AA:BB:CC:DD:EE:FF",
    "measure": [
      {"type": 1, "value": 0.123},
      {"type": 2, "value": 0.05}
    ]
  }'
```

## 7. Configurar IoTs na rede Morea

### 7.1 IPs acessíveis pelos sensores
Dependendo da rede:
- Se IoTs estão na mesma LAN que fog-manager: use `192.168.1.80:8000/api/store-data`
- Se em subnet diferente: configure roteamento entre subnets ou use firewall rules

### 7.2 Exemplo ESP32
```cpp
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

const char* SERVER_IP = "192.168.1.80";  // fog-manager
const int SERVER_PORT = 8000;
const char* DEVICE_MAC = "AA:BB:CC:DD:EE:FF";

void sendData(float volume, float energy) {
  if (WiFi.status() != WL_CONNECTED) return;
  
  HTTPClient http;
  String url = "http://" + String(SERVER_IP) + ":" + String(SERVER_PORT) + "/api/store-data";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  
  StaticJsonDocument<256> doc;
  doc["apiToken"] = "";  // Deixar vazio se device não autorizado
  doc["macAddress"] = DEVICE_MAC;
  doc["measure"][0]["type"] = 1;  // Volume
  doc["measure"][0]["value"] = volume;
  doc["measure"][1]["type"] = 2;  // Energia
  doc["measure"][1]["value"] = energy;
  
  String payload;
  serializeJson(doc, payload);
  
  int httpCode = http.POST(payload);
  Serial.println("Response: " + String(httpCode) + " - " + http.getString());
  
  http.end();
}

void setup() {
  Serial.begin(115200);
  WiFi.begin("SSID", "PASSWORD");
  while (WiFi.status() != WL_CONNECTED) delay(500);
  Serial.println("Connected");
}

void loop() {
  sendData(0.123, 0.05);
  delay(60000);  // A cada 1 minuto
}
```

## 8. Troubleshooting

### Container não inicia
```bash
docker service logs morea_web -f
# ou
docker node ps fog-worker-01
docker logs <container-id>
```

### Erro de espaço em disco
Raspberry Pi com cartão 32GB pode ficar cheio. Limpar cache Docker:
```bash
docker system prune -a --volumes
```

### Swarm não responde
Reiniciar daemon Docker em um node:
```bash
sudo systemctl restart docker
```

Se inteiro Swarm cair, reconstruir (perder dados):
```bash
# EM CADA NODE:
docker swarm leave -f

# No manager:
docker swarm init --advertise-addr 192.168.1.80
```

### Rede overlay não funciona
Verificar conectividade UDP entre nodes (port 4789 para VXLAN):
```bash
sudo ufw allow 4789/udp  # Se usar firewall
```

## 9. Monitoramento contínuo (opcional)

Instalar Portainer para gerenciar Swarm via UI:
```bash
docker service create \
  --name portainer \
  --constraint node.role==manager \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --publish 9000:9000 \
  portainer/portainer-ce:latest
```

Acessar: `http://fog-manager:9000/`

## 10. Backup e restore

### Backup do DB
```bash
# Se usar SQLite
docker exec -it <web-container-id> \
  tar czf - /app/db.sqlite3 | \
  tar xzf - -C /backup/

# Se usar PostgreSQL
docker exec -it <postgres-container-id> \
  pg_dump -U morea_user morea_db > /backup/morea-db.sql
```

## Resumo rápido

```bash
# Listar nós
docker node ls

# Status do stack
docker stack ps morea

# Escalar web para 3 replicas
docker service scale morea_web=3

# Update de serviço (nova imagem)
docker service update --image morea-ds-web:v2 morea_web

# Remover stack
docker stack rm morea

# Logs (follow)
docker service logs morea_web -f
```

---

**Próximos passos:**
1. Configurar backup automático
2. Implementar monitoramento (Prometheus/Grafana)
3. Documentar IPs e credenciais de sensores
4. Testar failover (desligar um worker e verificar redeploy)


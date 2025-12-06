#!/bin/bash
# setup-monitoring.sh
# Script para deploy do stack de monitoramento e provisioning inicial

set -e

MANAGER_IP="${1:-192.168.1.80}"
PROJECT_PATH="${2:-$(pwd)}"

echo "=== Morea Monitoring Stack Setup ==="
echo "Manager IP: $MANAGER_IP"
echo "Project Path: $PROJECT_PATH"

# Verificar Docker Swarm
echo "Checking Docker Swarm status..."
if ! docker info | grep -q "Swarm: active"; then
    echo "Error: Docker Swarm not active"
    exit 1
fi

# Criar volumes se não existirem
echo "Creating volumes..."
mkdir -p $PROJECT_PATH/prometheus
mkdir -p $PROJECT_PATH/grafana

# Deploy monitoring stack
echo "Deploying monitoring stack..."
cd $PROJECT_PATH
docker stack deploy -c docker-stack-monitoring.yml monitoring

echo "Waiting for services to start..."
sleep 10

# Verificar se subiu
docker stack ps monitoring

echo ""
echo "=== Monitoring Stack Deployed ==="
echo ""
echo "Access points:"
echo "  Prometheus: http://$MANAGER_IP:9090"
echo "  Grafana:    http://$MANAGER_IP:3000"
echo "  cAdvisor:   http://$MANAGER_IP:8081"
echo ""
echo "Grafana default credentials:"
echo "  User: admin"
echo "  Pass: (check .env GRAFANA_ADMIN_PASSWORD)"
echo ""
echo "Next steps:"
echo "  1. Access Grafana at http://$MANAGER_IP:3000"
echo "  2. Add Prometheus as data source (http://prometheus:9090)"
echo "  3. Import dashboards or create custom ones"
echo ""

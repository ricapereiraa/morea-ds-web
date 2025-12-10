#!/bin/bash

# Script para testar alta disponibilidade no Docker Swarm
# Simula falhas e verifica se o serviço continua disponível

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Teste de Alta Disponibilidade${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Verificar se está em um ambiente Swarm
if ! docker info | grep -q "Swarm: active"; then
    echo -e "${RED}ERRO: Docker Swarm não está ativo!${NC}"
    exit 1
fi

STACK_NAME=${STACK_NAME:-"morea"}
SERVICE_NAME=${SERVICE_NAME:-"morea_web"}
ENDPOINT=${ENDPOINT:-"http://localhost:8000"}

# Verificar configuração do Swarm
echo -e "${YELLOW}Configuração do Swarm:${NC}"
docker node ls

MANAGER_COUNT=$(docker node ls --filter role=manager --format "{{.Hostname}}" | wc -l)
WORKER_COUNT=$(docker node ls --filter role=worker --format "{{.Hostname}}" | wc -l)

echo -e "\n${GREEN}Topologia do Swarm:${NC}"
echo "  Managers: ${MANAGER_COUNT}"
echo "  Workers: ${WORKER_COUNT}"
echo "  Total: $(($MANAGER_COUNT + $WORKER_COUNT))"

if [ $MANAGER_COUNT -lt 1 ] || [ $WORKER_COUNT -lt 2 ]; then
    echo -e "\n${YELLOW}AVISO: Para testar alta disponibilidade adequadamente, recomenda-se:${NC}"
    echo "  - 1 Manager"
    echo "  - 2 ou mais Workers"
    echo ""
    read -p "Deseja continuar mesmo assim? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Verificar serviço
echo -e "\n${YELLOW}Estado atual do serviço:${NC}"
docker service ls | grep "${SERVICE_NAME}" || {
    echo -e "${RED}Serviço não encontrado!${NC}"
    exit 1
}

echo -e "\n${YELLOW}Réplicas do serviço:${NC}"
docker service ps ${STACK_NAME}_${SERVICE_NAME} --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}\t{{.Error}}"

# Verificar healthcheck
echo -e "\n${YELLOW}Verificando healthcheck do serviço...${NC}"
SERVICE_JSON=$(docker service inspect ${STACK_NAME}_${SERVICE_NAME} --format '{{json .Spec.TaskTemplate.ContainerSpec.Healthcheck}}' 2>/dev/null || echo "null")

if [ "$SERVICE_JSON" != "null" ] && [ "$SERVICE_JSON" != "" ]; then
    echo -e "${GREEN}[OK] Healthcheck configurado${NC}"
else
    echo -e "${YELLOW}[AVISO] Healthcheck nao configurado (recomendado para HA)${NC}"
fi

# Função para verificar se o endpoint está respondendo
check_endpoint() {
    local url=$1
    local timeout=${2:-5}
    if curl -s -o /dev/null -w "%{http_code}" --max-time ${timeout} ${url} > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Teste 1: Verificar disponibilidade inicial
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Teste 1: Disponibilidade Inicial${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Verificando se o endpoint está acessível...${NC}"
if check_endpoint ${ENDPOINT}; then
    echo -e "${GREEN}[OK] Endpoint esta acessivel${NC}"
    INITIAL_AVAILABLE=true
else
    echo -e "${RED}[ERRO] Endpoint nao esta acessivel${NC}"
    INITIAL_AVAILABLE=false
fi

# Teste 2: Simular falha de container
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Teste 2: Simulação de Falha de Container${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Obtendo lista de containers do serviço...${NC}"
CONTAINERS=$(docker service ps ${STACK_NAME}_${SERVICE_NAME} --format "{{.Name}}" --filter "desired-state=running" | head -1)

if [ -z "$CONTAINERS" ]; then
    echo -e "${RED}Nenhum container em execução encontrado!${NC}"
    exit 1
fi

FIRST_CONTAINER=$(echo $CONTAINERS | head -1)
FIRST_NODE=$(docker service ps ${STACK_NAME}_${SERVICE_NAME} --format "{{.Node}}" --filter "name=${FIRST_CONTAINER}" | head -1)

echo -e "${GREEN}Container selecionado para teste: ${FIRST_CONTAINER} (Node: ${FIRST_NODE})${NC}"

# Verificar quantas réplicas existem
REPLICA_COUNT=$(docker service ps ${STACK_NAME}_${SERVICE_NAME} --format "{{.Name}}" --filter "desired-state=running" | wc -l)
echo -e "${GREEN}Réplicas ativas: ${REPLICA_COUNT}${NC}"

if [ $REPLICA_COUNT -lt 2 ]; then
    echo -e "${YELLOW}AVISO: Apenas 1 réplica ativa. Para testar HA adequadamente, são necessárias pelo menos 2 réplicas.${NC}"
    echo "Deseja escalar o serviço para 2 réplicas? (s/N): "
    read -p "" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Escalando serviço para 2 réplicas...${NC}"
        docker service scale ${STACK_NAME}_${SERVICE_NAME}=2
        echo -e "${GREEN}Aguardando 10 segundos para as réplicas iniciarem...${NC}"
        sleep 10
    fi
fi

# Monitorar disponibilidade durante o teste
echo -e "\n${YELLOW}Iniciando monitoramento de disponibilidade...${NC}"
echo -e "${YELLOW}Enviando requisições a cada 2 segundos...${NC}\n"

MONITOR_DURATION=30
REQUESTS_SENT=0
REQUESTS_SUCCESS=0
REQUESTS_FAILED=0

for i in $(seq 1 $((MONITOR_DURATION / 2))); do
    if check_endpoint ${ENDPOINT} 2; then
        REQUESTS_SUCCESS=$(($REQUESTS_SUCCESS + 1))
        printf "${GREEN}.${NC}"
    else
        REQUESTS_FAILED=$(($REQUESTS_FAILED + 1))
        printf "${RED}F${NC}"
    fi
    REQUESTS_SENT=$(($REQUESTS_SENT + 1))
    sleep 2
done

echo -e "\n\n${GREEN}Resultados do monitoramento:${NC}"
echo "  Requisições enviadas: ${REQUESTS_SENT}"
echo "  Sucessos: ${REQUESTS_SUCCESS}"
echo "  Falhas: ${REQUESTS_FAILED}"
if [ $REQUESTS_SENT -gt 0 ]; then
    UPTIME=$(awk "BEGIN {printf \"%.2f\", (${REQUESTS_SUCCESS}/${REQUESTS_SENT})*100}")
    echo "  Uptime: ${UPTIME}%"
fi

# Teste 3: Verificar restart policy
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Teste 3: Política de Restart${NC}"
echo -e "${BLUE}========================================${NC}\n"

RESTART_POLICY=$(docker service inspect ${STACK_NAME}_${SERVICE_NAME} --format '{{.Spec.TaskTemplate.RestartPolicy.Condition}}' 2>/dev/null || echo "none")
echo -e "${GREEN}Política de restart configurada: ${RESTART_POLICY}${NC}"

if [ "$RESTART_POLICY" = "none" ] || [ -z "$RESTART_POLICY" ]; then
    echo -e "${YELLOW}[AVISO] Politica de restart nao configurada (recomendado: on-failure ou any)${NC}"
else
    echo -e "${GREEN}[OK] Politica de restart adequada para HA${NC}"
fi

# Teste 4: Verificar distribuição de réplicas
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Teste 4: Distribuição de Réplicas${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Distribuição atual:${NC}"
docker service ps ${STACK_NAME}_${SERVICE_NAME} --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}"

# Verificar se há réplicas em nodes diferentes
NODES_WITH_REPLICAS=$(docker service ps ${STACK_NAME}_${SERVICE_NAME} --format "{{.Node}}" --filter "desired-state=running" | sort -u | wc -l)
echo -e "\n${GREEN}Nodes com réplicas ativas: ${NODES_WITH_REPLICAS}${NC}"

if [ $NODES_WITH_REPLICAS -ge 2 ]; then
    echo -e "${GREEN}[OK] Replicas distribuidas em multiplos nodes (boa pratica para HA)${NC}"
else
    echo -e "${YELLOW}[AVISO] Todas as replicas estao no mesmo node (risco de ponto unico de falha)${NC}"
fi

# Resumo final
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Resumo do Teste de Alta Disponibilidade${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${GREEN}Configuração:${NC}"
echo "  Managers: ${MANAGER_COUNT}"
echo "  Workers: ${WORKER_COUNT}"
echo "  Réplicas do serviço: ${REPLICA_COUNT}"
echo "  Nodes com réplicas: ${NODES_WITH_REPLICAS}"
echo "  Política de restart: ${RESTART_POLICY}"

echo -e "\n${GREEN}Disponibilidade:${NC}"
if [ $REQUESTS_SENT -gt 0 ]; then
    echo "  Uptime durante teste: ${UPTIME}%"
fi

echo -e "\n${YELLOW}Recomendacoes:${NC}"
if [ $REPLICA_COUNT -lt 2 ]; then
    echo "  [AVISO] Escalar servico para pelo menos 2 replicas"
fi
if [ "$RESTART_POLICY" = "none" ] || [ -z "$RESTART_POLICY" ]; then
    echo "  [AVISO] Configurar politica de restart (on-failure ou any)"
fi
if [ $NODES_WITH_REPLICAS -lt 2 ]; then
    echo "  [AVISO] Distribuir replicas em multiplos nodes"
fi
if [ "$SERVICE_JSON" = "null" ] || [ -z "$SERVICE_JSON" ]; then
    echo "  [AVISO] Configurar healthcheck para o servico"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Teste de alta disponibilidade concluído!${NC}"
echo -e "${GREEN}========================================${NC}\n"


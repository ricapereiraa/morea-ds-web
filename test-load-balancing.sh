#!/bin/bash

# Script para testar balanceamento de carga no Docker Swarm
# Testa se as requisições estão sendo distribuídas entre as réplicas

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Teste de Balanceamento de Carga${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Verificar se está em um ambiente Swarm
if ! docker info | grep -q "Swarm: active"; then
    echo -e "${RED}ERRO: Docker Swarm não está ativo!${NC}"
    echo "Execute: docker swarm init (no manager) ou docker swarm join (nos workers)"
    exit 1
fi

# Verificar se o serviço está rodando
STACK_NAME=${STACK_NAME:-"morea"}
SERVICE_NAME=${SERVICE_NAME:-"morea_web"}
ENDPOINT=${ENDPOINT:-"http://localhost:8000"}

echo -e "${YELLOW}Verificando serviços do stack '${STACK_NAME}'...${NC}"
if ! docker stack services ${STACK_NAME} | grep -q "${SERVICE_NAME}"; then
    echo -e "${RED}ERRO: Serviço '${SERVICE_NAME}' não encontrado no stack '${STACK_NAME}'${NC}"
    echo "Execute: docker stack deploy -c docker-stack.yml ${STACK_NAME}"
    exit 1
fi

# Obter informações das réplicas
echo -e "\n${YELLOW}Informações das réplicas:${NC}"
docker service ls | grep "${SERVICE_NAME}"

echo -e "\n${YELLOW}Distribuição das réplicas nos nodes:${NC}"
docker service ps ${STACK_NAME}_${SERVICE_NAME} --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}"

# Contar réplicas
REPLICAS=$(docker service ps ${STACK_NAME}_${SERVICE_NAME} --format "{{.Name}}" | wc -l)
echo -e "\n${GREEN}Total de réplicas encontradas: ${REPLICAS}${NC}"

if [ ${REPLICAS} -lt 2 ]; then
    echo -e "${YELLOW}AVISO: Menos de 2 réplicas. Para testar load balancing, recomenda-se pelo menos 2 réplicas.${NC}"
    echo "Para escalar: docker service scale ${STACK_NAME}_${SERVICE_NAME}=2"
fi

# Teste de balanceamento de carga
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Iniciando teste de balanceamento...${NC}"
echo -e "${BLUE}========================================${NC}\n"

REQUESTS=${REQUESTS:-100}
CONCURRENT=${CONCURRENT:-10}

echo -e "${YELLOW}Enviando ${REQUESTS} requisições com ${CONCURRENT} requisições concorrentes...${NC}"
echo -e "${YELLOW}Endpoint: ${ENDPOINT}${NC}\n"

# Criar arquivo temporário para armazenar resultados
TEMP_FILE=$(mktemp)

# Executar requisições e capturar tempos de resposta
if command -v ab &> /dev/null; then
    echo -e "${GREEN}Usando Apache Bench (ab)...${NC}"
    ab -n ${REQUESTS} -c ${CONCURRENT} -g ${TEMP_FILE}.tsv ${ENDPOINT}/ > ${TEMP_FILE} 2>&1
    
    echo -e "\n${GREEN}Resultados:${NC}"
    cat ${TEMP_FILE} | grep -E "(Requests per second|Time per request|Transfer rate|Failed requests)"
    
    if [ -f "${TEMP_FILE}.tsv" ]; then
        echo -e "\n${YELLOW}Análise de distribuição de tempo de resposta:${NC}"
        awk 'NR>1 {sum+=$2; count++} END {if(count>0) print "Tempo médio:", sum/count, "ms"}' ${TEMP_FILE}.tsv
    fi
elif command -v curl &> /dev/null; then
    echo -e "${GREEN}Usando curl para teste básico...${NC}"
    echo -e "${YELLOW}Testando distribuição de requisições...${NC}\n"
    
    SUCCESS=0
    FAILED=0
    TOTAL_TIME=0
    
    for i in $(seq 1 ${REQUESTS}); do
        START=$(date +%s%N)
        if curl -s -o /dev/null -w "%{http_code}" ${ENDPOINT}/ > /dev/null 2>&1; then
            END=$(date +%s%N)
            TIME=$((($END - $START) / 1000000))
            TOTAL_TIME=$(($TOTAL_TIME + $TIME))
            SUCCESS=$(($SUCCESS + 1))
            echo -n "."
        else
            FAILED=$(($FAILED + 1))
            echo -n "F"
        fi
        
        # Nova linha a cada 50 requisições
        if [ $(($i % 50)) -eq 0 ]; then
            echo ""
        fi
    done
    
    echo -e "\n\n${GREEN}Resultados:${NC}"
    echo "Requisições bem-sucedidas: ${SUCCESS}"
    echo "Requisições falhadas: ${FAILED}"
    if [ ${SUCCESS} -gt 0 ]; then
        AVG_TIME=$(($TOTAL_TIME / $SUCCESS))
        echo "Tempo médio de resposta: ${AVG_TIME}ms"
    fi
else
    echo -e "${RED}ERRO: Nem 'ab' nem 'curl' estão disponíveis!${NC}"
    exit 1
fi

# Verificar logs dos containers para confirmar distribuição
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Verificando logs dos containers...${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Últimas requisições em cada réplica:${NC}"
for container in $(docker service ps ${STACK_NAME}_${SERVICE_NAME} --format "{{.Name}}" --filter "desired-state=running"); do
    NODE=$(docker service ps ${STACK_NAME}_${SERVICE_NAME} --format "{{.Node}}" --filter "name=${container}" | head -1)
    echo -e "\n${GREEN}Container: ${container} (Node: ${NODE})${NC}"
    docker logs --tail 5 ${container} 2>/dev/null || echo "  (logs não disponíveis)"
done

# Limpar arquivos temporários
rm -f ${TEMP_FILE} ${TEMP_FILE}.tsv

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Teste de balanceamento concluído!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${YELLOW}Dicas:${NC}"
echo "1. Para ver estatísticas em tempo real: watch -n 1 'docker service ps ${STACK_NAME}_${SERVICE_NAME}'"
echo "2. Para escalar o serviço: docker service scale ${STACK_NAME}_${SERVICE_NAME}=3"
echo "3. Para ver logs de todas as réplicas: docker service logs -f ${STACK_NAME}_${SERVICE_NAME}"


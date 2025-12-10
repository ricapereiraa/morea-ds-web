#!/bin/bash

# Script para testar latência no Docker Swarm
# Mede o tempo de resposta entre diferentes nodes

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Teste de Latência - Docker Swarm${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Verificar se está em um ambiente Swarm
if ! docker info | grep -q "Swarm: active"; then
    echo -e "${RED}ERRO: Docker Swarm não está ativo!${NC}"
    exit 1
fi

STACK_NAME=${STACK_NAME:-"morea"}
SERVICE_NAME=${SERVICE_NAME:-"morea_web"}
ENDPOINT=${ENDPOINT:-"http://localhost:8000"}

# Obter lista de nodes
echo -e "${YELLOW}Nodes no Swarm:${NC}"
docker node ls

echo -e "\n${YELLOW}Informações de rede:${NC}"
docker network ls | grep overlay

# Teste de latência de rede entre nodes
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Teste de Latência de Rede entre Nodes${NC}"
echo -e "${BLUE}========================================${NC}\n"

NODES=$(docker node ls --format "{{.Hostname}}")
NODE_ARRAY=($NODES)

if [ ${#NODE_ARRAY[@]} -lt 2 ]; then
    echo -e "${YELLOW}AVISO: Apenas 1 node encontrado. Para testar latência entre nodes, são necessários pelo menos 2 nodes.${NC}"
else
    echo -e "${GREEN}Testando latência entre nodes...${NC}"
    for i in "${!NODE_ARRAY[@]}"; do
        for j in "${!NODE_ARRAY[@]}"; do
            if [ $i -lt $j ]; then
                NODE1=${NODE_ARRAY[$i]}
                NODE2=${NODE_ARRAY[$j]}
                echo -e "\n${YELLOW}Latência entre ${NODE1} e ${NODE2}:${NC}"
                # Tentar ping entre nodes (requer acesso SSH ou execução nos nodes)
                echo "  (Execute manualmente nos nodes para testar: ping <IP_DO_NODE>)"
            fi
        done
    done
fi

# Teste de latência HTTP
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Teste de Latência HTTP${NC}"
echo -e "${BLUE}========================================${NC}\n"

ITERATIONS=${ITERATIONS:-50}
echo -e "${YELLOW}Executando ${ITERATIONS} requisições HTTP para medir latência...${NC}"
echo -e "${YELLOW}Endpoint: ${ENDPOINT}${NC}\n"

if ! command -v curl &> /dev/null; then
    echo -e "${RED}ERRO: 'curl' não está disponível!${NC}"
    exit 1
fi

# Arrays para armazenar resultados
declare -a TIMES
declare -a STATUS_CODES

SUCCESS=0
FAILED=0

for i in $(seq 1 ${ITERATIONS}); do
    START=$(date +%s%N)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 ${ENDPOINT}/ 2>/dev/null || echo "000")
    END=$(date +%s%N)
    
    TIME_MS=$((($END - $START) / 1000000))
    TIMES+=($TIME_MS)
    STATUS_CODES+=($HTTP_CODE)
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        SUCCESS=$(($SUCCESS + 1))
        printf "${GREEN}.${NC}"
    else
        FAILED=$(($FAILED + 1))
        printf "${RED}F${NC}"
    fi
    
    # Nova linha a cada 25 requisições
    if [ $(($i % 25)) -eq 0 ]; then
        echo ""
    fi
done

echo -e "\n\n${GREEN}========================================${NC}"
echo -e "${GREEN}Resultados da Latência HTTP${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Calcular estatísticas
if [ ${#TIMES[@]} -gt 0 ]; then
    TOTAL=0
    MIN=${TIMES[0]}
    MAX=${TIMES[0]}
    
    for time in "${TIMES[@]}"; do
        TOTAL=$(($TOTAL + $time))
        if [ $time -lt $MIN ]; then
            MIN=$time
        fi
        if [ $time -gt $MAX ]; then
            MAX=$time
        fi
    done
    
    AVG=$(($TOTAL / ${#TIMES[@]}))
    
    # Calcular mediana
    IFS=$'\n' SORTED=($(sort -n <<<"${TIMES[*]}"))
    unset IFS
    MIDDLE=$((${#SORTED[@]} / 2))
    if [ $((${#SORTED[@]} % 2)) -eq 0 ]; then
        MEDIAN=$(((${SORTED[$MIDDLE-1]} + ${SORTED[$MIDDLE]}) / 2))
    else
        MEDIAN=${SORTED[$MIDDLE]}
    fi
    
    echo -e "${GREEN}Estatísticas de Latência:${NC}"
    echo "  Requisições bem-sucedidas: ${SUCCESS}"
    echo "  Requisições falhadas: ${FAILED}"
    echo "  Taxa de sucesso: $(awk "BEGIN {printf \"%.2f\", (${SUCCESS}/${ITERATIONS})*100}")%"
    echo ""
    echo -e "${GREEN}Tempos de Resposta (ms):${NC}"
    echo "  Mínimo: ${MIN}ms"
    echo "  Máximo: ${MAX}ms"
    echo "  Média: ${AVG}ms"
    echo "  Mediana: ${MEDIAN}ms"
    
    # Calcular percentis
    P95_INDEX=$(awk "BEGIN {printf \"%.0f\", ${#SORTED[@]} * 0.95}")
    P99_INDEX=$(awk "BEGIN {printf \"%.0f\", ${#SORTED[@]} * 0.99}")
    
    if [ $P95_INDEX -lt ${#SORTED[@]} ]; then
        P95=${SORTED[$P95_INDEX]}
        echo "  P95: ${P95}ms"
    fi
    if [ $P99_INDEX -lt ${#SORTED[@]} ]; then
        P99=${SORTED[$P99_INDEX]}
        echo "  P99: ${P99}ms"
    fi
fi

# Teste de latência entre containers
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Teste de Latência entre Containers${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Containers do serviço ${SERVICE_NAME}:${NC}"
docker service ps ${STACK_NAME}_${SERVICE_NAME} --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}"

# Verificar latência de DNS interno do Swarm
echo -e "\n${YELLOW}Testando resolução DNS do serviço...${NC}"
SERVICE_DNS="${STACK_NAME}_${SERVICE_NAME}"
if docker run --rm --network ${STACK_NAME}_fog-network alpine nslookup ${SERVICE_DNS} > /dev/null 2>&1; then
    echo -e "${GREEN}[OK] DNS do servico esta funcionando${NC}"
else
    echo -e "${YELLOW}[AVISO] Nao foi possivel testar DNS (pode ser normal se o container de teste nao conseguir acessar)${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Teste de latência concluído!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${YELLOW}Dicas para melhorar latência:${NC}"
echo "1. Verifique a localização geográfica dos nodes"
echo "2. Use redes overlay otimizadas"
echo "3. Configure healthchecks apropriados"
echo "4. Monitore recursos (CPU, memória, rede) dos nodes"


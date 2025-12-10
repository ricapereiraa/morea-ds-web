#!/bin/bash

# Script master para executar todos os testes do Docker Swarm
# Executa testes de: balanceamento de carga, latência e alta disponibilidade

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Testes Completos do Docker Swarm${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Verificar se está em um ambiente Swarm
if ! docker info | grep -q "Swarm: active"; then
    echo -e "${RED}ERRO: Docker Swarm não está ativo!${NC}"
    echo "Execute no manager: docker swarm init"
    echo "Execute nos workers: docker swarm join --token <TOKEN> <MANAGER_IP>:2377"
    exit 1
fi

# Verificar se os scripts existem
for script in test-load-balancing.sh test-latency.sh test-high-availability.sh; do
    if [ ! -f "${SCRIPT_DIR}/${script}" ]; then
        echo -e "${RED}ERRO: Script ${script} não encontrado!${NC}"
        exit 1
    fi
done

# Menu de opções
echo -e "${YELLOW}Selecione os testes a executar:${NC}"
echo "1) Todos os testes (recomendado)"
echo "2) Apenas balanceamento de carga"
echo "3) Apenas latência"
echo "4) Apenas alta disponibilidade"
echo "5) Balanceamento + Latência"
echo "6) Balanceamento + Alta Disponibilidade"
echo "7) Latência + Alta Disponibilidade"
echo ""
read -p "Escolha uma opção (1-7): " choice

case $choice in
    1)
        echo -e "\n${GREEN}Executando todos os testes...${NC}\n"
        bash "${SCRIPT_DIR}/test-load-balancing.sh"
        echo -e "\n"
        bash "${SCRIPT_DIR}/test-latency.sh"
        echo -e "\n"
        bash "${SCRIPT_DIR}/test-high-availability.sh"
        ;;
    2)
        bash "${SCRIPT_DIR}/test-load-balancing.sh"
        ;;
    3)
        bash "${SCRIPT_DIR}/test-latency.sh"
        ;;
    4)
        bash "${SCRIPT_DIR}/test-high-availability.sh"
        ;;
    5)
        bash "${SCRIPT_DIR}/test-load-balancing.sh"
        echo -e "\n"
        bash "${SCRIPT_DIR}/test-latency.sh"
        ;;
    6)
        bash "${SCRIPT_DIR}/test-load-balancing.sh"
        echo -e "\n"
        bash "${SCRIPT_DIR}/test-high-availability.sh"
        ;;
    7)
        bash "${SCRIPT_DIR}/test-latency.sh"
        echo -e "\n"
        bash "${SCRIPT_DIR}/test-high-availability.sh"
        ;;
    *)
        echo -e "${RED}Opção inválida!${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Todos os testes foram concluídos!${NC}"
echo -e "${GREEN}========================================${NC}\n"


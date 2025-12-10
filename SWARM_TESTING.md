# Guia de Testes para Docker Swarm

Este documento descreve como usar os scripts de teste para validar o funcionamento do Docker Swarm, incluindo balanceamento de carga, latência e alta disponibilidade.

## Pre-requisitos

1. **Docker Swarm configurado** com:
   - 1 Manager
   - 2 ou mais Workers (recomendado)
   
2. **Stack deployado**:
   ```bash
   docker stack deploy -c docker-stack.yml morea
   ```

3. **Ferramentas opcionais** (para testes mais completos):
   - `curl` (geralmente já instalado)
   - `ab` (Apache Bench) - opcional, mas recomendado
   - `watch` - para monitoramento em tempo real

## Scripts Disponiveis

### 1. `test-load-balancing.sh`
Testa o balanceamento de carga entre as réplicas do serviço.

**O que faz:**
- Verifica a distribuição de réplicas nos nodes
- Envia múltiplas requisições HTTP
- Analisa a distribuição de carga
- Mostra logs dos containers para confirmar distribuição

**Uso:**
```bash
./test-load-balancing.sh
```

**Variáveis de ambiente:**
- `STACK_NAME` - Nome do stack (padrão: `morea`)
- `SERVICE_NAME` - Nome do serviço (padrão: `morea_web`)
- `ENDPOINT` - URL do endpoint (padrão: `http://localhost:8000`)
- `REQUESTS` - Número de requisições (padrão: `100`)
- `CONCURRENT` - Requisições concorrentes (padrão: `10`)

**Exemplo:**
```bash
REQUESTS=500 CONCURRENT=20 ./test-load-balancing.sh
```

### 2. `test-latency.sh`
Mede a latência de resposta do serviço e entre nodes.

**O que faz:**
- Testa latência HTTP (tempo de resposta)
- Calcula estatísticas (mínimo, máximo, média, mediana, percentis)
- Verifica latência de rede entre nodes
- Testa resolução DNS do serviço

**Uso:**
```bash
./test-latency.sh
```

**Variáveis de ambiente:**
- `STACK_NAME` - Nome do stack (padrão: `morea`)
- `SERVICE_NAME` - Nome do serviço (padrão: `morea_web`)
- `ENDPOINT` - URL do endpoint (padrão: `http://localhost:8000`)
- `ITERATIONS` - Número de iterações (padrão: `50`)

**Exemplo:**
```bash
ITERATIONS=100 ./test-latency.sh
```

### 3. `test-high-availability.sh`
Testa a alta disponibilidade do sistema.

**O que faz:**
- Verifica topologia do Swarm (managers e workers)
- Testa disponibilidade inicial
- Simula falhas e verifica recuperação
- Verifica política de restart
- Analisa distribuição de réplicas
- Monitora uptime durante o teste

**Uso:**
```bash
./test-high-availability.sh
```

**Variáveis de ambiente:**
- `STACK_NAME` - Nome do stack (padrão: `morea`)
- `SERVICE_NAME` - Nome do serviço (padrão: `morea_web`)
- `ENDPOINT` - URL do endpoint (padrão: `http://localhost:8000`)

### 4. `test-swarm-all.sh`
Script master que executa todos os testes.

**Uso:**
```bash
./test-swarm-all.sh
```

Oferece um menu interativo para escolher quais testes executar.

## Interpretando os Resultados

### Balanceamento de Carga
- **Requisições bem-sucedidas**: Deve ser próximo a 100%
- **Distribuição**: Verifique os logs para confirmar que requisições estão sendo distribuídas entre réplicas
- **Tempo de resposta**: Deve ser consistente entre requisições

### Latência
- **Tempo médio**: Idealmente < 200ms para requisições locais
- **P95/P99**: Percentis mostram a latência para 95% e 99% das requisições
- **Taxa de sucesso**: Deve ser 100% ou próximo disso

### Alta Disponibilidade
- **Uptime**: Deve ser próximo a 100% mesmo durante falhas simuladas
- **Réplicas**: Mínimo de 2 réplicas distribuídas em nodes diferentes
- **Política de restart**: Deve estar configurada (on-failure ou any)
- **Healthcheck**: Recomendado para detecção rápida de problemas

## Configuracao Recomendada para HA

Para uma configuração robusta de alta disponibilidade:

1. **Topologia mínima:**
   - 1 Manager
   - 2 Workers

2. **Configuração do serviço:**
   ```yaml
   deploy:
     replicas: 2  # Mínimo 2 réplicas
     placement:
       constraints:
         - node.role != manager  # Distribuir em workers
     restart_policy:
       condition: on-failure
     update_config:
       parallelism: 1
       delay: 10s
   ```

3. **Healthcheck:**
   ```yaml
   healthcheck:
     test: ["CMD", "curl", "-f", "http://localhost:8000/"]
     interval: 30s
     timeout: 10s
     retries: 3
     start_period: 40s
   ```

## Troubleshooting

### "Docker Swarm não está ativo"
```bash
# No manager:
docker swarm init --advertise-addr <MANAGER_IP>

# Nos workers:
docker swarm join --token <TOKEN> <MANAGER_IP>:2377
```

### "Serviço não encontrado"
```bash
# Verificar se o stack está deployado:
docker stack ls

# Deploy do stack:
docker stack deploy -c docker-stack.yml morea

# Verificar serviços:
docker stack services morea
```

### "Apenas 1 réplica encontrada"
```bash
# Escalar o serviço:
docker service scale morea_web=2

# Verificar:
docker service ps morea_web
```

### Requisições falhando
- Verifique se o endpoint está correto
- Verifique se o serviço está rodando: `docker service ps morea_web`
- Verifique logs: `docker service logs morea_web`
- Verifique firewall/portas

## Monitoramento em Tempo Real

### Ver status do serviço:
```bash
watch -n 1 'docker service ps morea_web'
```

### Ver logs em tempo real:
```bash
docker service logs -f morea_web
```

### Ver estatísticas do Swarm:
```bash
docker node ls
docker service ls
docker stack ps morea
```

## Exemplos de Uso

### Teste completo antes de produção:
```bash
./test-swarm-all.sh
# Escolha opção 1 (Todos os testes)
```

### Teste rápido de latência:
```bash
ITERATIONS=20 ./test-latency.sh
```

### Teste de carga com muitas requisições:
```bash
REQUESTS=1000 CONCURRENT=50 ./test-load-balancing.sh
```

### Teste de HA durante atualização:
```bash
# Terminal 1: Executar teste
./test-high-availability.sh

# Terminal 2: Atualizar serviço
docker service update --image nova-imagem:tag morea_web
```

## Notas Importantes

1. **Testes com 1 Manager e 2 Workers são suficientes** para validar alta disponibilidade básica
2. **Para produção**, considere:
   - 3 ou 5 Managers (para quorum)
   - Múltiplos Workers distribuídos geograficamente
   - Healthchecks configurados
   - Monitoramento contínuo

3. **Os testes são não-destrutivos** - não param ou removem containers, apenas verificam o estado atual

4. **Para testes mais realistas**, execute os scripts de diferentes nodes do Swarm

## Referencias

- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Traefik Load Balancing](https://doc.traefik.io/traefik/routing/services/)
- [High Availability Best Practices](https://docs.docker.com/engine/swarm/admin_guide/)


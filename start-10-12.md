

## Acesso SSH aos nós (Swarm)
- Manager: `ssh pirate@192.168.1.80`
- Worker01: `ssh pirate@192.168.1.81`
- Worker02: `ssh pirate@192.168.1.82`

# Atualizar código local (no manager)
```bash
cd /opt/morea-ds-web/morea-ds-web-main/
git pull https://github.com/evertonsantos2021/morea-ds-web.git
# se o remoto já estiver configurado:
# git pull
```

# Start 10/12 — Guia Rápido (Dev/Test)

## Subir a aplicação (Compose local)
```bash
docker compose up -d
```

## Migrações e estáticos
```bash
docker compose exec web python manage.py migrate
docker compose exec web python manage.py collectstatic --noinput --clear
```

## Popular dados de teste (opcional)
Gera dispositivos, leituras e gráficos de exemplo.
```bash
docker compose exec web python populate_test_data.py
docker compose restart web
```

Se houver erro de permissão ao gerar gráficos:
```bash
chmod -R 777 media
docker compose exec -u root web sh -c "mkdir -p /app/media/graphs && chmod -R 777 /app/media"
docker compose exec web python populate_test_data.py
docker compose restart web
```

## Endpoints
- App: http://localhost:8000
- Dashboard: http://localhost:8000/dashboard
- Traefik (se aplicado): http://localhost

---

# Testes de Swarm
Scripts já prontos na raiz do projeto:
- `test-load-balancing.sh`
- `test-latency.sh`
- `test-high-availability.sh`
- `test-swarm-all.sh` (menu para rodar todos/combinações)

Requisitos:
- Swarm ativo (`docker swarm init` no manager; `docker swarm join …` nos workers).
- Stack deployado (ex.: `docker stack deploy -c docker-stack.yml morea`).
- Opcional: `curl`, `ab` (Apache Bench) instalados na máquina de testes.

## Teste de Balanceamento de Carga
```bash
./test-load-balancing.sh
```
Variáveis úteis:
- `STACK_NAME` (padrão: morea)
- `SERVICE_NAME` (padrão: morea_web)
- `ENDPOINT` (padrão: http://localhost:8000)
- `REQUESTS` (padrão: 100), `CONCURRENT` (padrão: 10)

Exemplo:
```bash
REQUESTS=500 CONCURRENT=20 ./test-load-balancing.sh
```

## Teste de Latência
```bash
./test-latency.sh
```
Variáveis:
- `STACK_NAME`, `SERVICE_NAME`, `ENDPOINT` (padrão: http://localhost:8000)
- `ITERATIONS` (padrão: 50)

Exemplo:
```bash
ITERATIONS=100 ./test-latency.sh
```

## Teste de Alta Disponibilidade
```bash
./test-high-availability.sh
```
Checa topologia (manager/workers), uptime durante falha simulada, política de restart e distribuição de réplicas. Recomendado: 1 manager + 2 workers (mínimo).

## Teste Completo (menu)
```bash
./test-swarm-all.sh
```
Permite rodar todos os testes ou combinações. Use quando quiser validar rapidamente antes de produção.

---

# Dicas rápidas
- Ver status dos containers (compose): `docker compose ps`
- Logs do serviço web: `docker compose logs web -f`
- Rebuild rápido: `docker compose build web && docker compose up -d`
- Se estiver em Swarm: `docker stack services morea` e `docker service ps morea_web`


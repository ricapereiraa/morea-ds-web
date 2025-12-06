# Guia de Build e Deploy da Imagem Morea

## Pré-requisitos
- Docker instalado no manager (192.168.1.80)
- SSH configurado para acessar o manager (usuário padrão: `pi`)
- Código do Morea clonado/copiado no manager em `/home/pi/morea`
- `.env.swarm` já atualizado com os IPs corretos (MOREA_HOST_IP=192.168.1.136)

## Opção 1: Build no Manager via Script Bash (Recomendado para RPi3)

No manager (Raspberry Pi 192.168.1.80), execute:

```bash
# SSH para o manager
ssh pi@192.168.1.80

# Entre no diretório do código
cd /home/pi/morea

# (Opcional) Crie um registry local se ainda não tiver
docker run -d --restart=always -p 5000:5000 --name registry registry:2

# Dê permissão de execução ao script
chmod +x build-image.sh

# Build local (sem push, para testes rápidos)
./build-image.sh

# Ou, build + push para registry local
./build-image.sh 192.168.1.80:5000 latest
```

**O que o script faz:**
1. Valida o Dockerfile
2. Constrói a imagem (`docker build`)
3. Opcionalmente faz push para um registry
4. Pronto para deploy com `docker stack deploy`

## Opção 2: Build via PowerShell (Do seu Workstation Windows)

No seu computador Windows (onde você tem PowerShell):

```powershell
# Navegue até o diretório do repositório
cd C:\Users\Cliente MTech\Downloads\morea-ds-web-main\morea-ds-web-main

# Execute o script com SSH (conecta ao manager, faz build lá)
.\build-image.ps1 -ManagerIP "192.168.1.80" -Registry "192.168.1.80:5000" -UseSSH $true

# Ou, build local (apenas para testes, não recomendado para RPi3):
.\build-image.ps1 -UseSSH $false
```

**Parâmetros do script:**
- `-ManagerIP`: IP do manager (padrão: "192.168.1.80")
- `-Registry`: URL do registry (padrão: "192.168.1.80:5000")
- `-Tag`: Tag da imagem (padrão: "latest")
- `-UseSSH`: `$true` para build no manager, `$false` para build local

## Opção 3: Build Manualmente (Passo a Passo)

Se preferir controle total, execute no manager:

```bash
ssh pi@192.168.1.80
cd /home/pi/morea

# 1. Build a imagem
docker build -t morea-app:latest .

# 2. (Opcional) Push para registry local
docker tag morea-app:latest 192.168.1.80:5000/morea-app:latest
docker push 192.168.1.80:5000/morea-app:latest

# 3. Verifique a imagem
docker images | grep morea

# 4. Deploy (próximo passo)
docker stack deploy -c docker-stack.yml morea --with-registry-auth
```

## Configurar Registry Local (Opcional)

Se quiser usar um registry local para armazenar imagens:

```bash
# No manager (uma vez)
docker run -d \
  --restart=always \
  -p 5000:5000 \
  --name registry \
  -v /mnt/registry:/var/lib/registry \
  registry:2

# Verifique se está rodando
docker ps | grep registry
```

## Atualizar `docker-stack.yml` com a Imagem Correta

Abra `docker-stack.yml` e garanta que o campo `image` aponta para a imagem que você criou:

```yaml
services:
  web:
    image: morea-app:latest  # Ou: 192.168.1.80:5000/morea-app:latest se usar registry
    # ... rest of config
```

Se usar registry local, atualize para:
```yaml
image: 192.168.1.80:5000/morea-app:latest
```

## Deploy no Swarm (Próximo Passo)

Após o build estar completo, no manager execute:

```bash
# Copie os arquivos necessários (se ainda não estiverem lá)
scp docker-stack.yml pi@192.168.1.80:/home/pi/morea/
scp .env.swarm pi@192.168.1.80:/home/pi/morea/

# SSH para o manager e deploy
ssh pi@192.168.1.80
cd /home/pi/morea

# Deploy a stack
docker stack deploy -c docker-stack.yml morea --with-registry-auth

# Verifique se os serviços estão rodando
docker service ls
docker service ps morea_web

# Veja os logs
docker service logs morea_web --tail 50
```

## Troubleshooting

### Build falha com erro de APT
Se receber erros como `Sub-process returned an error code`, isso já foi corrigido no Dockerfile. Se persistir:
- Aumente o espaço em disco no RPi
- Reduza dependências em `requirements.txt`
- Tente novamente

### Push falha (registry não encontrado)
- Garanta que registry está rodando: `docker ps | grep registry`
- Se registry está em outro host, use `http://` na URL (insecure): edite `/etc/docker/daemon.json` e adicione `"insecure-registries": ["192.168.1.80:5000"]`

### Stack não inicia (serviço fica em pending)
- Verifique a imagem: `docker images | grep morea`
- Verifique logs: `docker service logs morea_web`
- Garanta que `.env.swarm` está no mesmo diretório que `docker-stack.yml`
- Se usar registry, verifique que todos os nodes podem acessar (configurar `/etc/docker/daemon.json`)

### Imagem é muito grande (RPi3 fica lento/sem espaço)
- Reduza o tamanho do `requirements.txt` (remova pacotes não essenciais)
- Use multi-stage builds (avançado)
- Considere desabilitar Traefik/Prometheus se não usar

## Referências
- [Docker Stack Deploy Docs](https://docs.docker.com/engine/reference/commandline/stack_deploy/)
- [Docker Registry Setup](https://docs.docker.com/registry/)
- [Docker Swarm Overlay Networks](https://docs.docker.com/network/overlay/)


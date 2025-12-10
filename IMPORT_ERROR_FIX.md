# Plotly import diagnostics (atualizado em dezembro/2025)

## O que mudou?
Os gráficos HTML agora são gerados diretamente com `plotly.graph_objects`, eliminando a dependência do `pandas`. O erro `ImportError: Plotly express requires pandas` não deve mais ocorrer em builds recentes. Caso você ainda veja essa mensagem, provavelmente está executando uma imagem antiga: faça rebuild seguindo as etapas abaixo.

## Soluções rápidas

### Solução 1: Rebuild com cache limpo (recomendado)

No manager (192.168.1.80):

```bash
ssh pi@192.168.1.80
cd /home/pi/morea

# Rebuild sem cache (força reinstalação de todas as camadas)
docker build --no-cache -t morea-ds-web:latest .

# Tag para Docker Hub
docker tag morea-ds-web:latest evertonsantos2025/morea-ds-web:latest

# Push para Docker Hub
docker push evertonsantos2025/morea-ds-web:latest

# Atualizar stack (puxará a nova imagem)
docker stack rm morea
docker stack deploy -c docker-stack.yml morea --with-registry-auth

# Verificar status
docker service ls
docker service logs morea_web --tail 100 --follow
```

### Solução 2: Diagnóstico no container rodando

Se preferir entender exatamente o que está faltando:

```bash
# Obter o ID/nome do container
docker ps | grep morea_web

# Ou listar tasks do serviço
docker service ps morea_web

# Executar diagnóstico (substitua <container_id_or_name>)
docker exec <container_id_or_name> python /tmp/diagnose_imports.py
```

Isso mostrará:
- Quais pacotes estão instalados
- Quais imports funcionam/falham
- Mensagens de erro específicas

### Solução 3: Fix manual no container (emergencial, não persiste ao reiniciar)

Se o serviço estiver rodando e quiser verificar rápido:

```bash
# Entre no container
docker exec -it <container_id> /bin/bash

# Dentro do container, apenas garanta a presença do Plotly
pip install --upgrade plotly

# Teste o import com a nova stack
python3 -c "import plotly.graph_objects as go; print('OK')"

# Saia
exit
```

⚠️ Essa mudança não persiste quando o container reinicia. Para persistir, você deve fazer rebuild do Docker.

## Verificação da imagem antes de deploy

Antes de fazer push/deploy, teste localmente:

```bash
# Build localmente
docker build -t morea-ds-web:test .

# Execute um container de teste
docker run --rm morea-ds-web:test python3 -c "import plotly.graph_objects as go; print('✓ Plotly OK')"
```

Se esse comando retornar "All imports OK", a imagem está boa.

## Se ainda falhar após rebuild

1. Verifique `requirements.txt` — `plotly` deve estar presente.
2. Se o problema for conexão ao PyPI durante build, considere usar um mirror/cache local:
   - Aumentar timeout: `pip install --default-timeout=1000 -r requirements.txt`
   - Ou compilar em uma máquina com melhor conectividade

## Checklist rápido

- [ ] `plotly` está em `requirements.txt`?
- [ ] Rebuild com `--no-cache` foi executado?
- [ ] Nova imagem foi enviada para o Docker Hub?
- [ ] Stack foi atualizada (`docker stack deploy`)?
- [ ] Container consegue fazer import de `plotly.graph_objects`?

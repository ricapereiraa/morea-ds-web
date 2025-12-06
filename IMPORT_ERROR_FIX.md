# Solução para erro "ImportError: Plotly express requires pandas"

## Causa provável
O erro ocorre quando:
1. `pandas` não foi instalado corretamente durante o build Docker
2. Há conflito entre versões de `pandas` e `plotly`
3. A instalação foi interrompida (falta `|| true` mascarando o erro)

## Soluções Rápidas

### Solução 1: Rebuild com cache limpo (Recomendado)

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

### Solução 3: Fix manual no container (Emergencial, não persiste ao reiniciar)

Se o serviço estiver rodando e quiser verificar rápido:

```bash
# Entre no container
docker exec -it <container_id> /bin/bash

# Dentro do container, reinstale pandas
pip install --upgrade pandas plotly

# Teste o import
python3 -c "import plotly.express; print('OK')"

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
docker run --rm morea-ds-web:test python3 -c "import pandas; import plotly.express; print('✓ All imports OK')"
```

Se esse comando retornar "All imports OK", a imagem está boa.

## Se ainda falhar após rebuild

1. Verifique `requirements.txt` — certifique-se de que `pandas` e `plotly` estão presentes.
2. Verifique a ordem — `numpy` e `pandas` devem vir antes de `plotly`:
   ```
   numpy==1.26.4
   pandas==2.2.0
   plotly==5.19.0
   ```
3. Se o problema for conexão ao PyPI durante build, considere usar um mirror/cache local:
   - Aumentar timeout: `pip install --default-timeout=1000 -r requirements.txt`
   - Ou compilar em uma máquina com melhor conectividade

## Checklist rápido

- [ ] `pandas` e `plotly` estão em `requirements.txt`?
- [ ] Rebuild com `--no-cache` foi executado?
- [ ] Nova imagem foi pushed para Docker Hub?
- [ ] Stack foi atualizada (`docker stack deploy`)?
- [ ] Container consegue fazer import de `plotly.express`?

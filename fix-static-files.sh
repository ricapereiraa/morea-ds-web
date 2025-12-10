#!/bin/bash

# Script para diagnosticar e corrigir problemas com arquivos estáticos

echo "=========================================="
echo "Diagnostico de Arquivos Estaticos"
echo "=========================================="
echo ""

# Verificar se o container está rodando
echo "1. Verificando status do container..."
if docker compose ps 2>/dev/null | grep -q "morea_web.*Up"; then
    echo "[OK] Container esta rodando"
    CONTAINER_RUNNING=true
else
    echo "[ERRO] Container nao esta rodando ou precisa de sudo"
    CONTAINER_RUNNING=false
fi

echo ""
echo "2. Verificando arquivos estaticos no container..."
if [ "$CONTAINER_RUNNING" = true ]; then
    echo "Verificando /app/staticfiles/..."
    docker compose exec web ls -la /app/staticfiles/ 2>/dev/null | head -10 || echo "  [AVISO] Nao foi possivel verificar (pode precisar de sudo)"
    
    echo ""
    echo "Verificando /app/static/..."
    docker compose exec web ls -la /app/static/ 2>/dev/null | head -10 || echo "  [AVISO] Nao foi possivel verificar (pode precisar de sudo)"
fi

echo ""
echo "3. Testando acesso aos arquivos estaticos..."
STATIC_FILES=(
    "/static/css/layout/layout.css"
    "/static/css/home.css"
    "/static/js/menu.js"
)

for file in "${STATIC_FILES[@]}"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:8000${file}" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo "[OK] ${file} - HTTP ${HTTP_CODE}"
    else
        echo "[ERRO] ${file} - HTTP ${HTTP_CODE}"
    fi
done

echo ""
echo "=========================================="
echo "Solucoes Recomendadas"
echo "=========================================="
echo ""
echo "Se os arquivos estaticos estao retornando 404:"
echo ""
echo "1. Reconstruir a imagem (pode falhar se nao tiver internet):"
echo "   sudo docker compose build web"
echo ""
echo "2. OU executar collectstatic manualmente no container:"
echo "   sudo docker compose exec web python manage.py collectstatic --noinput"
echo ""
echo "3. Verificar se DEBUG=True no .env:"
echo "   grep DEBUG .env"
echo ""
echo "4. Verificar logs do container:"
echo "   sudo docker compose logs web | tail -50"
echo ""
echo "5. Se o problema persistir, reiniciar o container:"
echo "   sudo docker compose restart web"
echo ""


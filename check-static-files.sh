#!/bin/bash

# Script para verificar se os arquivos estáticos estão sendo servidos corretamente

ENDPOINT=${1:-"http://localhost:8000"}

echo "Verificando arquivos estaticos em: ${ENDPOINT}"
echo ""

# Lista de arquivos estáticos importantes para verificar
STATIC_FILES=(
    "/static/css/layout/layout.css"
    "/static/css/home.css"
    "/static/js/menu.js"
    "/static/assets/images/logo-morea-ds-noname.png"
)

SUCCESS=0
FAILED=0

for file in "${STATIC_FILES[@]}"; do
    URL="${ENDPOINT}${file}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${URL}" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "[OK] ${file} - HTTP ${HTTP_CODE}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "[ERRO] ${file} - HTTP ${HTTP_CODE}"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "Resultado: ${SUCCESS} sucesso, ${FAILED} falhas"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo "Problemas encontrados:"
    echo "1. Verifique se o container esta rodando: docker compose ps"
    echo "2. Verifique os logs: docker compose logs web | grep -i static"
    echo "3. Verifique se collectstatic foi executado: docker compose exec web ls -la /app/staticfiles/"
    echo "4. Verifique DEBUG no .env: grep DEBUG .env"
    exit 1
else
    echo ""
    echo "Todos os arquivos estaticos estao sendo servidos corretamente!"
    exit 0
fi


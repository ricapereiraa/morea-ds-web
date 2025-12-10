#!/bin/bash

# Script rápido para corrigir arquivos estáticos sem rebuild

echo "Corrigindo arquivos estaticos..."
echo ""

# Executar collectstatic no container
echo "1. Executando collectstatic..."
sudo docker compose exec web python manage.py collectstatic --noinput --clear

echo ""
echo "2. Reiniciando container..."
sudo docker compose restart web

echo ""
echo "3. Aguardando container iniciar..."
sleep 5

echo ""
echo "4. Testando arquivos estaticos..."
STATIC_FILE="/static/css/layout/layout.css"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:8000${STATIC_FILE}" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo "[OK] Arquivos estaticos estao funcionando! (HTTP ${HTTP_CODE})"
    echo ""
    echo "Acesse: http://localhost:8000"
    echo "O frontend deve estar renderizando corretamente agora."
else
    echo "[ERRO] Arquivos estaticos ainda nao estao acessiveis (HTTP ${HTTP_CODE})"
    echo ""
    echo "Tente:"
    echo "1. Verificar logs: sudo docker compose logs web | tail -30"
    echo "2. Verificar se DEBUG=True: grep DEBUG .env"
    echo "3. Reconstruir: sudo docker compose build web && sudo docker compose up -d"
fi


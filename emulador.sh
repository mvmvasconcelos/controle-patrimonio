#!/bin/bash

# 1. Check and Start Proxy
if pgrep -f "scripts/adb_proxy.py" > /dev/null; then
    echo "O Proxy já está rodando."
else
    echo "Iniciando Proxy ADB..."
    nohup python3 -u scripts/adb_proxy.py > proxy.log 2>&1 &
    sleep 1 # Give it a moment to bind
    echo "Proxy iniciado."
fi

# 2. Check and Connect Flutter Container
if docker-compose ps --services --filter "status=running" | grep -q "flutter"; then
    echo "Container Flutter está rodando. Usando 'exec'..."
    docker-compose exec flutter ./scripts/connect_emulator.sh
else
    echo "Container Flutter NÃO está rodando."
    echo "Iniciando agora..."
    docker-compose up -d flutter
    echo "Aguardando inicialização do container..."
    sleep 5
    docker-compose exec flutter ./scripts/connect_emulator.sh
fi
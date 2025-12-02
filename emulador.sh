#!/bin/bash

# Check if the flutter container is running
if docker-compose ps --services --filter "status=running" | grep -q "flutter"; then
    echo "Flutter container is running. Using 'exec'..."
    docker-compose exec flutter ./scripts/connect_emulator.sh
else
    echo "Flutter container is NOT running."
    echo "Starting it now..."
    docker-compose up -d flutter
    echo "Waiting for container to initialize..."
    sleep 5
    docker-compose exec flutter ./scripts/connect_emulator.sh
fi
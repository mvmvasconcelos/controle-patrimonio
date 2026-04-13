#!/bin/bash

# Detect if running in Docker
# Detect if running in Docker
if [ -f /.dockerenv ]; then
    echo "Rodando dentro do container Docker."
    # In Docker, we use the internal ADB client to connect to the proxy
    # The proxy is at host.docker.internal:5556
    echo "Conectando ao emulador via proxy..."
    adb connect host.docker.internal:5556
else
    echo "Rodando na máquina Host."
    ADB_LOCAL="$(pwd)/tools/android-sdk/platform-tools"
    if [ -d "$ADB_LOCAL" ]; then
        export PATH="$ADB_LOCAL:$PATH"
    fi
    echo "Conectando ao emulador via localhost..."
    adb connect localhost:5555
fi

echo ""
echo "Verificando dispositivos..."
adb devices

echo ""
echo "Se você ver seu emulador acima (host.docker.internal:5556), você pode rodar 'flutter run'."

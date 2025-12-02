#!/bin/bash

# Detect if running in Docker
if [ -f /.dockerenv ]; then
    echo "Running inside Docker container."
    # In Docker, we use the internal ADB client to connect to the proxy
    # The proxy is at host.docker.internal:5556
    echo "Connecting to emulator via proxy..."
    adb connect host.docker.internal:5556
else
    echo "Running on Host machine."
    ADB_LOCAL="$(pwd)/tools/android-sdk/platform-tools"
    if [ -d "$ADB_LOCAL" ]; then
        export PATH="$ADB_LOCAL:$PATH"
    fi
    echo "Connecting to emulator via localhost..."
    adb connect localhost:5555
fi

echo ""
echo "Checking for devices..."
adb devices

echo ""
echo "If you see your emulator above (host.docker.internal:5556), you can now run 'flutter run'."

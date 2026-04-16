#!/bin/bash
set -euo pipefail

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }
log_error() { echo "[ERRO] $1" >&2; }

if ! command -v adb >/dev/null 2>&1; then
    log_error "adb nao encontrado no PATH."
    exit 1
fi

adb start-server >/dev/null 2>&1 || true

if [[ -f /.dockerenv ]]; then
    log_info "Rodando dentro do container Docker."
    log_info "Conectando ao emulador via proxy host.docker.internal:5556..."
    adb connect host.docker.internal:5556 || true
else
    log_info "Rodando no host."
    ADB_LOCAL="$(pwd)/tools/android-sdk/platform-tools"
    if [[ -d "$ADB_LOCAL" ]]; then
        export PATH="$ADB_LOCAL:$PATH"
    fi
    log_info "Conectando ao emulador via localhost:5555..."
    adb connect localhost:5555 || true
fi

echo
log_info "Dispositivos ADB detectados:"
DEVICES_OUTPUT="$(adb devices)"
echo "$DEVICES_OUTPUT"

if echo "$DEVICES_OUTPUT" | grep -q "host.docker.internal:5556[[:space:]]\+offline"; then
    log_warn "Dispositivo em estado offline. Tentando reconectar..."
    adb disconnect host.docker.internal:5556 || true
    adb kill-server || true
    adb start-server || true
    adb connect host.docker.internal:5556 || true

    echo
    log_info "Dispositivos ADB apos tentativa de reconexao:"
    adb devices
fi

echo
log_warn "Se o estado for 'unauthorized', aceite o popup de depuracao no emulador e execute novamente."

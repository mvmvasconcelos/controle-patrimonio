#!/bin/bash
set -euo pipefail

readonly PROXY_SCRIPT="scripts/adb_proxy.py"
readonly CONNECT_SCRIPT="./scripts/connect_emulator.sh"
readonly PROXY_LOG="proxy.log"
readonly TUNNEL_HOST="127.0.0.1"
readonly TUNNEL_PORT="5557"
readonly PROXY_PORT="5556"

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }
log_error() { echo "[ERRO] $1" >&2; }

check_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Comando obrigatorio nao encontrado: $cmd"
        exit 1
    fi
}

check_tunnel() {
    if timeout 1 bash -c "</dev/tcp/${TUNNEL_HOST}/${TUNNEL_PORT}" >/dev/null 2>&1; then
        log_info "Tunel SSH detectado em ${TUNNEL_HOST}:${TUNNEL_PORT}."
    else
        log_warn "Tunel SSH nao detectado em ${TUNNEL_HOST}:${TUNNEL_PORT}."
        log_warn "Sem tunel, o proxy nao consegue alcancar o emulador remoto."
        log_warn "Verifique o RemoteForward 5557 -> 127.0.0.1:5555 na sua sessao SSH."
    fi
}

start_proxy_if_needed() {
    if pgrep -f "$PROXY_SCRIPT" >/dev/null; then
        log_info "Proxy ADB ja esta rodando."
        return
    fi

    log_info "Iniciando proxy ADB em 0.0.0.0:${PROXY_PORT}..."
    nohup python3 -u "$PROXY_SCRIPT" > "$PROXY_LOG" 2>&1 &
    sleep 1

    if pgrep -f "$PROXY_SCRIPT" >/dev/null; then
        log_info "Proxy iniciado. Logs em ${PROXY_LOG}."
    else
        log_error "Falha ao iniciar proxy ADB."
        exit 1
    fi
}

ensure_flutter_running() {
    if docker-compose ps --services --filter "status=running" | grep -q "^flutter$"; then
        log_info "Container flutter ja esta rodando."
        return
    fi

    log_info "Subindo container flutter..."
    docker-compose up -d flutter
    sleep 3
}

connect_from_container() {
    log_info "Conectando ADB do container ao proxy..."
    docker-compose exec -T flutter "$CONNECT_SCRIPT"

    log_info "Verificando dispositivos no container..."
    docker-compose exec -T flutter sh -lc "adb devices"
}

main() {
    check_cmd docker-compose
    check_cmd python3
    check_cmd timeout

    if [[ ! -f "$PROXY_SCRIPT" ]]; then
        log_error "Arquivo nao encontrado: $PROXY_SCRIPT"
        exit 1
    fi

    check_tunnel
    start_proxy_if_needed
    ensure_flutter_running
    connect_from_container

    echo
    log_info "Se o emulador aparecer como device, rode o app com:"
    log_info "docker-compose exec -T flutter sh -lc 'flutter run'"
}

main "$@"
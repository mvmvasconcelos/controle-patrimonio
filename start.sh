#!/bin/bash
set -euo pipefail

# ============================================
# Flutter Docker Manager Script
# ============================================
# Propósito: Gerenciar container Docker Flutter
# Uso: ./start.sh

# Configurações
readonly PROJECT_NAME="controle-patrimonio"
readonly CONTAINER_NAME="${PROJECT_NAME}-flutter"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# Funções de Logging
# ============================================
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo "[✓] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_warning() {
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# ============================================
# Funções de Verificação
# ============================================
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker não está instalado"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker não está rodando ou você não tem permissão"
        return 1
    fi
    
    log_info "Docker detectado e funcionando"
    return 0
}

check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose não está instalado"
        return 1
    fi
    
    log_info "docker-compose detectado"
    return 0
}

is_container_running() {
    docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# ============================================
# Funções Principais
# ============================================
start_container() {
    log_info "=========================================="
    log_info "Iniciando Ambiente Flutter Docker"
    log_info "=========================================="
    
    cd "$SCRIPT_DIR"
    
    if is_container_running; then
        log_warning "Container já está rodando!"
        show_status
        return 0
    fi
    
    log_info "Subindo container com docker-compose..."
    if docker-compose up -d; then
        log_success "Container iniciado com sucesso!"
        echo ""
        
        # Aguardar um pouco para o container inicializar
        sleep 3
        
        # Mostrar logs de inicialização
        log_info "Logs de inicialização:"
        echo "=========================================="
        docker logs "$CONTAINER_NAME" 2>&1 | tail -30
        echo "=========================================="
        echo ""
        
        show_status
        show_usage
    else
        log_error "Falha ao iniciar container"
        return 1
    fi
}

stop_container() {
    log_info "Parando container..."
    
    cd "$SCRIPT_DIR"
    
    if ! is_container_running; then
        log_warning "Container não está rodando"
        return 0
    fi
    
    if docker-compose down; then
        log_success "Container parado com sucesso!"
    else
        log_error "Falha ao parar container"
        return 1
    fi
}

restart_container() {
    log_info "Reiniciando container..."
    stop_container
    sleep 2
    start_container
}

show_status() {
    log_info "Status do container:"
    echo "=========================================="
    docker-compose ps
    echo "=========================================="
}

show_logs() {
    if ! is_container_running; then
        log_error "Container não está rodando"
        return 1
    fi
    
    log_info "Exibindo logs (Ctrl+C para sair)..."
    docker-compose logs -f flutter
}

access_container() {
    if ! is_container_running; then
        log_error "Container não está rodando. Execute './start.sh' primeiro"
        return 1
    fi
    
    log_info "Acessando container..."
    docker-compose exec flutter bash
}

show_usage() {
    echo ""
    log_info "=========================================="
    log_info "Comandos Disponíveis:"
    log_info "=========================================="
    echo ""
    echo "  📦 Gerenciamento:"
    echo "     ./start.sh              - Iniciar container"
    echo "     ./start.sh stop         - Parar container"
    echo "     ./start.sh restart      - Reiniciar container"
    echo "     ./start.sh status       - Ver status"
    echo "     ./start.sh logs         - Ver logs em tempo real"
    echo ""
    echo "  🔧 Acesso:"
    echo "     ./start.sh bash         - Acessar container (bash)"
    echo "     docker-compose exec flutter bash  (alternativa)"
    echo ""
    echo "  📱 Desenvolvimento:"
    echo "     ./compila.sh [patch|minor|major]  - Compilar APK"
    echo "     ./share.sh                        - Compartilhar APK via HTTP temporario"
    echo "     (scripts opcionais; fluxo principal atual usa compila.sh + share.sh)"
    echo ""
    log_info "=========================================="
}

# ============================================
# Função Principal
# ============================================
main() {
    # Verificar dependências
    if ! check_docker; then
        exit 1
    fi
    
    if ! check_docker_compose; then
        exit 1
    fi
    
    # Processar comando
    case "${1:-start}" in
        start)
            start_container
            ;;
        stop)
            stop_container
            ;;
        restart)
            restart_container
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        bash|shell|exec)
            access_container
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Comando desconhecido: $1"
            show_usage
            exit 1
            ;;
    esac
}

# ============================================
# Executar
# ============================================
main "$@"

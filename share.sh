#!/bin/bash
set -euo pipefail

# ============================================
# Script de Compartilhamento APK - Controle Patrimônio
# ============================================
# Propósito: Servir APK via servidor HTTP temporário
# Uso: ./compartilha.sh

# Configurações
readonly SERVER_HOST="128.1.1.49"
readonly SERVER_PORT="8090"
readonly APK_NAME="controle-patrimonio.apk"

# Cores para output
readonly COLOR_RESET='\033[0m'
readonly COLOR_INFO='\033[0;36m'
readonly COLOR_SUCCESS='\033[0;32m'
readonly COLOR_ERROR='\033[0;31m'
readonly COLOR_WARNING='\033[0;33m'

# Funções de logging
log_info() { echo -e "${COLOR_INFO}[INFO]${COLOR_RESET} $1"; }
log_success() { echo -e "${COLOR_SUCCESS}[✓]${COLOR_RESET} $1"; }
log_error() { echo -e "${COLOR_ERROR}[ERROR]${COLOR_RESET} $1" >&2; }
log_warning() { echo -e "${COLOR_WARNING}[WARNING]${COLOR_RESET} $1"; }

# ============================================
# Verificar se APK existe
# ============================================
check_apk_exists() {
  if ! docker-compose exec -T flutter test -f "web/apk/${APK_NAME}" 2>/dev/null; then
    log_error "APK não encontrado!"
    log_info "Execute primeiro: ./compilaApk.sh"
    return 1
  fi
  return 0
}

# ============================================
# Função principal
# ============================================
main() {
  log_info "=========================================="
  log_info "🌐 Servidor de Compartilhamento APK"
  log_info "=========================================="
  
  # Verificar se APK existe
  if ! check_apk_exists; then
    exit 1
  fi
  
  log_success "APK encontrado!"
  echo ""
  
  # Criar trap para limpar ao sair
  cleanup() {
    echo ""
    log_info "Encerrando servidor..."
    docker-compose exec -T flutter pkill -f "python3 /tmp/http_server.py" 2>/dev/null || true
    docker-compose exec -T flutter rm -f /tmp/http_server.py 2>/dev/null || true
    sleep 1
    log_success "Servidor encerrado. Links não estão mais acessíveis (404)."
  }
  trap cleanup EXIT INT TERM
  
  # Iniciar servidor em background dentro do container
  log_info "Iniciando servidor HTTP..."
  
  # Matar qualquer servidor anterior na porta
  docker-compose exec -T flutter pkill -f "python3 /tmp/http_server.py" 2>/dev/null || true
  docker-compose exec -T flutter pkill -f "python3 -m http.server ${SERVER_PORT}" 2>/dev/null || true
  sleep 1
  
  # Criar script Python para servidor com tratamento de erros
  docker-compose exec -T flutter bash -c "cat > /tmp/http_server.py << 'PYTHON_SCRIPT'
import http.server
import socketserver
import sys

class QuietHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        # Log com IP do cliente
        client_ip = self.address_string()
        sys.stderr.write(\"[%s] %s - %s\n\" %
                         (self.log_date_time_string(),
                          client_ip,
                          format%args))
    
    def copyfile(self, source, outputfile):
        # Tratamento para BrokenPipeError (download cancelado)
        try:
            super().copyfile(source, outputfile)
        except (BrokenPipeError, ConnectionResetError):
            # Cliente cancelou o download - é normal, apenas ignora
            pass

PORT = ${SERVER_PORT}
Handler = QuietHTTPRequestHandler

with socketserver.TCPServer((\"\", PORT), Handler) as httpd:
    httpd.serve_forever()
PYTHON_SCRIPT"
  
  # Iniciar servidor usando nohup para rodar em background
  docker-compose exec -T flutter bash -c "cd web && nohup python3 /tmp/http_server.py > /tmp/server.log 2>&1 &"
  
  # Aguardar servidor iniciar
  sleep 3
  
  # Verificar se servidor está rodando
  if docker-compose exec -T flutter bash -c "pgrep -f 'python3 /tmp/http_server.py'" > /dev/null 2>&1; then
    log_success "Servidor iniciado com sucesso!"
  else
    log_error "Falha ao iniciar servidor"
    exit 1
  fi
  
  echo ""
  log_success "=========================================="
  log_success "✅ Servidor HTTP ativo!"
  log_success "=========================================="
  echo ""
  log_info "📡 Acesse de qualquer dispositivo na rede:"
  echo ""
  log_info "   🔗 Página de Download:"
  echo "      http://${SERVER_HOST}:${SERVER_PORT}/"
  echo ""
  log_info "   📱 Download Direto do APK:"
  echo "      http://${SERVER_HOST}:${SERVER_PORT}/apk/${APK_NAME}"
  echo ""
  log_success "=========================================="
  echo ""
  log_info "📋 Logs de Acesso (Ctrl+C para encerrar):"
  log_info "=========================================="
  echo ""
  
  # Exibir logs em tempo real
  docker-compose exec flutter tail -f /tmp/server.log
  
  # Cleanup será chamado automaticamente pelo trap
}

# ============================================
# Executar
# ============================================
main "$@"

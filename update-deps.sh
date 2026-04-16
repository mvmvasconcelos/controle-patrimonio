#!/bin/bash
set -euo pipefail

# ============================================
# Script de Atualização de Dependências - Controle Patrimônio
# ============================================
# Propósito: Atualizar dependências Flutter do projeto
# Uso: ./update-deps.sh [get|upgrade|outdated|clean]

# Cores para output
readonly COLOR_RESET='\033[0m'
readonly COLOR_INFO='\033[0;36m'
readonly COLOR_SUCCESS='\033[0;32m'
readonly COLOR_ERROR='\033[0;31m'
readonly COLOR_WARNING='\033[0;33m'
readonly COLOR_BOLD='\033[1m'

# Funções de logging
log_info() { echo -e "${COLOR_INFO}[INFO]${COLOR_RESET} $1"; }
log_success() { echo -e "${COLOR_SUCCESS}[✓]${COLOR_RESET} $1"; }
log_error() { echo -e "${COLOR_ERROR}[ERROR]${COLOR_RESET} $1" >&2; }
log_warning() { echo -e "${COLOR_WARNING}[WARNING]${COLOR_RESET} $1"; }

# ============================================
# Verificar contexto de execução
# ============================================
if [ ! -f "/.dockerenv" ]; then
  # Executando fora do container
  ACTION="${1:-get}"
  log_info "🐳 Executando dentro do container Docker..."
  docker-compose exec -T flutter bash -c "./update-deps.sh $ACTION"
  exit $?
fi

# ============================================
# Funções principais
# ============================================

# Configurar Git
setup_git() {
  log_info "Configurando Git como seguro..."
  git config --global --add safe.directory /opt/flutter 2>/dev/null || true
}

# Verificar pubspec.yaml
check_pubspec() {
  if [ ! -f "pubspec.yaml" ]; then
    log_error "Arquivo pubspec.yaml não encontrado!"
    exit 1
  fi
  log_success "Projeto Flutter encontrado"
}

# Mostrar dependências desatualizadas
show_outdated() {
  log_info "=========================================="
  log_info "📦 Verificando dependências desatualizadas..."
  log_info "=========================================="
  echo ""
  
  if flutter pub outdated; then
    echo ""
    log_info "ℹ️  Use './update-deps.sh upgrade' para atualizar"
  else
    log_warning "Não foi possível verificar dependências outdated"
  fi
}

# Baixar dependências (sem atualizar versões)
pub_get() {
  log_info "=========================================="
  log_info "📥 Baixando dependências..."
  log_info "=========================================="
  echo ""
  
  if flutter pub get; then
    echo ""
    log_success "Dependências sincronizadas com sucesso!"
  else
    echo ""
    log_error "Erro ao baixar dependências"
    return 1
  fi
}

# Atualizar dependências para versões mais recentes
pub_upgrade() {
  log_info "=========================================="
  log_info "⬆️  Atualizando dependências para versões mais recentes..."
  log_info "=========================================="
  echo ""
  
  if flutter pub upgrade; then
    echo ""
    log_success "Dependências atualizadas com sucesso!"
    log_info "Verifique pubspec.lock para ver as mudanças"
  else
    echo ""
    log_error "Erro ao atualizar dependências"
    return 1
  fi
}

# Limpar cache e rebuild
clean_build() {
  log_info "=========================================="
  log_info "🧹 Limpando cache e arquivos de build..."
  log_info "=========================================="
  echo ""
  
  if flutter clean; then
    echo ""
    log_success "Cache limpo com sucesso!"
    log_info "Executando flutter pub get..."
    echo ""
    pub_get
  else
    echo ""
    log_error "Erro ao limpar cache"
    return 1
  fi
}

# Mostrar ajuda
show_usage() {
  echo ""
  echo -e "${COLOR_BOLD}Uso:${COLOR_RESET} ./update-deps.sh [comando]"
  echo ""
  echo -e "${COLOR_BOLD}Comandos disponíveis:${COLOR_RESET}"
  echo "  get       - Baixar dependências do pubspec.yaml (padrão)"
  echo "  upgrade   - Atualizar dependências para versões mais recentes"
  echo "  outdated  - Mostrar dependências desatualizadas"
  echo "  clean     - Limpar cache e fazer pub get"
  echo "  help      - Mostrar esta ajuda"
  echo ""
  echo -e "${COLOR_BOLD}Exemplos:${COLOR_RESET}"
  echo "  ./update-deps.sh          # Executa pub get"
  echo "  ./update-deps.sh upgrade  # Atualiza todas as dependências"
  echo "  ./update-deps.sh outdated # Verifica atualizações disponíveis"
  echo "  ./update-deps.sh clean    # Limpa cache e baixa dependências"
  echo ""
}

# Mostrar próximos passos
show_next_steps() {
  echo ""
  log_success "=========================================="
  log_success "✅ Operação concluída!"
  log_success "=========================================="
  echo ""
  log_info "📋 Próximos passos disponíveis:"
  echo "   ./start.sh               - Gerenciar container Docker"
  echo "   ./compila.sh             - Compilar APK (incrementa versionCode)"
  echo "   ./compila.sh patch       - Compilar com versao patch"
  echo "   ./compila.sh minor       - Compilar com versao minor"
  echo "   ./compila.sh major       - Compilar com versao major"
  echo "   ./share.sh               - Compartilhar APK via servidor HTTP"
  echo ""
}

# ============================================
# Main
# ============================================
main() {
  local action="${1:-get}"
  
  # Setup inicial
  setup_git
  check_pubspec
  
  echo ""
  log_info "=========================================="
  log_info "📦 Gerenciador de Dependências Flutter"
  log_info "=========================================="
  echo ""
  
  # Executar ação
  case "$action" in
    get)
      pub_get && show_next_steps
      ;;
    upgrade)
      pub_upgrade && show_next_steps
      ;;
    outdated)
      show_outdated
      ;;
    clean)
      clean_build && show_next_steps
      ;;
    help|--help|-h)
      show_usage
      ;;
    *)
      log_error "Comando desconhecido: $action"
      show_usage
      exit 1
      ;;
  esac
}

# ============================================
# Executar
# ============================================
main "$@"

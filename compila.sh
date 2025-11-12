#!/bin/bash
set -euo pipefail

# ============================================
# Script de Compilação APK - Controle Patrimônio
# ============================================
# Propósito: Compilar APK e preparar arquivos para distribuição
# Uso: ./compilaApk.sh [major|minor|patch]

# Configurações
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
# Verificar se está fora do container
# ============================================
if [ ! -f "/.dockerenv" ]; then
  log_info "🐳 Executando compilação dentro do container Docker..."
  docker-compose exec -T flutter bash -c "./compilaApk.sh $*"
  exit $?
fi

# ============================================
# DAQUI PRA BAIXO: Código executado DENTRO do container
# ============================================
# ============================================

# ============================================
# DAQUI PRA BAIXO: Código executado DENTRO do container
# ============================================

log_info "Iniciando compilação do APK..."

# Configurar Git como seguro
git config --global --add safe.directory /opt/flutter 2>/dev/null || true

# Verificar estrutura do projeto
if [ ! -d "lib" ]; then
  log_error "Diretório 'lib' não encontrado"
  exit 1
fi

if [ ! -f "lib/main.dart" ]; then
  log_error "Arquivo main.dart não encontrado"
  exit 1
fi

# ============================================
# Gerenciamento de Versão
# ============================================
# A versão fica salva no arquivo pubspec.yaml
# Formato: X.Y.Z+N
log_info "Atualizando versão do aplicativo..."

PUBSPEC_FILE="pubspec.yaml"
LOCAL_PROPERTIES_FILE="android/local.properties"
README_FILE="README.md"

# Extrair versão atual
CURRENT_VERSION=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //')
VERSION_NAME=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
VERSION_CODE=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)

# Extrair componentes semânticos
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION_NAME"

# Incrementar versionCode
NEW_VERSION_CODE=$((VERSION_CODE + 1))

# Determinar tipo de incremento
case "${1:-build}" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    log_info "Incrementando versão major para $MAJOR.0.0"
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    log_info "Incrementando versão minor para $MAJOR.$MINOR.0"
    ;;
  patch)
    PATCH=$((PATCH + 1))
    log_info "Incrementando versão patch para $MAJOR.$MINOR.$PATCH"
    ;;
  build|*)
    log_info "Incrementando apenas build number para +$NEW_VERSION_CODE"
    ;;
esac

# Nova versão completa
NEW_VERSION_NAME="$MAJOR.$MINOR.$PATCH"
NEW_VERSION="${NEW_VERSION_NAME}+${NEW_VERSION_CODE}"

log_info "🔄 Versão: $CURRENT_VERSION → $NEW_VERSION"

# Atualizar pubspec.yaml
sed -i "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC_FILE"

# Verificar atualização
UPDATED_VERSION=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //')
if [ "$UPDATED_VERSION" != "$NEW_VERSION" ]; then
  log_error "Falha ao atualizar pubspec.yaml"
  exit 1
fi
log_success "pubspec.yaml atualizado"

# Atualizar local.properties
if [ -f "$LOCAL_PROPERTIES_FILE" ]; then
  sed -i '/flutter.versionName=/d' "$LOCAL_PROPERTIES_FILE"
  sed -i '/flutter.versionCode=/d' "$LOCAL_PROPERTIES_FILE"
fi
mkdir -p "$(dirname "$LOCAL_PROPERTIES_FILE")"
echo "flutter.versionName=$NEW_VERSION_NAME" >> "$LOCAL_PROPERTIES_FILE"
echo "flutter.versionCode=$NEW_VERSION_CODE" >> "$LOCAL_PROPERTIES_FILE"
log_success "local.properties atualizado"

# Atualizar README.md badge
if [ -f "$README_FILE" ]; then
  sed -i "s/version-[0-9]*\.[0-9]*\.[0-9]*-blue/version-$NEW_VERSION_NAME-blue/" "$README_FILE" 2>/dev/null || true
fi

# ============================================
# Compilação
# ============================================
log_info "Instalando dependências..."
flutter pub get --offline 2>/dev/null || flutter pub get

log_info "Compilando APK (isso pode demorar alguns minutos)..."

cd android
if ./gradlew assembleRelease --offline 2>/dev/null; then
  log_success "APK compilado (modo offline)"
elif ./gradlew assembleRelease; then
  log_success "APK compilado (modo online)"
else
  log_error "Falha na compilação com Gradle"
  cd ..
  exit 1
fi
cd ..

# ============================================
# Verificar APK gerado
# ============================================
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_PATH" ]; then
  log_error "APK não foi gerado em $APK_PATH"
  exit 1
fi

APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
log_success "APK gerado com sucesso! ($APK_SIZE)"

# ============================================
# Preparar diretório web para distribuição
# ============================================
log_info "Preparando arquivos para distribuição..."

mkdir -p web/apk
cp "$APK_PATH" "web/apk/${APK_NAME}"
log_success "APK copiado para web/apk/${APK_NAME}"

# Criar version.json
CURRENT_DATE=$(date +"%Y-%m-%d")
cat > web/version.json <<EOF
{
    "version": "$NEW_VERSION_NAME",
    "buildNumber": "$NEW_VERSION_CODE",
    "releaseDate": "$CURRENT_DATE",
    "size": "$APK_SIZE"
}
EOF
log_success "version.json criado"

# Criar página HTML de download
cat > web/index.html <<'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Download APK - Controle Patrimônio</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 500px;
            width: 100%;
            padding: 40px;
            text-align: center;
        }
        
        .icon {
            width: 80px;
            height: 80px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 20px;
            font-size: 40px;
        }
        
        h1 {
            color: #2d3748;
            font-size: 28px;
            margin-bottom: 10px;
        }
        
        .subtitle {
            color: #718096;
            font-size: 16px;
            margin-bottom: 30px;
        }
        
        .version-info {
            background: #f7fafc;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 30px;
        }
        
        .version-item {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #e2e8f0;
        }
        
        .version-item:last-child {
            border-bottom: none;
        }
        
        .version-label {
            color: #718096;
            font-weight: 500;
        }
        
        .version-value {
            color: #2d3748;
            font-weight: 600;
        }
        
        .download-btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 16px 32px;
            text-decoration: none;
            font-size: 18px;
            font-weight: 600;
            border-radius: 12px;
            display: inline-block;
            transition: transform 0.2s, box-shadow 0.2s;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
        }
        
        .download-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(102, 126, 234, 0.6);
        }
        
        .download-btn:active {
            transform: translateY(0);
        }
        
        .instructions {
            margin-top: 30px;
            text-align: left;
            background: #fffbeb;
            border-left: 4px solid #f59e0b;
            border-radius: 8px;
            padding: 20px;
        }
        
        .instructions h3 {
            color: #92400e;
            font-size: 16px;
            margin-bottom: 15px;
        }
        
        .instructions ol {
            color: #78350f;
            padding-left: 20px;
        }
        
        .instructions li {
            margin-bottom: 8px;
            line-height: 1.5;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">📱</div>
        <h1>Controle Patrimônio</h1>
        <p class="subtitle">Download do Aplicativo Android</p>
        
        <div class="version-info" id="versionInfo">
            <div class="version-item">
                <span class="version-label">Versão:</span>
                <span class="version-value" id="version">Carregando...</span>
            </div>
            <div class="version-item">
                <span class="version-label">Build:</span>
                <span class="version-value" id="build">-</span>
            </div>
            <div class="version-item">
                <span class="version-label">Data:</span>
                <span class="version-value" id="date">-</span>
            </div>
            <div class="version-item">
                <span class="version-label">Tamanho:</span>
                <span class="version-value" id="size">-</span>
            </div>
        </div>
        
        <a href="apk/controle-patrimonio.apk" class="download-btn" id="downloadBtn">
            📥 Baixar APK
        </a>
        
        <div class="instructions">
            <h3>⚠️ Instruções de Instalação</h3>
            <ol>
                <li>Clique no botão acima para baixar o APK</li>
                <li>Nas configurações do Android, habilite "Fontes desconhecidas"</li>
                <li>Abra o arquivo APK baixado</li>
                <li>Toque em "Instalar" e aguarde</li>
                <li>Conceda as permissões necessárias quando solicitado</li>
            </ol>
        </div>
    </div>
    
    <script>
        // Carregar informações da versão
        fetch('version.json')
            .then(response => response.json())
            .then(data => {
                document.getElementById('version').textContent = data.version;
                document.getElementById('build').textContent = data.buildNumber;
                document.getElementById('date').textContent = data.releaseDate;
                document.getElementById('size').textContent = data.size;
            })
            .catch(err => {
                console.error('Erro ao carregar version.json:', err);
            });
    </script>
</body>
</html>
EOF
log_success "Página HTML criada"

echo ""
log_success "=========================================="
log_success "✅ Compilação concluída com sucesso!"
log_success "=========================================="
log_info "📦 APK: web/apk/${APK_NAME} ($APK_SIZE)"
log_info "📄 Versão: $NEW_VERSION_NAME (build $NEW_VERSION_CODE)"
log_info ""
log_info "Para compartilhar o APK execute:"
log_info "   ./compartilha.sh"
log_success "=========================================="

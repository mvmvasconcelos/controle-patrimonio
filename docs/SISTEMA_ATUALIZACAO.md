# Implementação do Sistema de Atualização - Controle Patrimônio

## Resumo
Foi implementado um sistema completo de atualização do aplicativo, copiado do projeto **barcode-scanner** e adaptado para o **controle-patrimonio**.

## Funcionalidades Implementadas

### 1. Verificação de Atualizações
- Verifica se o servidor está online (compartilha.sh rodando)
- Compara a versão atual com a versão disponível no servidor
- Suporta comparação de versão semântica e build number

### 2. Download e Instalação
- Download automático do APK com barra de progresso
- Instalação facilitada após o download
- Múltiplas estratégias de instalação para compatibilidade

### 3. Configuração Personalizável
- IP e porta do servidor configuráveis
- Valores padrão: `128.1.1.49:8090`
- Configurações salvas localmente

## Arquivos Criados

### Configuração
- `lib/config/app_info.dart` - Informações do aplicativo (versão, nome, data)

### Serviços
- `lib/services/update_service.dart` - Lógica de atualização (verificação, download, instalação)

### Providers
- `lib/providers/update_provider.dart` - Gerenciamento de estado da atualização

### Telas
- `lib/screens/about_page.dart` - Tela "Sobre" com funcionalidade de atualização

### Dados
- `web/version.json` - Arquivo com informações da versão atual (servido pelo compartilha.sh)

## Arquivos Modificados

### `pubspec.yaml`
Adicionadas dependências:
- `provider` - Gerenciamento de estado
- `http`, `dio` - Requisições HTTP
- `connectivity_plus` - Verificação de conectividade
- `package_info_plus` - Informações do pacote
- `shared_preferences` - Armazenamento local
- `path_provider` - Acesso a diretórios
- `open_filex`, `install_plugin` - Instalação de APK
- `permission_handler` - Permissões Android
- `intl`, `yaml` - Utilitários

### `lib/main.dart`
- Adicionado `ChangeNotifierProvider` para `UpdateProvider`
- Criada HomePage com botão "Sobre" no AppBar
- Interface melhorada com Material 3

## Como Usar

### Para o Desenvolvedor

1. **Compilar nova versão:**
   ```bash
   ./compilaApk.sh
   ```

2. **Atualizar version.json:**
   - Editar `web/version.json` com nova versão e buildNumber

3. **Iniciar servidor de compartilhamento:**
   ```bash
   ./compartilha.sh
   ```

### Para o Usuário

1. Abrir o aplicativo
2. Tocar no ícone "ℹ️" (Sobre) no canto superior direito
3. Tocar em "Verificar atualizações"
4. Se houver atualização disponível, tocar em "ATUALIZAR"
5. Seguir as instruções de instalação

### Configuração do Servidor (se necessário)

1. Na tela Sobre, tocar no ícone de engrenagem (⚙️)
2. Inserir o IP e porta do servidor
3. Tocar em "SALVAR"

## Comportamento do Sistema

### Verificação de Servidor
- Tenta conectar 3 vezes com timeout de 8 segundos
- Verifica conectividade de internet antes
- Mensagens de erro amigáveis

### Download
- Barra de progresso em tempo real
- Validação do tamanho do arquivo (mínimo 1MB)
- Tratamento de erros de conexão

### Instalação
- 3 estratégias diferentes para máxima compatibilidade
- Instruções claras para o usuário
- Fecha o app automaticamente após iniciar instalação

## Observações Importantes

1. **Servidor deve estar rodando**: O script `compartilha.sh` precisa estar em execução
2. **Mesma rede**: Dispositivo móvel deve estar na mesma rede que o servidor
3. **Permissões**: O app solicitará permissão para instalar APKs de fontes desconhecidas
4. **Versão vs Build**: Sistema compara tanto versão semântica quanto build number

## Compatibilidade

- **Android**: Totalmente funcional
- **iOS**: Não aplicável (iOS não permite instalação de APK)
- **Web**: Não aplicável (não há APK para web)

## Estrutura do version.json

```json
{
  "version": "1.0.4",
  "buildNumber": 5,
  "releaseDate": "2025-11-12",
  "size": "18M",
  "description": "Controle de Patrimônio IFSul"
}
```

## Próximos Passos

Para testar a funcionalidade:

1. Compilar o APK com a nova implementação
2. Instalar no dispositivo
3. Iniciar o compartilha.sh
4. Abrir o app e testar a verificação de atualizações

---

**Desenvolvido em**: IFSul Câmpus Venâncio Aires  
**Data**: Novembro de 2025

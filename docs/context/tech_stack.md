# Contexto Tecnico

## Visao de Arquitetura

O produto e um webapp Flutter offline-first. O navegador usa a API como fonte
de verdade quando ha conexao e mantem uma copia local para continuar a
Conferencia em areas sem rede.

### Frontend Web

- **Framework:** Flutter Web (Dart).
- **Estado e regras de negocio:** telas e repositorios; o
  `OfflineInventoryRepository` implementa a interface do repositório remoto.
- **Cache offline:** Hive sobre IndexedDB, incluindo inventário, fotos, metadados
  e fila de operações pendentes.
- **Câmera e arquivos:** captura pelo navegador, seleção de arquivos e downloads
  são feitos pelos adaptadores web.
- **Sincronização:** automática ao recuperar conectividade e disponível pela
  interface; conflitos de edição seguem last-write-wins por patrimônio.

### Backend (API)

- **Framework:** FastAPI (Python).
- **Banco:** SQLite no servidor.
- **Responsabilidades:** autenticação, inventário, conferências, relatórios,
  sincronização e endpoints de upload/listagem/download/remoção de fotos.

### Infraestrutura

- **Containerização:** Docker Compose.
- **Serviços:** `flutter` para análise/testes/build web; `backend` para a API;
  `web` para servir o build e encaminhar requisições à API.
- **Host:** servidor Linux remoto (IFVA).

## Padrões de Qualidade

- **Lint:** `flutter_lints`.
- **Testes:** `flutter test`, incluindo testes de repositório web, cache offline,
  fotos e widgets.
- **Formatação:** padrão Dart.

## Restrições-Chave

1. Comandos Flutter e Python são executados nos serviços Docker do projeto.
2. Importação/exportação pelo navegador e operação offline devem continuar
   disponíveis sem depender do backend durante uma interrupção de rede.
3. Mudanças na API devem preservar contratos e a fila local de operações.

# Contexto Tecnico

## Visao de Arquitetura
O sistema esta em **transicao para arquitetura hibrida**:
1. **Prioridade atual**: fluxo offline no app (importar planilha, editar, exportar alteracoes).
2. **Ja implementado no ciclo atual**: sincronizacao assistida por backend e suporte a fotos por item.

Na pratica, o app precisa continuar funcional offline enquanto as capacidades de sincronizacao sao introduzidas gradualmente.

### Frontend (App Mobile)
- **Framework**: Flutter (Dart).
- **Gerenciamento de estado**: `Provider`.
- **Base local**: `Hive` (NoSQL chave-valor, rapido para leitura).
- **Base local de fotos**: `sqflite` (SQLite) com BLOB e fila de pendencias de sincronizacao.
- **Padrao de camadas**:
    - **Screens**: componentes de interface.
    - **Providers**: estado e regras de negocio.
    - **Services/Repositories**: acesso a dados (API/Hive/arquivos).
    - **Models**: objetos de transferencia de dados (`fromJson`, etc.).

### Backend (API)
- **Framework**: FastAPI (Python).
- **Banco**: SQLite no servidor.
- **Papel no projeto**:
    - oferecer endpoints de suporte para sincronizacao
    - receber e persistir alteracoes quando o fluxo de sync estiver habilitado
    - manter endpoints de fotos por item (upload/listagem/download/remocao)
    - apoiar distribuicao de artefatos quando aplicavel

### Infraestrutura
- **Containerizacao**: Docker Compose.
- **Servicos principais**:
    - `flutter`: ambiente para comandos Flutter.
    - `backend`: ambiente Python/FastAPI.
- **Host**: servidor Linux remoto (IFVA).

## Padroes de Qualidade
- **Lint**: `flutter_lints`.
- **Testes**: `flutter test` e testes de integracao/logica quando aplicavel.
- **Formatacao**: padrao Dart.

## Restricoes-Chave
1. **Sem execucao direta no host**: comandos tecnicos devem rodar via `docker-compose`.
2. **Compatibilidade retroativa**: fluxo por planilha offline deve continuar funcionando durante a transicao.
3. **Controle de versao e contratos**: mudancas de app/API devem evitar incompatibilidades disruptivas.

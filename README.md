# Controle de Patrimônio IFSul Câmpus Venâncio Aires

[![Status](https://img.shields.io/badge/Status-em%20Desenvolvimento-purple)](https://github.com/mvmvasconcelos/) [![Versão](https://img.shields.io/badge/version-1.0.3-blue.svg)](https://github.com/ifsul/leitor-etiquetas-patrimonio) [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev/) [![Licença](https://img.shields.io/badge/licen%C3%A7a-MIT-green.svg)](https://opensource.org/licenses/MIT) [![Platform](https://img.shields.io/badge/platform-Android-brightgreen.svg)](https://www.android.com/) [![Docker](https://img.shields.io/badge/Docker-Suportado-2496ED?logo=docker)](https://www.docker.com/) [![IFSul](https://img.shields.io/badge/IFSul-Ven%C3%A2ncio%20Aires-195128)](https://www.venancio.ifsul.edu.br)

Aplicativo Android desenvolvido em Flutter para apoio às conferências de inventário patrimonial. Funciona como uma **"planilha de apoio" automatizada**: o usuário importa a planilha exportada do SUAP, realiza o trabalho de campo escaneando os itens, e exporta de volta apenas o que foi alterado — pronto para atualização no SUAP.

---

## Fluxo de uso

1. **Importar** — No SUAP, exporte o inventário em `.xls`, `.xlsx` ou `.csv`. No app, use a tela de **Gerenciamento de Dados** para importar o arquivo. Ele passa a ser o banco de dados local do app.
2. **Conferir** — Use o scanner (individual ou em lotes) para localizar os itens. Ao escanear um patrimônio, o app exibe os dados e permite editar sala, responsável, situação, etc.
3. **Exportar** — Após as conferências, exporte de duas formas:
   - **Somente modificados** — planilha com as mesmas colunas do SUAP, apenas os itens alterados, células modificadas destacadas em amarelo.
   - **Planilha completa** — todos os itens com coluna adicional `ATUALIZADO_EM` (preenchida só nos alterados).
   - Formatos disponíveis: `.xlsx` ou `.csv`.

---

## Funcionalidades implementadas

| Recurso | Detalhe |
|---|---|
| Scanner de código de barras | Individual e em lotes, com feedback sonoro |
| Busca manual | Pesquisa por número de patrimônio |
| Importação de planilha SUAP | `.xls`, `.xlsx` e `.csv`; mapeamento automático de colunas |
| Listagem do inventário | Busca e filtros por sala / somente modificados |
| Rastreamento de alterações | Registra campo por campo o que foi modificado |
| Exportação modificados | Mesmo formato SUAP, células alteradas em amarelo |
| Exportação completa | Planilha completa + coluna `ATUALIZADO_EM` |
| Relatório de modificações | Tela dedicada, geração de `.xlsx` com destaque |
| Funcionamento offline | Banco de dados local via Hive |
| Fotos por item | Até 3 fotos por patrimônio, com câmera/galeria e visualização em grade |
| Sync de fotos (assistido) | Upload/download/delete com fila de pendências offline |
| Auto-atualização | Verifica e baixa nova versão do APK |

---

## Infraestrutura

- **App**: Flutter 3.x (Android), Hive + SQLite local (`sqflite`), `mobile_scanner`, `excel`, `spreadsheet_decoder`, `csv`, `file_picker`, `image_picker`, `flutter_image_compress`, `photo_view`
- **Backend web**: FastAPI + SQLite como fonte de verdade do webapp; o fluxo do APK existente continua preservado durante a transição
- **Build**: Docker (`controle-patrimonio-flutter`)

## Webapp

O webapp Flutter usa o backend como fonte de verdade e está publicado sob `/controle-patrimonio/`. Consulte [docs/deploy-web.md](docs/deploy-web.md) para configurar o administrador por ambiente e iniciar o deploy com Docker Compose.

---

## Scripts

| Script | Descrição |
|---|---|
| `./start.sh` | Inicializa os containers Docker |
| `./compila.sh [patch\|minor\|major]` | Compila o APK com versionamento automático |
| `./update-deps.sh` | Atualiza as dependências Flutter dentro do container |
| `./share.sh` | Sobe um servidor HTTP temporário para distribuir o APK |
| `./emulador.sh` | Inicia o emulador Android para testes |

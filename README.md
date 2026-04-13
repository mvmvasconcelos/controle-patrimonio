# Controle de Patrimônio IFSul Câmpus Venâncio Aires

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
| Auto-atualização | Verifica e baixa nova versão do APK |

---

## Infraestrutura

- **App**: Flutter 3.x (Android), Hive (DB local), `mobile_scanner`, `excel`, `spreadsheet_decoder`, `csv`, `file_picker`
- **Backend** (suporte): FastAPI + SQLite em `128.1.1.49:6090` — usado para sincronização opcional, não é requisito para o funcionamento principal
- **Build**: Docker (`controle-patrimonio-flutter`)

---

## Scripts

| Script | Descrição |
|---|---|
| `./start.sh` | Inicializa os containers Docker |
| `./compila.sh [patch\|minor\|major]` | Compila o APK com versionamento automático |
| `./update-deps.sh` | Atualiza as dependências Flutter dentro do container |
| `./share.sh` | Sobe um servidor HTTP temporário para distribuir o APK |
| `./emulador.sh` | Inicia o emulador Android para testes |

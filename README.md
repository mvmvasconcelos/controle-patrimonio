# Controle de Patrimônio IFSul Câmpus Venâncio Aires

Aplicação Flutter Web para importar o inventário do SUAP, realizar conferências
de patrimônio e sincronizar alterações com a API. O acesso é feito pelo
navegador em `/controle-patrimonio/`, sem instalação de aplicativo.

## Funcionalidades

- Login de Administrador e sessão autenticada.
- Busca, filtros, listagem e edição de patrimônios.
- Conferência individual ou em lote, com leitura pela câmera do navegador e
  alternativa de digitação manual.
- Importação do inventário e download de exportações e relatórios.
- Captura ou seleção de fotos, com redimensionamento, visualização e remoção.
- Operação offline: Hive usa IndexedDB para manter o inventário, as fotos e a
  fila de alterações no navegador; a Sincronização é retomada quando a rede
  volta.

## Arquitetura

- **Interface:** Flutter Web.
- **Cache offline:** Hive em IndexedDB, com operações pendentes e Sincronização
  last-write-wins por patrimônio.
- **API:** FastAPI e SQLite no servidor.
- **Execução local:** Docker Compose (`flutter`, `backend` e `web`).

Consulte [docs/deploy-web.md](docs/deploy-web.md) para a configuração do
ambiente e [docs/context/tech_stack.md](docs/context/tech_stack.md) para os
detalhes técnicos.

## Desenvolvimento

Execute os comandos Flutter no serviço Docker `flutter`:

```sh
docker-compose run --rm -w /app flutter sh -lc "flutter analyze"
docker-compose run --rm -w /app flutter sh -lc "flutter test"
docker-compose run --rm -w /app flutter sh -lc "flutter build web --release --no-web-resources-cdn --base-href /controle-patrimonio/"
```

Para executar a API e o webapp localmente, consulte
[docs/deploy-web.md](docs/deploy-web.md).

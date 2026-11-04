# Fotos de Patrimônio no Webapp

Este documento descreve a implementação atual de fotos na aplicação Flutter
Web. O backend é a fonte de verdade; o navegador mantém um cache local para
visualização offline e uma fila para uploads e remoções pendentes.

## Fluxo e limites

- O Administrador pode capturar uma foto pela câmera do navegador ou selecionar
  um arquivo.
- `BrowserPhotoPicker` redimensiona a imagem para no máximo 1280 px no maior
  lado e a converte para JPEG.
- São aceitas até três fotos por Patrimônio; o upload tem limite de 5 MB.
- A API lista, recebe, entrega e remove fotos associadas ao Patrimônio.
- Ao visualizar uma foto, seus bytes podem ser guardados em Hive sobre
  IndexedDB. A cópia em cache pode ser descartada quando faltar espaço; uploads
  pendentes não são descartados.
- Se não houver conexão, novos uploads e remoções entram na fila local e são
  enviados na Sincronização seguinte.

## Componentes

| Componente | Responsabilidade |
|---|---|
| `lib/services/web_photo_picker.dart` | Seleção pela câmera ou arquivo e redimensionamento |
| `lib/services/web_photo_resizer.dart` | Adaptador de redimensionamento específico para Web |
| `lib/services/web_inventory_repository.dart` | Contratos HTTP para fotos e validação de tamanho |
| `lib/services/offline/offline_inventory_repository.dart` | Cache, operações pendentes e Sincronização |
| `lib/services/offline/offline_store.dart` | Armazenamento Hive de bytes e fila local |
| `lib/screens/web_patrimony_pages.dart` | Fluxos de exibição e edição de fotos |

O cache offline tem um orçamento conservador padrão de 100 MB. Fotos em cache
podem ser removidas por LRU para liberar espaço. Fotos criadas offline ficam
marcadas como pendentes e não são removidas para abrir espaço; se o navegador
não tiver quota suficiente, a operação informa erro ao Administrador.

## Sincronização

1. Com rede, o app consulta a lista da API e baixa sob demanda os bytes ausentes
   no cache local.
2. Sem rede, uma nova foto é armazenada localmente com identificador temporário
   e uma operação `upload_photo`; uma remoção de foto já enviada cria uma
   operação `delete_photo`.
3. Ao voltar a conexão, a fila é processada. Um upload bem-sucedido troca o
   identificador temporário pelo identificador do servidor.
4. Falhas de rede ou do servidor mantêm a operação pendente para nova tentativa.
   O limite de fotos e o tamanho são validados antes do envio.

## Verificação

Os testes que cobrem este fluxo incluem:

- `test/web_inventory_repository_photos_test.dart` — contratos HTTP, limite de
  tamanho, CSRF, erros e remoções;
- `test/offline_inventory_repository_test.dart` — cache, fotos e fila offline;
- `test/offline_store_test.dart` — persistência Hive, quota, orçamento e
  retenção de uploads pendentes.

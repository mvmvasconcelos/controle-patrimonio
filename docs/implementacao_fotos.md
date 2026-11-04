# Plano de Implementação: Fotos por Item Patrimonial

**Versão do plano:** 1.2 — Abril 2026  
**Status:** Implementado (MVP funcional em campo)

---

## Status de Implementação (Abril/2026)

- [x] Captura por câmera e seleção de galeria com compressão.
- [x] Armazenamento local em SQLite (`fotos.db`) com limite de 3 fotos por item.
- [x] Viewer full-screen com zoom e deleção.
- [x] Exibição de fotos no fluxo individual e na visualização de item do inventário.
- [x] Indicador visual de item com fotos na listagem do inventário.
- [x] Sincronização com backend (upload, download sob demanda e deleção remota idempotente).
- [x] Fila local de deleção pendente (tombstones) para uso offline.
- [x] Contadores de pendência e feedback de erro/sincronização na UI.
- [x] Fluxo de restauração e limpeza manual de fotos órfãs na gestão de dados.

---

## Visão Geral da Entrega

O app permite capturar e gerenciar até **3 fotos por item patrimonial**, armazenadas localmente no dispositivo como BLOBs em um banco SQLite independente do Hive. As fotos persistem entre importações de planilha (a chave é sempre o `numeroPatrimonio`). Quando o servidor está disponível, as fotos são sincronizadas automaticamente.

---

## Decisões de Design

| Aspecto | Decisão | Justificativa |
|---|---|---|
| Armazenamento | BLOB em SQLite (`sqflite`) | Banco leve, autocontido, sem risco de arquivos órfãos |
| Schema | `id`, `numero_patrimonio`, `imagem_blob`, `data_modificacao` | Mínimo — demais campos vêm da planilha |
| Resolução | Máx. 1280×720 (HD landscape) ou equivalente portrait, mantendo aspect ratio | Leveza + qualidade aceitável |
| Formato | JPEG 85% | Melhor custo/benefício de compressão |
| Limite | 3 fotos por item | Suficiente para documentação, evita banco inflado |
| Exportação | Não incluída nesta etapa | TODO futuro: exportar como .zip (planilha + pasta de fotos) |
| Sincronização | Sim, quando servidor disponível; aviso discreto se offline | |
| Deleção offline | Usar tombstones locais para remoção pendente | Evita foto zumbi no servidor |
| Conflito de sincronização | Fase 1: servidor rejeita excesso acima de 3 com `409`; app avisa conflito | Evita merge silencioso e perda de previsibilidade |
| Fotos órfãs | Não apagar automaticamente; detectar e oferecer limpeza manual | Evita perda de dados após importações incompletas |
| Limpar dados do app | Hive + SQLite local são perdidos; recuperação depende do servidor | Comportamento explícito para suporte e UX |
| Indicador de foto na lista | Carregar um `Set<String>` único por página, sem `FutureBuilder` por tile | Evita N consultas SQLite por frame |

---

## Pacotes Utilizados

```yaml
# pubspec.yaml — dependencies utilizadas:
sqflite: ^2.3.0           # SQLite local para fotos
image_picker: ^1.1.0      # Câmera + galeria
flutter_image_compress: ^2.2.0  # Resize + compressão JPEG
photo_view: ^0.15.0       # Viewer com pinch-to-zoom
path: ^1.9.0              # Utilitários de caminhos
```

---

## Schema do Banco de Dados de Fotos

```sql
-- Arquivo: fotos.db (em getApplicationDocumentsDirectory())

CREATE TABLE fotos_patrimonio (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  numero_patrimonio TEXT NOT NULL,
  imagem_blob      BLOB NOT NULL,
  data_modificacao TEXT NOT NULL,  -- ISO 8601: 2026-04-13T14:30:00
  server_photo_id  INTEGER,
  sync_status      TEXT NOT NULL DEFAULT 'pending_upload',
  sync_origin      TEXT NOT NULL DEFAULT 'app'
);

CREATE TABLE fotos_patrimonio_delete_queue (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  numero_patrimonio TEXT NOT NULL,
  server_photo_id  INTEGER NOT NULL,
  data_modificacao TEXT NOT NULL
);

CREATE INDEX idx_fotos_numero ON fotos_patrimonio(numero_patrimonio);
CREATE INDEX idx_fotos_sync_status ON fotos_patrimonio(sync_status);
CREATE INDEX idx_delete_queue_numero ON fotos_patrimonio_delete_queue(numero_patrimonio);
```

**Observações:**
- Um item pode ter de 0 a 3 registros nessa tabela.
- A tabela nunca é limpa em importações de planilha — apenas o Hive é limpo.
- Fotos locais novas nascem com `sync_status='pending_upload'`.
- Fotos baixadas do servidor usam `sync_status='synced'` e `sync_origin='server'`.
- Ao deletar uma foto já sincronizada enquanto offline, ela sai da UI local e entra na tabela `fotos_patrimonio_delete_queue`.
- Se a foto ainda não foi sincronizada e for deletada localmente, basta remover o registro sem criar tombstone.

---

## Arquitetura de Código

### Novos arquivos

```
lib/
  database/
    photo_database.dart        ← NOVO: wrapper SQLite para fotos
  services/
    photo_service.dart         ← NOVO: captura + compressão de imagens
    photo_sync_service.dart    ← NOVO: sincronização com backend
  screens/
    photo_viewer_page.dart     ← NOVO: tela full-screen com pinch-zoom
  widgets/
    photo_grid_widget.dart     ← NOVO: grid de thumbs + botões add/remove
```

### Arquivos modificados

```
lib/
  main.dart                  ← inicialização do banco de fotos e sync no bootstrap
  widgets/
    scanned_item_modal.dart  ← integração do grid no modal de edição
  database/
    hive_database.dart       ← limpeza conjunta (Hive + fotos) em ações de apagar dados
  screens/
    individual_scan_page.dart  ← adicionar seção de fotos no formulário de edição
    inventory_list_page.dart   ← tap no item abre detalhe com fotos
    item_detail_page.dart      ← visualização detalhada read-only com fotos
    data_management_page.dart  ← restauração em lote e limpeza de órfãs
    cache_management_page.dart ← aviso explícito sobre perda de fotos não sincronizadas
    home_page.dart             ← sincronização manual e indicadores de pendência
backend/
  app/api/endpoints.py       ← endpoints de upload/listagem/download/delete de fotos
  app/models.py              ← modelo FotoPatrimonio
  app/crud.py                ← operações CRUD para fotos
  app/schemas.py             ← schema Pydantic para fotos
```

---

## Detalhamento por Arquivo

### `lib/database/photo_database.dart`

```dart
class PhotoDatabase {
  static const _dbName = 'fotos.db';
  static const _tableName = 'fotos_patrimonio';
  static const _maxPhotos = 3;
  static Database? _db;

  static Future<void> init() async { ... }

  // Retorna lista de PhotoRecord para um item
  static Future<List<PhotoRecord>> getPhotos(String numeroPatrimonio) async { ... }

  // Retorna true se o item tem fotos
  static Future<bool> hasPhotos(String numeroPatrimonio) async { ... }

  // Retorna Set de numeroPatrimonio que possuem pelo menos 1 foto
  static Future<Set<String>> getAllNumbersWithPhotos() async { ... }

  // Retorna fotos órfãs (numero_patrimonio não presente na carga atual)
  static Future<Set<String>> getOrphanNumbers(Set<String> numerosAtuais) async { ... }

  // Adiciona foto (valida limite de 3). Lança Exception se já tiver 3.
  static Future<void> addPhoto(String numeroPatrimonio, Uint8List imageBytes) async { ... }

  // Remove foto pelo id
  static Future<void> deletePhoto(int id) async { ... }

  // Enfileira remoção remota para foto já sincronizada
  static Future<void> enqueueRemoteDelete(PhotoRecord photo) async { ... }

  // Retorna remoções pendentes para sincronização com o servidor
  static Future<List<PhotoDeleteRecord>> getPendingDeletes() async { ... }

  // Limpa todas as fotos de um item (ex.: item deletado)
  static Future<void> deleteAllPhotos(String numeroPatrimonio) async { ... }
}

class PhotoRecord {
  final int id;
  final String numeroPatrimonio;
  final Uint8List imageBytes;
  final DateTime dataModificacao;
  final int? serverPhotoId;
  final String syncStatus;
  final String syncOrigin;
}

class PhotoDeleteRecord {
  final int id;
  final String numeroPatrimonio;
  final int serverPhotoId;
  final DateTime dataModificacao;
}
```

---

### `lib/services/photo_service.dart`

```dart
class PhotoService {
  static const _maxDimension = 1280; // lado maior
  static const _jpegQuality = 85;

  // Abre câmera, comprime e retorna bytes prontos para salvar
  static Future<Uint8List?> captureFromCamera() async { ... }

  // Abre galeria, comprime e retorna bytes
  static Future<Uint8List?> pickFromGallery() async { ... }

  // Comprime: redimensiona para max 1280px no lado maior, JPEG 85%
  // Usa flutter_image_compress
  static Future<Uint8List> compress(Uint8List original) async { ... }

  // Recupera captura perdida após o app ser morto em Android
  static Future<Uint8List?> recoverLostData() async { ... }

  // Solicita permissões de câmera + galeria
  static Future<bool> requestPermissions() async { ... }

  // Mostra diálogo direcionando para Configurações quando a permissão foi negada permanentemente
  static Future<bool> handlePermanentPermissionDenial(BuildContext context) async { ... }
}
```

---

### `lib/services/photo_sync_service.dart`

```dart
class PhotoSyncService {
  // Tenta sincronizar todas as fotos não sincronizadas com o servidor.
  // Se offline, exibe snackbar de aviso e retorna false.
  // Usa sync_status: 'pending_upload' | 'synced'
  static Future<bool> syncAll(BuildContext context) async { ... }

  // Envia uma foto específica
  static Future<void> _uploadPhoto(PhotoRecord photo) async { ... }

  // Envia remoções pendentes
  static Future<void> _flushPendingDeletes() async { ... }

  // Baixa e salva localmente fotos do servidor para itens conhecidos
  static Future<void> downloadPhotos(List<String> numeros) async { ... }
}
```

**Regras adicionais de sincronização:**
- `syncAll()` deve processar primeiro uploads pendentes e depois deleções pendentes.
- `downloadPhotos()` só deve rodar sob demanda controlada: ao abrir detalhe de item sem fotos locais ou em restauração pós-login/instalação.
- Se o servidor responder `409` por limite excedido ou conflito, o app mantém a foto local marcada como pendente e informa o usuário para resolução manual.

---

### `lib/widgets/photo_grid_widget.dart`

Widget reutilizável exibindo o grid de fotos de um item.

**Props:**
- `numeroPatrimonio` — chave para buscar/salvar fotos
- `readOnly: bool` — se `true`, não mostra botões de add/remove (para visualização no inventário)

**Comportamento:**
- Exibe até 3 thumbs quadrados (100×100)
- Thumb com `+` aparece quando há menos de 3 fotos **e** `readOnly == false`
- Ao tocar num thumb existente → abre `PhotoViewerPage` com opção de deletar (se `readOnly == false`)
- Ao tocar em `+` → bottom sheet com opções "Câmera" e "Galeria"
- Enquanto carrega/salva, mostra `CircularProgressIndicator` no lugar do thumb
- Se houver conflito de sync ou erro de permissão permanente, exibe mensagem clara e ação corretiva

```
┌──────┬──────┬──────┐
│foto1 │foto2 │  +   │  ← readOnly=false, 2 fotos salvas
└──────┴──────┴──────┘

┌──────┬──────┐
│foto1 │foto2 │        ← readOnly=true, apenas visualização
└──────┴──────┘
```

---

### `lib/screens/photo_viewer_page.dart`

Tela full-screen para visualização de uma foto.

- Usa `photo_view` para pinch-to-zoom
- Fundo escuro (`Colors.black`)
- Botão `X` no canto superior direito (fecha a tela)
- Se `readOnly == false`: botão de lixeira no canto inferior direito para deletar
  - Confirmação via dialog antes de deletar
- Suporte a deslizar horizontalmente para navegar entre fotos do item (`PageView` + `photo_view`)
- Indicador de página (`1/2`, `2/2`, etc.)

---

### Alterações em `individual_scan_page.dart`

No formulário de edição do item (modal/card que aparece após scan ou busca manual):

**Onde inserir:** abaixo do campo "Situação", antes dos botões de ação.

```
┌─────────────────────────────────┐
│  Fotos do item                  │
│  ┌──────┬──────┬──────┐         │
│  │foto1 │foto2 │  +   │         │
│  └──────┴──────┴──────┘         │
└─────────────────────────────────┘
```

- `PhotoGridWidget(numeroPatrimonio: p.numeroPatrimonio, readOnly: false)`
- As fotos são salvas/deletadas imediatamente ao interagir (não precisa de "salvar" separado — o banco de fotos é independente)

---

### Alterações em `inventory_list_page.dart`

**`_ItemTile`** — adicionar ícone de câmera no `trailing` quando o item tiver fotos:
- Pré-carregar uma vez por tela `Set<String> numerosComFotos = await PhotoDatabase.getAllNumbersWithPhotos()`
- Consultar o `Set` em memória ao montar cada tile
- Exibir `Icon(Icons.photo_camera, color: Colors.blue)` se tiver fotos

**Tap no item** — navegar para nova tela de detalhe `ItemDetailPage` (ou bottom sheet expandido):
- Exibe todos os campos do item
- `PhotoGridWidget(numeroPatrimonio: p.numeroPatrimonio, readOnly: true)`

> **Nota:** Criar `ItemDetailPage` como tela simples — não é um formulário de edição, apenas visualização com fotos. Para editar, o usuário deve escanear o item.

---

## Backend FastAPI — Novos Endpoints

### `app/models.py`
```python
class FotoPatrimonio(Base):
    __tablename__ = "fotos_patrimonio"
    id = Column(Integer, primary_key=True, index=True)
    numero_patrimonio = Column(String, nullable=False, index=True)
    imagem_blob = Column(LargeBinary, nullable=False)
    data_modificacao = Column(DateTime, default=datetime.utcnow)
    sync_origin = Column(String, default="app")  # 'app' | 'server'
```

### `app/api/endpoints.py` — novos endpoints
```
POST   /patrimonio/{numero}/fotos        # upload de uma foto (multipart/form-data)
GET    /patrimonio/{numero}/fotos        # lista {id, data_modificacao} das fotos do item
GET    /patrimonio/{numero}/fotos/{id}   # download de uma foto específica (bytes)
DELETE /patrimonio/{numero}/fotos/{id}   # remove foto do servidor
```

**Requisitos de backend validados nesta entrega:**
- Reutilizar a mesma autenticação/autorização já aplicada aos endpoints patrimoniais.
- Garantir suporte a upload de pelo menos 5 MB por arquivo no FastAPI e no nginx.
- No `POST`, retornar o `id` da foto criada no servidor para persistir em `server_photo_id`.
- No `DELETE`, responder `204` para deleção idempotente quando a foto já não existir.
- No `GET /patrimonio/{numero}/fotos`, incluir metadados suficientes para evitar redownload desnecessário (`id`, `data_modificacao`).

---

## Fluxo de Sincronização

```
App abre após estar offline
    ↓
PhotoSyncService.syncAll()
    ↓
Para cada foto com sync_status='pending_upload':
  ├── Servidor disponível? → POST /patrimonio/{numero}/fotos → salva server_photo_id e marca 'synced'
  └── Servidor indisponível? → mantém 'pending_upload', exibe SnackBar uma única vez:
        "X foto(s) pendentes de sincronização com o servidor"

Depois processa fotos em `fotos_patrimonio_delete_queue`:
  ├── Servidor disponível? → DELETE /patrimonio/{numero}/fotos/{server_photo_id} → remove tombstone
  └── Servidor indisponível? → mantém tombstone para a próxima tentativa
```

**Quando disparar sync:**
- Ao abrir o app (background, silencioso — apenas avisa se houver pendências)
- Ao importar planilha nova
- Ao salvar ou deletar uma foto
- Ao usuário pedir restauração após limpar os dados do app

**Política inicial de conflito:**
- O limite de 3 fotos vale no conjunto local + servidor.
- Se o servidor já estiver no limite e o app tentar subir nova foto, o upload falha com `409`.
- Nesta primeira etapa não haverá merge automático entre dispositivos; a resolução será manual e explícita.

---

## Preservação entre Importações

`HiveDatabase.importData()` limpa apenas `patrimonio_box` e `raw_data_box`.  
O banco `fotos.db` (SQLite) **nunca é tocado** nessa operação.

Cenário descrito pelo usuário:
```
1ª importação: itens 10, 12, 14
  → item 14 ganha 2 fotos → salvo em fotos.db com numero='14'

2ª importação: itens 9, 10, 12, 14, 15
  → Hive é limpo e repopulado
  → fotos.db intacto
  → ao abrir item 14 no formulário: PhotoGridWidget busca fotos com numero='14' → encontra 2 fotos ✓
  → usuário deleta 1 e adiciona 1 → item 14 segue com 2 fotos
```

**Ajuste importante:**
- Após cada importação, o app deve detectar números com foto que não existem mais na planilha atual e marcá-los como órfãos em memória.
- Fotos órfãs não devem ser apagadas automaticamente nesta etapa.
- Deve existir ação manual de manutenção para limpar fotos órfãs posteriormente.

---

## Comportamento ao Limpar Cache / Dados do App

Há dois cenários diferentes:

1. **Importar nova planilha**
  - Apenas o Hive é limpo.
  - O SQLite de fotos permanece intacto.

2. **Limpar armazenamento/dados do app no Android**
  - Hive e SQLite local são apagados pelo sistema.
  - Fotos ainda não sincronizadas com o servidor são perdidas definitivamente.
  - Fotos já sincronizadas podem ser restauradas pelo fluxo de download sob demanda.

**Decisão de UX:**
- O app deve informar claramente que “limpar dados” remove fotos locais ainda não sincronizadas.
- Em reinstalação ou limpeza de dados, o app não baixa todas as fotos automaticamente; o restore é sob demanda por item ou via ação explícita de restauração.

---

## Permissões Android (Aplicadas)

Permissões utilizadas no `AndroidManifest.xml`:
```xml
<!-- já existente via permission_handler, verificar se presentes: -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />  <!-- Android 13+ -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />  <!-- Android 12 e abaixo -->
```

**Tratamento obrigatório de UX:**
- Se a permissão for negada temporariamente, permitir nova solicitação.
- Se a permissão for negada permanentemente, exibir diálogo com atalho para as configurações do app.
- Em Android, recuperar `lostData` do `image_picker` ao reabrir a tela relevante.

---

## Ordem de Implementação Executada

1. **`photo_database.dart`** — base de tudo; sem ela nada funciona
2. **`photo_service.dart`** — captura + compressão
3. **Backend** — endpoints FastAPI + modelo + retorno de `server_photo_id`
4. **`photo_sync_service.dart`** — sync de upload/delete e tratamento de conflitos
5. **`photo_grid_widget.dart`** — widget reutilizável (sem ele as UIs ficam incompletas)
6. **`photo_viewer_page.dart`** — viewer full-screen
7. **`individual_scan_page.dart`** — integrar grid no formulário de edição
8. **`inventory_list_page.dart`** — ícone de câmera no tile + tela de detalhe com pré-carga do índice de fotos

---

## Pontos Críticos Atendidos

- O schema nasceu com `server_photo_id`, `sync_status` e fila de deleção pendente.
- Não usar `FutureBuilder` por item na lista de inventário para descobrir se há foto.
- Conflitos entre dispositivos não serão resolvidos automaticamente nesta primeira etapa.
- Fotos órfãs não serão deletadas em importações; terão manutenção manual.
- Limpar dados do app apaga fotos locais não sincronizadas; isso precisa constar no fluxo e na comunicação ao usuário.
- O backend precisa retornar o ID remoto da foto e aceitar uploads com tamanho compatível.

---

## TODO Futuros (fora do escopo desta etapa)

- [ ] Exportar fotos: gerar `.zip` com planilha + pasta `/fotos/{numero_patrimonio}/` contendo os JPEGs
- [ ] Adicionar coluna na planilha exportada indicando quantidade de fotos disponíveis para o item
- [ ] Visualização de fotos diretamente na tela de escaneamento em lotes

---

## Estimativa de Impacto no Tamanho do App

| Cenário | Tamanho adicional |
|---|---|
| 10 itens com 3 fotos cada (300KB/foto) | ~9 MB no banco SQLite |
| 50 itens com fotos | ~45 MB |
| Pacotes adicionais no APK | +2–3 MB |

---

## Fotos no Webapp (Issue #6)

No navegador, as fotos ficam apenas no servidor (sem `fotos.db`), por Patrimônio, e sobrevivem à reimportação do Inventário.

- Tela de detalhe do Patrimônio: listar miniaturas, ampliar (zoom), remover (com confirmação), "Tirar foto" (câmera) e "Escolher arquivo".
- Redimensionamento no navegador antes do envio: canvas, máx. 1280 px no maior lado, JPEG 85%.
- API (`/api/v1/patrimonio/{numero}/fotos`, cookie de sessão + `X-CSRF-Token` em mutações): somente `image/jpeg` com assinatura JPEG (`415`), máx. 5 MB (`413`), arquivo vazio (`400`), máx. 3 fotos (`409`), Patrimônio inexistente (`404`). `DELETE` é idempotente (`204`). Download com `X-Content-Type-Options: nosniff`.
- Erros do servidor e do seletor são exibidos na seção de fotos.
- Fora do escopo: offline/sincronização (#8) e limpeza do código Android/APK (#9).

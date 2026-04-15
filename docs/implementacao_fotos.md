# Plano de Implementação: Fotos por Item Patrimonial

**Versão do plano:** 1.0 — Abril 2026  
**Status:** Aguardando implementação

---

## Visão Geral

Permitir ao usuário capturar e gerenciar até **3 fotos por item patrimonial**, armazenadas localmente no dispositivo como BLOBs em um banco SQLite independente do Hive. As fotos persistem entre importações de planilha (a chave é sempre o `numeroPatrimonio`). Quando o servidor estiver disponível, as fotos são sincronizadas automaticamente.

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

---

## Pacotes Novos Necessários

```yaml
# pubspec.yaml — adicionar em dependencies:
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
  data_modificacao TEXT NOT NULL   -- ISO 8601: 2026-04-13T14:30:00
);

CREATE INDEX idx_fotos_numero ON fotos_patrimonio(numero_patrimonio);
```

**Observações:**
- Um item pode ter de 0 a 3 registros nessa tabela.
- A tabela nunca é limpa em importações de planilha — apenas o Hive é limpo.
- Ao deletar uma foto, apenas aquele `id` é removido.

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
  screens/
    individual_scan_page.dart  ← adicionar seção de fotos no formulário de edição
    inventory_list_page.dart   ← tap no item abre detalhe com fotos
  backend/
    app/main.py                ← 3 novos endpoints de fotos
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

  // Adiciona foto (valida limite de 3). Lança Exception se já tiver 3.
  static Future<void> addPhoto(String numeroPatrimonio, Uint8List imageBytes) async { ... }

  // Remove foto pelo id
  static Future<void> deletePhoto(int id) async { ... }

  // Limpa todas as fotos de um item (ex.: item deletado)
  static Future<void> deleteAllPhotos(String numeroPatrimonio) async { ... }
}

class PhotoRecord {
  final int id;
  final String numeroPatrimonio;
  final Uint8List imageBytes;
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

  // Solicita permissões de câmera + galeria
  static Future<bool> requestPermissions() async { ... }
}
```

---

### `lib/services/photo_sync_service.dart`

```dart
class PhotoSyncService {
  // Tenta sincronizar todas as fotos não sincronizadas com o servidor.
  // Se offline, exibe snackbar de aviso e retorna false.
  // Usa coluna sync_status na tabela (adicionar: 'pending' | 'synced')
  static Future<bool> syncAll(BuildContext context) async { ... }

  // Envia uma foto específica
  static Future<void> _uploadPhoto(PhotoRecord photo) async { ... }

  // Baixa e salva localmente fotos do servidor para itens conhecidos
  static Future<void> downloadPhotos(List<String> numeros) async { ... }
}
```

**Nota:** Adicionar coluna `sync_status TEXT DEFAULT 'pending'` ao schema.

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
- Consultar `PhotoDatabase.hasPhotos(p.numeroPatrimonio)` com `FutureBuilder`
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

### `app/main.py` — novos endpoints
```
POST   /patrimonio/{numero}/fotos        # upload de uma foto (multipart/form-data)
GET    /patrimonio/{numero}/fotos        # lista {id, data_modificacao} das fotos do item
GET    /patrimonio/{numero}/fotos/{id}   # download de uma foto específica (bytes)
DELETE /patrimonio/{numero}/fotos/{id}   # remove foto do servidor
```

---

## Fluxo de Sincronização

```
App abre após estar offline
    ↓
PhotoSyncService.syncAll()
    ↓
Para cada foto com sync_status='pending':
    ├── Servidor disponível? → POST /patrimonio/{numero}/fotos → marca 'synced'
    └── Servidor indisponível? → mantém 'pending', exibe SnackBar uma única vez:
        "X foto(s) pendentes de sincronização com o servidor"
```

**Quando disparar sync:**
- Ao abrir o app (background, silencioso — apenas avisa se houver pendências)
- Ao importar planilha nova
- Ao salvar ou deletar uma foto

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

---

## Permissões Android

Adicionar em `AndroidManifest.xml`:
```xml
<!-- já existente via permission_handler, verificar se presentes: -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />  <!-- Android 13+ -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />  <!-- Android 12 e abaixo -->
```

---

## Ordem de Implementação Sugerida

1. **`photo_database.dart`** — base de tudo; sem ela nada funciona
2. **`photo_service.dart`** — captura + compressão
3. **`photo_grid_widget.dart`** — widget reutilizável (sem ele as UIs ficam incompletas)
4. **`photo_viewer_page.dart`** — viewer full-screen
5. **`individual_scan_page.dart`** — integrar grid no formulário de edição
6. **`inventory_list_page.dart`** — ícone de câmera no tile + tela de detalhe
7. **Backend** — endpoints FastAPI + modelo
8. **`photo_sync_service.dart`** — sincronização (pode ser feito por último pois offline já funciona)

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

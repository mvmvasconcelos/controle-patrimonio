import 'package:controle_patrimonio/screens/web_app.dart';
import 'package:controle_patrimonio/screens/web_batch_conferencia_page.dart';
import 'package:controle_patrimonio/services/batch_feedback_stub.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

class _Repository extends WebInventoryRepository {
  _Repository()
      : super(
            client: MockClient(
                (_) async => throw StateError('Unexpected request')));

  final entries = <String, InventoryEntry>{
    '100': const InventoryEntry(
      number: '100',
      description: 'Mesa de reunião',
      room: 'Sala A',
      responsible: 'Ana',
      status: 'Ativo',
    ),
    '200': const InventoryEntry(
      number: '200',
      description: 'Cadeira giratória',
      room: 'Sala B',
      responsible: 'Bia',
      status: 'Ativo',
    ),
  };
  final checked = <String>[];
  final queries = <Map<String, Object?>>[];
  final created = <NewInventoryEntry>[];
  final updates = <Map<String, String?>>[];
  Object? markError;
  Object? filtersError;

  InventoryEntry _view(InventoryEntry e) => InventoryEntry(
        number: e.number,
        description: e.description,
        room: e.room,
        responsible: e.responsible,
        status: e.status,
        notes: e.notes,
        checked: checked.contains(e.number),
      );

  @override
  Future<List<PatrimonyPhoto>> fetchPhotos(String number) async => const [];

  @override
  Future<AdminSession?> restoreSession() async => const AdminSession(
      username: 'admin', role: 'administrador', csrfToken: 'c');

  @override
  Future<InventoryFilters> fetchFilters() async {
    if (filtersError != null) throw filtersError!;
    return const InventoryFilters(
        rooms: ['Sala A', 'Sala B'], statuses: ['Ativo']);
  }

  @override
  Future<InventoryPage> fetchInventory({
    String? query,
    String? room,
    String? status,
    bool? checked,
    int offset = 0,
    int limit = 50,
  }) async {
    queries.add({'query': query, 'room': room, 'checked': checked});
    var list = entries.values.map(_view).toList();
    if (query != null && query.isNotEmpty) {
      list = list.where((e) => e.description.contains(query)).toList();
    }
    if (room != null) list = list.where((e) => e.room == room).toList();
    return InventoryPage(total: list.length, items: list);
  }

  @override
  Future<ConferenciaResult> markChecked(String number) async {
    if (markError != null) throw markError!;
    if (!entries.containsKey(number.trim())) {
      throw PatrimonyNotFoundException(number.trim());
    }
    final repeated = checked.contains(number.trim());
    checked.add(number.trim());
    return ConferenciaResult(
      number: number.trim(),
      repeated: repeated,
      checkedAt: DateTime.utc(2026),
    );
  }

  @override
  Future<InventoryEntry?> fetchEntry(String number) async =>
      entries[number] == null ? null : _view(entries[number]!);

  @override
  Future<InventoryEntry> updateEntry(
      String number, Map<String, String?> fields) async {
    updates.add(fields);
    final old = entries[number]!;
    entries[number] = InventoryEntry(
      number: number,
      description: fields['descricao'] ?? old.description,
      room: fields['sala'] ?? old.room,
      responsible: old.responsible,
      status: old.status,
    );
    return _view(entries[number]!);
  }

  @override
  Future<InventoryEntry> createEntry(NewInventoryEntry entry) async {
    created.add(entry);
    entries[entry.number] = InventoryEntry(
      number: entry.number,
      description: entry.description,
      room: entry.room,
      responsible: entry.responsible,
      status: entry.status,
    );
    if (entry.checked) checked.add(entry.number);
    return _view(entries[entry.number]!);
  }
}

Future<_Repository> _open(WidgetTester tester,
    {BarcodeScanner? scanBarcode}) async {
  final repository = _Repository();
  await tester.pumpWidget(MaterialApp(
    home: WebApp(repository: repository, scanBarcode: scanBarcode),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ver Inventário'));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('list searches and filters through the repository',
      (tester) async {
    final repository = await _open(tester);
    expect(find.text('Mesa de reunião'), findsOneWidget);
    expect(find.text('Cadeira giratória'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Mesa');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Cadeira giratória'), findsNothing);
    expect(repository.queries.last['query'], 'Mesa');

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conferência').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conferidos').last);
    await tester.pumpAndSettle();
    expect(repository.queries.last['checked'], isTrue);
  });

  testWidgets('manual Conferência marks the Patrimônio as checked',
      (tester) async {
    final repository = await _open(tester);
    await tester.tap(find.text('Conferir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Conferir'));
    await tester.pumpAndSettle();

    expect(repository.checked, ['100']);
    expect(find.text('Patrimônio 100 conferido.'), findsOneWidget);
  });

  testWidgets('batch Conferência continues manual reads with distinct results',
      (tester) async {
    final repository = await _open(tester);
    await tester.tap(find.text('Conferência em lote'));
    await tester.pumpAndSettle();

    final number = find.byType(TextField);
    await tester.enterText(number, '100');
    await tester.tap(find.text('Registrar Conferência'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Conferência registrada'), findsOneWidget);

    await tester.enterText(number, '100');
    await tester.tap(find.text('Registrar Conferência'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Duplicado'), findsOneWidget);

    await tester.enterText(number, '999');
    await tester.tap(find.text('Registrar Conferência'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não encontrado'), findsOneWidget);

    expect(repository.checked, ['100', '100']);
    expect(find.text('3 resultados nesta sessão'), findsOneWidget);
    expect(find.text('Patrimônio 100'), findsWidgets);
  });

  testWidgets('batch Conferência keeps API failures visible', (tester) async {
    final repository = await _open(tester);
    repository.markError = Exception('Falha de rede');
    await tester.tap(find.text('Conferência em lote'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Registrar Conferência'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Falha de rede'), findsOneWidget);
    expect(find.textContaining('Conferência registrada'), findsNothing);
    expect(find.text('1 resultado nesta sessão'), findsOneWidget);
  });

  testWidgets('batch feedback distinguishes success, duplicate and not found',
      (tester) async {
    final repository = _Repository();
    final feedback = <BatchFeedbackKind>[];
    await tester.pumpWidget(MaterialApp(
      home: WebBatchConferenciaPage(
        repository: repository,
        onFeedback: (kind) async => feedback.add(kind),
      ),
    ));
    await tester.pumpAndSettle();

    final number = find.byType(TextField);
    for (final value in ['100', '100', '999']) {
      await tester.enterText(number, value);
      await tester.tap(find.text('Registrar Conferência'));
      await tester.pumpAndSettle();
    }

    expect(feedback, [
      BatchFeedbackKind.success,
      BatchFeedbackKind.duplicate,
      BatchFeedbackKind.notFound,
    ]);
  });

  testWidgets('batch feedback playback failure is visible without losing result',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WebBatchConferenciaPage(
        repository: _Repository(),
        onFeedback: (_) async => throw StateError('audio blocked'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Registrar Conferência'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Feedback sonoro indisponível'), findsOneWidget);
    expect(find.textContaining('Conferência registrada'), findsOneWidget);
  });

  testWidgets('camera scan result is checked; manual entry stays available',
      (tester) async {
    final repository = await _open(tester, scanBarcode: (_) async => ' 200 ');
    await tester.tap(find.text('Conferir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Escanear com a câmera'));
    await tester.pumpAndSettle();

    expect(repository.checked, ['200']);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('unknown number offers registration and returns to checked list',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = await _open(tester);
    await tester.tap(find.text('Conferir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '999');
    await tester.tap(find.text('Conferir'));
    await tester.pumpAndSettle();
    expect(find.text('Patrimônio 999 não está no Inventário.'), findsOneWidget);
    expect(repository.checked, isEmpty);

    await tester.tap(find.text('Cadastrar patrimônio'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();
    expect(find.text('Campo obrigatório'), findsWidgets);
    expect(repository.created, isEmpty);

    final fields = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(fields.at(0)).controller!.text, '999');
    await tester.enterText(fields.at(1), 'Projetor');
    await tester.enterText(fields.at(2), 'Sala C');
    await tester.enterText(fields.at(3), 'Carla');
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(repository.created.single.number, '999');
    expect(repository.checked, ['999']);
    expect(find.text('Patrimônio 999 cadastrado e conferido.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Projetor'), findsOneWidget);
  });

  testWidgets('expired session during Conferência shows a clear error',
      (tester) async {
    final repository = await _open(tester);
    repository.markError = const SessionExpiredException();
    await tester.tap(find.text('Conferir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Conferir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sessão expirada'), findsOneWidget);
  });

  testWidgets('filter loading errors are visible without hiding the inventory',
      (tester) async {
    final repository = _Repository()
      ..filtersError = Exception('Falha nos filtros');
    await tester.pumpWidget(MaterialApp(
      home: WebApp(repository: repository),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver Inventário'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Falha ao carregar os filtros'), findsOneWidget);
    expect(find.text('Mesa de reunião'), findsOneWidget);
  });

  testWidgets('detail edits a Patrimônio and list reflects it', (tester) async {
    final repository = await _open(tester);
    await tester.tap(find.text('Mesa de reunião'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'), 'Mesa nova');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(repository.updates.single, {'descricao': 'Mesa nova'});
    expect(find.text('Patrimônio atualizado.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Mesa nova'), findsOneWidget);
  });
}

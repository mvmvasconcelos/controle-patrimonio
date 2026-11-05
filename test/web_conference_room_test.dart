import 'package:controle_patrimonio/screens/web_batch_conferencia_page.dart';
import 'package:controle_patrimonio/screens/web_patrimony_pages.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

class _RoomRepository extends WebInventoryRepository {
  _RoomRepository()
      : super(client: MockClient((_) async => throw StateError('Unexpected')));

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
  final updates = <Map<String, String?>>[];

  @override
  Future<InventoryFilters> fetchFilters() async =>
      const InventoryFilters(rooms: ['Sala A', 'Sala B'], statuses: ['Ativo']);

  @override
  Future<InventoryEntry?> fetchEntry(String number) async => entries[number];

  @override
  Future<List<PatrimonyPhoto>> fetchPhotos(String number) async => const [];

  @override
  Future<ConferenciaResult> markChecked(String number) async {
    final normalized = number.trim();
    if (!entries.containsKey(normalized)) {
      throw PatrimonyNotFoundException(normalized);
    }
    final repeated = checked.contains(normalized);
    checked.add(normalized);
    return ConferenciaResult(
      number: normalized,
      repeated: repeated,
      checkedAt: DateTime.utc(2026),
    );
  }

  @override
  Future<InventoryEntry> updateEntry(
      String number, Map<String, String?> fields) async {
    updates.add(fields);
    final old = entries[number]!;
    final updated = InventoryEntry(
      number: old.number,
      description: fields['descricao'] ?? old.description,
      room: fields['sala'] ?? old.room,
      responsible: old.responsible,
      status: old.status,
      notes: old.notes,
    );
    entries[number] = updated;
    return updated;
  }
}

Future<void> _open(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

Future<void> _chooseRoom(WidgetTester tester, String? room) async {
  if (room == null) {
    await tester.tap(find.text('Não'));
  } else {
    await tester.tap(find.byKey(const ValueKey('conference-room-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(room).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pular a seleção mostra que a Sala não foi informada',
      (tester) async {
    await _open(tester, WebConferenciaPage(repository: _RoomRepository()));
    expect(find.text('Selecionar Sala'), findsOneWidget);

    await _chooseRoom(tester, null);

    expect(find.text('Sala: Não informada'), findsOneWidget);
  });

  testWidgets('conferência individual confirma quando a Sala está correta',
      (tester) async {
    final repository = _RoomRepository();
    await _open(tester, WebConferenciaPage(repository: repository));
    await _chooseRoom(tester, 'Sala A');

    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Pesquisar manualmente'));
    await tester.pumpAndSettle();

    expect(repository.checked, ['100']);
    expect(find.textContaining('Sala correta: Sala A'), findsOneWidget);
    expect(repository.entries['100']!.room, 'Sala A');
  });

  testWidgets('divergência individual oferece edição pelo cadastro',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _RoomRepository();
    await _open(tester, WebConferenciaPage(repository: repository));
    await _chooseRoom(tester, 'Sala A');

    await tester.enterText(find.byType(TextField), '200');
    await tester.tap(find.text('Pesquisar manualmente'));
    await tester.pumpAndSettle();
    expect(find.text('Sala divergente'), findsOneWidget);
    expect(find.textContaining("Sala B"), findsWidgets);

    await tester.tap(find.text('Corrigir Sala'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Sala'), 'Sala A');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(repository.updates.single, {'sala': 'Sala A'});

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(repository.entries['200']!.room, 'Sala A');
  });

  testWidgets('lotes mostram a comparação de Sala para cada Patrimônio',
      (tester) async {
    final repository = _RoomRepository();
    await _open(tester, WebBatchConferenciaPage(repository: repository));
    await _chooseRoom(tester, 'Sala A');

    final number = find.byType(TextField);
    await tester.enterText(number, '100');
    await tester.tap(find.text('Pesquisar manualmente'));
    await tester.pumpAndSettle();
    expect(find.text('Sala correta: Sala A.'), findsOneWidget);

    await tester.enterText(number, '200');
    await tester.tap(find.text('Pesquisar manualmente'));
    await tester.pumpAndSettle();
    expect(find.text('Sala divergente'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sala divergente: cadastrada na Sala B'),
        findsOneWidget);
    expect(find.text('2 resultados nesta sessão'), findsOneWidget);
    expect(repository.entries['200']!.room, 'Sala B');
  });
}

import 'package:controle_patrimonio/screens/web_inventory_list.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

class _Repository extends WebInventoryRepository {
  _Repository()
      : super(client: MockClient((_) async => throw StateError('no http')));

  static const all = [
    InventoryEntry(
      number: '100',
      description: 'Mesa de reunião',
      room: 'Sala A',
      responsible: 'Ana',
      status: 'Ativo',
    ),
    InventoryEntry(
      number: '200',
      description: 'Cadeira giratória',
      room: 'Sala B',
      responsible: 'Bia',
      status: 'Baixado',
    ),
    InventoryEntry(
      number: '300',
      description: 'Mesa auxiliar',
      room: 'Sala B',
      responsible: 'Bia',
      status: 'Ativo',
    ),
  ];

  @override
  Future<InventoryFilters> fetchFilters() async => const InventoryFilters(
      rooms: ['Sala A', 'Sala B'], statuses: ['Ativo', 'Baixado']);

  @override
  Future<InventoryPage> fetchInventory({
    String? query,
    String? room,
    String? status,
    bool? checked,
    int offset = 0,
    int limit = 50,
  }) async {
    final needle = query?.toLowerCase() ?? '';
    final list = all
        .where((e) =>
            e.description.toLowerCase().contains(needle) &&
            (room == null || e.room == room) &&
            (status == null || e.status == status))
        .toList();
    return InventoryPage(
        total: list.length, items: list.skip(offset).take(limit).toList());
  }

  @override
  Future<InventoryEntry?> fetchEntry(String number) async =>
      all.firstWhere((e) => e.number == number);

  @override
  Future<List<PatrimonyPhoto>> fetchPhotos(String number) async => const [];
}

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: WebInventoryList(repository: _Repository())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rows show number, description, Sala and status', (tester) async {
    await _open(tester);
    expect(find.text('Mesa de reunião'), findsOneWidget);
    expect(find.text('100 • Sala: Sala A'), findsOneWidget);
    expect(find.text('Ativo'), findsNWidgets(2));
    expect(find.text('Baixado'), findsOneWidget);
    expect(find.text('3 de 3 itens'), findsOneWidget);
  });

  testWidgets('search narrows the list and updates the counter',
      (tester) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField), 'Mesa');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Cadeira giratória'), findsNothing);
    expect(find.text('2 de 3 itens'), findsOneWidget);
  });

  testWidgets('filter sheet restricts the list by Sala and situação',
      (tester) async {
    await _open(tester);
    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas as salas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sala B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas as situações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ativo').last);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('Mesa auxiliar'), findsOneWidget);
    expect(find.text('Mesa de reunião'), findsNothing);
    expect(find.text('Cadeira giratória'), findsNothing);
    expect(find.text('1 de 3 itens'), findsOneWidget);
  });

  testWidgets('tapping a row opens the Patrimônio detail', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Cadeira giratória'));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);
    expect(find.text('Cadeira giratória'), findsWidgets);
    expect(find.text('Sala B'), findsWidgets);
    expect(find.byType(WebInventoryList), findsNothing);
  });
}

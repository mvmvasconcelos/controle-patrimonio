import 'dart:async';

import 'package:controle_patrimonio/screens/web_home_page.dart';
import 'package:controle_patrimonio/services/offline/sync_status.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

class _HomeRepository extends WebInventoryRepository {
  _HomeRepository({this.total = 42, this.status = const SyncStatus()})
      : super(client: MockClient((_) async => throw StateError('rede')));

  final int total;
  SyncStatus status;
  int syncCalls = 0;
  final controller = StreamController<SyncStatus>.broadcast();

  @override
  SyncStatus get syncStatus => status;

  @override
  Stream<SyncStatus> get syncStatusChanges => controller.stream;

  @override
  Future<SyncStatus> synchronize() async {
    syncCalls++;
    return status;
  }

  @override
  Future<InventoryPage> fetchInventory({
    String? query,
    String? room,
    String? status,
    bool? checked,
    int offset = 0,
    int limit = 50,
  }) async =>
      InventoryPage(total: total, items: const []);
}

Future<void> _pump(
  WidgetTester tester,
  _HomeRepository repository, {
  VoidCallback? onOpenInventory,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: WebHomePage(
        repository: repository,
        onOpenInventory: onOpenInventory ?? () {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cartão mostra a data da última Sincronização e os itens',
      (tester) async {
    final repository = _HomeRepository(
      status: SyncStatus(lastSyncAt: DateTime(2026, 3, 7, 9, 5)),
    );
    await _pump(tester, repository);

    expect(find.text('Última sincronização'), findsOneWidget);
    expect(find.text('07/03/2026 09:05'), findsOneWidget);
    expect(find.text('42 patrimônios carregados'), findsOneWidget);
  });

  testWidgets('sem Sincronização anterior o cartão avisa', (tester) async {
    await _pump(tester, _HomeRepository(total: 1));

    expect(find.text('Nunca sincronizado'), findsOneWidget);
    expect(find.text('1 patrimônio carregado'), findsOneWidget);
  });

  testWidgets('cartão atualiza depois de uma nova Sincronização',
      (tester) async {
    final repository = _HomeRepository();
    await _pump(tester, repository);

    repository.controller
        .add(SyncStatus(lastSyncAt: DateTime(2026, 1, 2, 3, 4)));
    await tester.pumpAndSettle();

    expect(find.text('02/01/2026 03:04'), findsOneWidget);
  });

  testWidgets('botões levam às telas de escaneamento e ao inventário',
      (tester) async {
    var inventoryOpened = 0;
    await _pump(tester, _HomeRepository(),
        onOpenInventory: () => inventoryOpened++);

    await tester.tap(find.text('Escaneamento Individual'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Não'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Conferência'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Escaneamento em Lotes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Não'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Conferência em lote'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver Inventário'));
    expect(inventoryOpened, 1);
  });

  testWidgets('falha mostra a mensagem; Tentar Novamente usa a fila',
      (tester) async {
    final repository = _HomeRepository(
      status: const SyncStatus(lastError: 'Servidor indisponível'),
    );
    await _pump(tester, repository);

    expect(find.text('Falha na sincronização'), findsOneWidget);
    expect(find.text('Servidor indisponível'), findsOneWidget);

    await tester.tap(find.text('Tentar Novamente'));
    await tester.pumpAndSettle();
    expect(repository.syncCalls, 1);
  });

  testWidgets('Descartar esconde a falha até que outra ocorra', (tester) async {
    final repository = _HomeRepository(
      status: const SyncStatus(lastError: 'Servidor indisponível'),
    );
    await _pump(tester, repository);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Servidor indisponível'), findsNothing);
    expect(find.text('Tentar Novamente'), findsNothing);

    repository.controller.add(const SyncStatus(lastError: 'Outro erro'));
    await tester.pumpAndSettle();
    expect(find.text('Outro erro'), findsOneWidget);
  });
}

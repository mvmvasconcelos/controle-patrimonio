import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:controle_patrimonio/screens/web_app.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';

class _FakeRepository extends WebInventoryRepository {
  _FakeRepository(this.username, this.password)
      : super(
            client: MockClient(
                (_) async => throw StateError('Unexpected request')));

  final String username;
  final String password;
  bool _loggedIn = false;

  @override
  Future<AdminSession?> restoreSession() async => null;

  @override
  Future<AdminSession> login(String username, String password) async {
    if (username != this.username || password != this.password) {
      throw Exception('Credenciais inválidas');
    }
    _loggedIn = true;
    return AdminSession(
      username: username,
      role: 'administrador',
      csrfToken: 'csrf-test-token',
    );
  }

  @override
  Future<InventoryFilters> fetchFilters() async =>
      const InventoryFilters(rooms: [], statuses: []);

  @override
  Future<InventoryPage> fetchInventory({
    String? query,
    String? room,
    String? status,
    bool? checked,
    int offset = 0,
    int limit = 50,
  }) async {
    if (!_loggedIn) {
      throw StateError('Sessão ausente');
    }
    return const InventoryPage(total: 1, items: [
      InventoryEntry(
        number: 'patrimonio-test',
        description: 'Mesa de teste',
        room: 'Sala de teste',
        responsible: 'Administrador',
        status: 'Ativo',
      ),
        ]);
  }

  @override
  Future<void> logout() async {
    _loggedIn = false;
  }

  final importedNames = <String>[];
  final downloaded = <String>[];

  @override
  Future<ImportSummary> importInventory(String filename, List<int> bytes) async {
    importedNames.add(filename);
    return const ImportSummary(
      created: 3,
      updated: 2,
      unchanged: 1,
      errors: [ImportRowError(line: 5, message: 'Descrição ausente')],
    );
  }

  @override
  Future<DownloadedFile> exportChanges() async =>
      const DownloadedFile('alteracoes.csv', [1]);

  @override
  Future<DownloadedFile> exportReport() async =>
      const DownloadedFile('relatorio.csv', [2]);
}

String _randomValue() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(256).toRadixString(16)).join();
}

void main() {
  testWidgets('login errors are clear and successful login opens inventory',
      (tester) async {
    final username = _randomValue();
    final password = _randomValue();
    final repository = _FakeRepository(username, password);

    await tester.pumpWidget(
      MaterialApp(home: WebApp(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acesso do Administrador'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), username);
    await tester.enterText(find.byType(TextField).at(1), _randomValue());
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Credenciais inválidas'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), password);
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Mesa de teste'), findsOneWidget);
    expect(find.text(username), findsOneWidget);

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso do Administrador'), findsOneWidget);
  });

  testWidgets('data management imports, shows summary and downloads exports',
      (tester) async {
    final repository = _FakeRepository('u', 'p');
    final downloads = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: WebApp(
          repository: repository,
          pickInventoryFile: () async =>
              const PickedInventoryFile('inv.csv', [1]),
          saveDownload: (file) async => downloads.add(file.filename),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'u');
    await tester.enterText(find.byType(TextField).at(1), 'p');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Gestão de dados'));
    await tester.pumpAndSettle();
    expect(find.text('Gestão de dados'), findsOneWidget);

    await tester.tap(find.text('Importar Inventário'));
    await tester.pumpAndSettle();
    expect(repository.importedNames, ['inv.csv']);
    expect(find.text('Novos: 3'), findsOneWidget);
    expect(find.text('Atualizados: 2'), findsOneWidget);
    expect(find.text('Com erro: 1'), findsOneWidget);
    expect(find.text('Linha 5: Descrição ausente'), findsOneWidget);

    await tester.tap(find.text('Exportar alterações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar relatório'));
    await tester.pumpAndSettle();
    expect(downloads, ['alteracoes.csv', 'relatorio.csv']);
  });
}

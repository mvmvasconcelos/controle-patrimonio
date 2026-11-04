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
  Future<List<InventoryEntry>> loadInventory() async {
    if (!_loggedIn) {
      throw StateError('Sessão ausente');
    }
    return const [
      InventoryEntry(
        number: 'patrimonio-test',
        description: 'Mesa de teste',
        room: 'Sala de teste',
        responsible: 'Administrador',
        status: 'Ativo',
      ),
    ];
  }

  @override
  Future<void> logout() async {
    _loggedIn = false;
  }
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
}

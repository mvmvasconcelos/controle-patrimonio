import 'package:controle_patrimonio/app_info.dart';
import 'package:controle_patrimonio/screens/web_about_page.dart';
import 'package:controle_patrimonio/screens/web_cache_management_page.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

class _FakeRepository extends WebInventoryRepository {
  _FakeRepository({this.total = 10, this.modified = 0})
      : super(client: MockClient((_) async => throw StateError('no network')));

  int total;
  int modified;
  int resets = 0;
  int clears = 0;

  @override
  Future<LocalDataStats> localDataStats() async =>
      LocalDataStats(total: total, modified: modified);

  @override
  Future<void> resetLocalChanges() async {
    resets++;
    modified = 0;
  }

  @override
  Future<void> clearLocalData() async {
    clears++;
    total = 0;
    modified = 0;
  }
}

Future<void> _open(
  WidgetTester tester,
  _FakeRepository repo, {
  VoidCallback? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WebCacheManagementPage(repository: repo, onChanged: onChanged),
    ),
  );
  await tester.pumpAndSettle();
}

ButtonStyleButton resetButton(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(find.ancestor(
      of: find.text('Resetar modificações'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ));

void main() {
  group('Gerenciar Dados e Cache', () {
    testWidgets('mostra total importado e modificados', (tester) async {
      await _open(tester, _FakeRepository(total: 42, modified: 3));

      expect(find.text('Gerenciar Dados e Cache'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Total importado'), findsOneWidget);
      expect(find.text('Modificados'), findsOneWidget);
      expect(find.text('Ações de risco'), findsOneWidget);
    });

    testWidgets('resetar fica desabilitado sem modificações', (tester) async {
      await _open(tester, _FakeRepository(modified: 0));

      final button = resetButton(tester);
      expect(button.onPressed, isNull);
    });

    testWidgets('resetar pede confirmação e zera os modificados', (
      tester,
    ) async {
      final repo = _FakeRepository(modified: 2);
      var changed = 0;
      await _open(tester, repo, onChanged: () => changed++);

      await tester.tap(find.text('Resetar modificações'));
      await tester.pumpAndSettle();
      expect(find.text('Resetar modificações?'), findsOneWidget);
      expect(repo.resets, 0);

      await tester.tap(find.text('Resetar'));
      await tester.pumpAndSettle();
      expect(repo.resets, 1);
      expect(changed, 1);
      expect(find.text('Modificações resetadas com sucesso'), findsOneWidget);
      final button = resetButton(tester);
      expect(button.onPressed, isNull);
    });

    testWidgets('limpar tudo pede confirmação e cancelar não apaga', (
      tester,
    ) async {
      final repo = _FakeRepository(total: 5);
      await _open(tester, repo);

      await tester.tap(find.text('Limpar tudo'));
      await tester.pumpAndSettle();
      expect(find.text('Limpar tudo?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repo.clears, 0);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('limpar tudo confirmado apaga os dados locais', (tester) async {
      final repo = _FakeRepository(total: 5, modified: 1);
      var changed = 0;
      await _open(tester, repo, onChanged: () => changed++);

      await tester.tap(find.text('Limpar tudo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Limpar'));
      await tester.pumpAndSettle();

      expect(repo.clears, 1);
      expect(changed, 1);
      expect(find.text('Todos os dados locais foram limpos'), findsOneWidget);
      expect(find.text('5'), findsNothing);
    });
  });

  group('Sobre', () {
    testWidgets('mostra nome, versão e data do build sem atualização de APK', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: WebAboutPage()));

      expect(find.text('Sobre'), findsWidgets);
      expect(find.text(AppInfo.name), findsOneWidget);
      expect(find.textContaining(AppInfo.version), findsOneWidget);
      expect(find.textContaining(AppInfo.buildDate), findsOneWidget);
      expect(find.textContaining('atualiza', findRichText: true), findsNothing);
      expect(find.textContaining('APK'), findsNothing);
    });
  });
}

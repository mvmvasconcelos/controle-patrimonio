import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> searchAndChoosePatrimony(
  WidgetTester tester, {
  required String query,
  required String number,
}) async {
  await tester.enterText(find.byType(TextField).first, query);
  await tester.tap(find.text('Pesquisar manualmente'));
  await tester.pumpAndSettle();
  expect(find.text('Buscar Patrimônio'), findsOneWidget);
  await tester.tap(find.text('Buscar'));
  await tester.pumpAndSettle();
  expect(find.textContaining('$number ·'), findsOneWidget);
  expect(find.textContaining('Sala:'), findsWidgets);
  await tester.tap(find.textContaining('$number ·'));
  await tester.pumpAndSettle();
}

Future<void> submitPatrimonyNumber(WidgetTester tester, String number) async {
  await tester.enterText(find.byType(TextField).first, number);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

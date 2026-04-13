import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:controle_patrimonio/screens/individual_scan_page.dart';
import 'package:controle_patrimonio/screens/batch_scan_page.dart';
import 'package:controle_patrimonio/providers/patrimonio_provider.dart';

void main() {
  testWidgets('IndividualScanPage UI Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PatrimonioProvider()),
        ],
        child: const MaterialApp(
          home: IndividualScanPage(selectedSala: 'Sala 101'),
        ),
      ),
    );

    // Verify basic UI elements
    expect(find.text('Escaneamento Individual'), findsOneWidget);
    expect(find.text('Sala: Sala 101'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    expect(find.text('Pesquisar manualmente'), findsOneWidget);
  });

  testWidgets('BatchScanPage UI Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PatrimonioProvider()),
        ],
        child: const MaterialApp(
          home: BatchScanPage(selectedSala: 'Sala 102'),
        ),
      ),
    );

    // Verify basic UI elements
    expect(find.text('Escaneamento em Lotes'), findsOneWidget);
    expect(find.text('Sala: Sala 102'), findsOneWidget);
    expect(find.text('Escanear'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });
}

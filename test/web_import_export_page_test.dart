import 'package:controle_patrimonio/screens/web_data_management_page.dart';
import 'package:controle_patrimonio/screens/web_import_export_page.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

class _Repository extends WebInventoryRepository {
  _Repository({this.total = 10, this.modified = 0})
      : super(client: MockClient((_) async => throw StateError('sem rede')));

  int total;
  int modified;
  final imported = <String>[];
  final exports = <(ExportFormat, bool)>[];
  int restoreCalls = 0;
  int cleanCalls = 0;

  @override
  Future<InventoryTotals> fetchTotals() async =>
      InventoryTotals(total: total, modified: modified);

  @override
  Future<ImportSummary> importInventory(
      String filename, List<int> bytes) async {
    imported.add(filename);
    total = 25;
    return const ImportSummary(
        created: 25, updated: 0, unchanged: 0, errors: []);
  }

  @override
  Future<DownloadedFile> exportSpreadsheet({
    required ExportFormat format,
    required bool onlyModified,
    DateTime? now,
  }) async {
    exports.add((format, onlyModified));
    return DownloadedFile('saida.${format.name}', const [1]);
  }

  @override
  Future<int> restoreSyncedPhotos() async {
    restoreCalls++;
    return 4;
  }

  @override
  Future<int> cleanOrphanPhotos() async {
    cleanCalls++;
    return 2;
  }
}

Future<void> _open(
  WidgetTester tester,
  _Repository repository, {
  List<String>? downloads,
  VoidCallback? onOpenInventory,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: WebImportExportPage(
      repository: repository,
      pickFile: () async => const PickedInventoryFile('suap.xlsx', [1]),
      saveDownload: (file) async => downloads?.add(file.filename),
      onOpenInventory: onOpenInventory,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra total importado e modificados', (tester) async {
    await _open(tester, _Repository(total: 10, modified: 3));
    expect(find.text('Importar / Exportar'), findsOneWidget);
    expect(find.text('Total importado'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Modificados'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('Ver inventário completo aciona o callback', (tester) async {
    var opened = 0;
    await _open(tester, _Repository(), onOpenInventory: () => opened++);
    await tester.tap(find.text('Ver inventário completo'));
    expect(opened, 1);
  });

  testWidgets('exportar só modificados fica desabilitado sem modificações',
      (tester) async {
    await _open(tester, _Repository(modified: 0));
    final card = find.widgetWithText(ListTile, 'Somente itens modificados');
    expect(tester.widget<ListTile>(card).enabled, isFalse);
    expect(
        tester
            .widget<ListTile>(
                find.widgetWithText(ListTile, 'Planilha completa'))
            .enabled,
        isTrue);
  });

  testWidgets('exporta modificados em csv e planilha completa em xlsx',
      (tester) async {
    final repository = _Repository(modified: 2);
    final downloads = <String>[];
    await _open(tester, repository, downloads: downloads);

    await tester.tap(find.text('.csv'));
    await tester.pump();
    await tester.tap(find.text('Somente itens modificados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('.xlsx'));
    await tester.pump();
    await tester.tap(find.text('Planilha completa'));
    await tester.pumpAndSettle();

    expect(repository.exports,
        [(ExportFormat.csv, true), (ExportFormat.xlsx, false)]);
    expect(downloads, ['saida.csv', 'saida.xlsx']);
  });

  testWidgets(
      'importar explica a atualização e preservação e só importa ao confirmar',
      (tester) async {
    final repository = _Repository();
    await _open(tester, repository);
    expect(
        find.textContaining("patrimônios ausentes do arquivo"), findsOneWidget);

    await tester.tap(find.text('Selecionar arquivo'));
    await tester.pumpAndSettle();
    expect(find.text('Atenção'), findsOneWidget);
    expect(find.textContaining("nem altera conferências ou fotos existentes"),
        findsNWidgets(2));
    await tester.tap(find.text("Cancelar"));
    await tester.pumpAndSettle();
    expect(repository.imported, isEmpty);

    await tester.tap(find.text("Selecionar arquivo"));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(repository.imported, ['suap.xlsx']);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('Novos: 25'), findsOneWidget);
  });

  testWidgets('restaura fotos sincronizadas e limpa órfãs', (tester) async {
    final repository = _Repository();
    await _open(tester, repository);

    await tester.tap(find.text('Restaurar fotos sincronizadas'));
    await tester.pumpAndSettle();
    expect(repository.restoreCalls, 1);
    expect(find.textContaining('4 foto(s) restaurada(s)'), findsOneWidget);

    await tester.tap(find.text('Limpar fotos órfãs'));
    await tester.pumpAndSettle();
    expect(repository.cleanCalls, 1);
    expect(
        find.textContaining('2 foto(s) órfã(s) removida(s)'), findsOneWidget);
  });
}

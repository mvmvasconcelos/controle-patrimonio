import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_patrimonio/models/patrimonio.dart';
import 'package:controle_patrimonio/providers/patrimonio_provider.dart';
import 'package:controle_patrimonio/services/report_service.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:controle_patrimonio/database/hive_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Mock path_provider method channel for unit tests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );

    await setUpTestHive();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PatrimonioAdapter());
    }
    await Hive.openBox<Patrimonio>('patrimonios');
    await Hive.openBox('settings');

    HiveDatabase.patrimonioBox = Hive.box<Patrimonio>('patrimonios');
    HiveDatabase.settingsBox = Hive.box('settings');
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('ReportService generates Excel files for modified, grouped and missing reports', () async {
    final item1 = Patrimonio(
      numeroPatrimonio: '1001',
      descricao: 'Computador i5',
      sala: 'Lab 01',
      responsavel: 'Carlos',
      situacao: 'Bom',
      isModified: true,
      modifiedFields: {'sala': 'Lab 01'},
    );

    final item2 = Patrimonio(
      numeroPatrimonio: '1002',
      descricao: 'Monitor 24',
      sala: 'Lab 01',
      responsavel: 'Carlos',
      situacao: 'Bom',
    );

    // 1. Report of modified items
    final modifiedFile = await ReportService.generateReport([item1]);
    expect(modifiedFile.existsSync(), isTrue);
    expect(modifiedFile.path.endsWith('.xlsx'), isTrue);

    // 2. Report grouped by room
    final groupedRoomFile = await ReportService.generateGroupedReport(
      [item1, item2],
      isByRoom: true,
    );
    expect(groupedRoomFile.existsSync(), isTrue);

    // 3. Report grouped by responsible
    final groupedRespFile = await ReportService.generateGroupedReport(
      [item1, item2],
      isByRoom: false,
    );
    expect(groupedRespFile.existsSync(), isTrue);

    // 4. Report of missing items
    final missingFile = await ReportService.generateMissingReport(
      sala: 'Lab 01',
      missingItems: [item2],
    );
    expect(missingFile.existsSync(), isTrue);
  });

  test('PatrimonioProvider getSalasUnicas returns distinct sorted room names', () async {
    final provider = PatrimonioProvider();
    await provider.loadLocalData();

    await provider.addPatrimonio(Patrimonio(
      numeroPatrimonio: '1',
      descricao: 'Item 1',
      sala: 'Sala B',
      responsavel: 'Ana',
      situacao: 'Bom',
    ));

    await provider.addPatrimonio(Patrimonio(
      numeroPatrimonio: '2',
      descricao: 'Item 2',
      sala: 'Sala A',
      responsavel: 'Ana',
      situacao: 'Bom',
    ));

    await provider.addPatrimonio(Patrimonio(
      numeroPatrimonio: '3',
      descricao: 'Item 3',
      sala: 'Sala B',
      responsavel: 'Bruno',
      situacao: 'Bom',
    ));

    final rooms = provider.getSalasUnicas();
    expect(rooms, equals(['Sala A', 'Sala B']));
  });
}

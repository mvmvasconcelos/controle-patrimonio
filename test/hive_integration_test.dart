import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:controle_patrimonio/models/patrimonio.dart';
import 'package:controle_patrimonio/database/hive_database.dart';

void main() {
  group('Hive Database Integration Tests', () {
    late Directory tempDir;

    setUp(() async {
      // Create a temporary directory for the test database
      tempDir = await Directory.systemTemp.createTemp('hive_test');
      
      // Initialize Hive with the temp path
      Hive.init(tempDir.path);
      
      // Register adapter if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(PatrimonioAdapter());
      }
      
      // Open boxes
      await Hive.openBox<Patrimonio>(HiveDatabase.patrimonioBoxName);
      await Hive.openBox(HiveDatabase.settingsBoxName);
    });

    tearDown(() async {
      // Close and delete boxes
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('Should save and retrieve a Patrimonio item', () async {
      final item = Patrimonio(
        id: 1,
        numeroPatrimonio: '123456',
        descricao: 'Cadeira Giratória',
        sala: 'Sala 101',
        responsavel: 'João Silva',
        situacao: 'Bom',
      );

      // Save
      await HiveDatabase.savePatrimonioData([item]);

      // Retrieve
      final savedItems = HiveDatabase.getAllPatrimonios();
      
      expect(savedItems.length, 1);
      expect(savedItems.first.numeroPatrimonio, '123456');
      expect(savedItems.first.descricao, 'Cadeira Giratória');
    });

    test('Should update an existing Patrimonio item', () async {
      final item = Patrimonio(
        id: 2,
        numeroPatrimonio: '987654',
        descricao: 'Mesa de Escritório',
        sala: 'Sala 102',
        responsavel: 'Maria Souza',
        situacao: 'Bom',
      );

      // Save initial
      await HiveDatabase.savePatrimonioData([item]);
      
      // Verify initial save
      var savedItems = HiveDatabase.getAllPatrimonios();
      expect(savedItems.first.situacao, 'Bom');

      // Update
      final updatedItem = savedItems.first.copyWith(
        situacao: 'Danificado',
        isModified: true,
      );
      await HiveDatabase.updatePatrimonio(updatedItem);

      // Verify update
      savedItems = HiveDatabase.getAllPatrimonios();
      expect(savedItems.length, 1);
      expect(savedItems.first.situacao, 'Danificado');
      expect(savedItems.first.isModified, true);
    });

    test('Should filter Patrimonios by Sala', () async {
      final items = [
        Patrimonio(numeroPatrimonio: '1', descricao: 'Item 1', sala: 'Sala A', responsavel: 'R1', situacao: 'Bom'),
        Patrimonio(numeroPatrimonio: '2', descricao: 'Item 2', sala: 'Sala B', responsavel: 'R2', situacao: 'Bom'),
        Patrimonio(numeroPatrimonio: '3', descricao: 'Item 3', sala: 'Sala A', responsavel: 'R1', situacao: 'Bom'),
      ];

      await HiveDatabase.savePatrimonioData(items);

      final salaAItems = HiveDatabase.getPatrimoniosBySala('Sala A');
      final salaBItems = HiveDatabase.getPatrimoniosBySala('Sala B');

      expect(salaAItems.length, 2);
      expect(salaBItems.length, 1);
    });
    
    test('Should persist data (simulate offline storage)', () async {
       // This test relies on the fact that we are writing to a real file system (tempDir)
       // and reading back from it via the Hive abstraction.
       
       final item = Patrimonio(
        numeroPatrimonio: 'OFFLINE_TEST',
        descricao: 'Teste Offline',
        sala: 'Sala Server',
        responsavel: 'Admin',
        situacao: 'Novo',
      );
      
      await HiveDatabase.savePatrimonioData([item]);
      
      expect(HiveDatabase.hasPatrimonioData(), true);
      
      final retrieved = HiveDatabase.getPatrimonioByNumero('OFFLINE_TEST');
      expect(retrieved, isNotNull);
      expect(retrieved!.descricao, 'Teste Offline');
    });
  });
}

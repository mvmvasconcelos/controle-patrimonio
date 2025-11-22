import 'package:flutter_test/flutter_test.dart';
import 'package:controle_patrimonio/providers/patrimonio_provider.dart';
import 'package:controle_patrimonio/models/patrimonio.dart';
import 'package:controle_patrimonio/database/hive_database.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

void main() {
  setUp(() async {
    await setUpTestHive();
    // Register Adapter
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PatrimonioAdapter());
    }
    await Hive.openBox<Patrimonio>('patrimonios');
    await Hive.openBox('settings');
    
    // Inject boxes into HiveDatabase for testing
    HiveDatabase.patrimonioBox = Hive.box<Patrimonio>('patrimonios');
    HiveDatabase.settingsBox = Hive.box('settings');
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('Tracking Logic: Preserves original values across multiple edits', () async {
    final provider = PatrimonioProvider();
    await provider.loadLocalData();

    // 1. Create initial item
    final initialItem = Patrimonio(
      numeroPatrimonio: '123',
      descricao: 'Cadeira Velha',
      sala: '101',
      responsavel: 'Joao',
      situacao: 'Bom',
    );
    await provider.addPatrimonio(initialItem);

    // 2. First Edit: Change Description 'Cadeira Velha' -> 'Cadeira Nova'
    var item = provider.getPatrimonioByNumero('123')!;
    await provider.updatePatrimonio(item, {'descricao': 'Cadeira Nova'});

    // Verify First Edit
    item = provider.getPatrimonioByNumero('123')!;
    expect(item.isModified, true);
    expect(item.descricao, 'Cadeira Nova');
    expect(item.originalValues?['descricao'], 'Cadeira Velha'); // Should be preserved
    expect(item.modifiedFields?['descricao'], 'Cadeira Nova');

    // 3. Second Edit: Change Description 'Cadeira Nova' -> 'Cadeira Gamer'
    await provider.updatePatrimonio(item, {'descricao': 'Cadeira Gamer'});

    // Verify Second Edit
    item = provider.getPatrimonioByNumero('123')!;
    expect(item.descricao, 'Cadeira Gamer');
    expect(item.originalValues?['descricao'], 'Cadeira Velha'); // MUST still be 'Cadeira Velha'
    expect(item.modifiedFields?['descricao'], 'Cadeira Gamer');
  });

  test('Tracking Logic: Reverting to original value clears modified status', () async {
    final provider = PatrimonioProvider();
    await provider.loadLocalData();

    final initialItem = Patrimonio(
      numeroPatrimonio: '456',
      descricao: 'Mesa',
      sala: '200',
      responsavel: 'Maria',
      situacao: 'Bom',
    );
    await provider.addPatrimonio(initialItem);

    // Edit: Mesa -> Mesa Grande
    var item = provider.getPatrimonioByNumero('456')!;
    await provider.updatePatrimonio(item, {'descricao': 'Mesa Grande'});
    
    item = provider.getPatrimonioByNumero('456')!;
    expect(item.isModified, true);

    // Revert: Mesa Grande -> Mesa
    await provider.updatePatrimonio(item, {'descricao': 'Mesa'});

    // Verify Revert
    item = provider.getPatrimonioByNumero('456')!;
    expect(item.isModified, false);
    expect(item.originalValues, null); // Should be cleared
    expect(item.modifiedFields, null); // Should be cleared
  });
}

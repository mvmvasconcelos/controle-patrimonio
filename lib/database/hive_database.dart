import 'package:hive_flutter/hive_flutter.dart';
import '../models/patrimonio.dart';

class HiveDatabase {
  static const String patrimonioBoxName = 'patrimonio_box';
  static const String settingsBoxName = 'settings_box';
  static const String rawDataBoxName = 'raw_data_box';

  static Future<void> init() async {
    // Inicializar Hive
    await Hive.initFlutter();

    // Registrar adaptadores
    Hive.registerAdapter(PatrimonioAdapter());

    // Abrir boxes
    await Hive.openBox<Patrimonio>(patrimonioBoxName);
    await Hive.openBox(settingsBoxName);
    await Hive.openBox<Map>(rawDataBoxName);

    // Seed de desenvolvimento: garantir que exista um patrimônio mock
    // válido para testes (número 253170). Não sobrescreve se já existir.
    final box = patrimonioBox;
    final exists = box.values.cast<Patrimonio?>().any(
      (p) => p != null && p.numeroPatrimonio == '253170',
    );

    if (!exists) {
      final mock = Patrimonio(
        id: null,
        numeroPatrimonio: '253170',
        descricao: 'Mockup válido para testes',
        sala: 'Sala de Teste',
        responsavel: 'Automated Mock',
        situacao: 'Ativo',
        observacoes: 'Inserido automaticamente para testes locais',
      );

      await box.add(mock);
    }
  }

  // Box para armazenar os dados do patrimônio
  static Box<Patrimonio>? _patrimonioBox;
  static Box<Patrimonio> get patrimonioBox {
    return _patrimonioBox ?? Hive.box<Patrimonio>(patrimonioBoxName);
  }
  static set patrimonioBox(Box<Patrimonio> box) {
    _patrimonioBox = box;
  }

  // Box para configurações do app
  static Box? _settingsBox;
  static Box get settingsBox {
    return _settingsBox ?? Hive.box(settingsBoxName);
  }
  static set settingsBox(Box box) {
    _settingsBox = box;
  }

  // Box para dados brutos originais do CSV/XLS (chave = numeroPatrimonio)
  static Box<Map> get rawDataBox => Hive.box<Map>(rawDataBoxName);

  static Map<String, String>? getRawRow(String numeroPatrimonio) {
    final raw = rawDataBox.get(numeroPatrimonio);
    if (raw == null) return null;
    return raw.cast<String, String>();
  }

  // Métodos para gerenciar dados do patrimônio
  static Future<void> savePatrimonioData(List<Patrimonio> patrimonios) async {
    final box = patrimonioBox;
    await box.clear(); // Limpar dados antigos
    await box.addAll(patrimonios);
  }

  static List<Patrimonio> getAllPatrimonios() {
    return patrimonioBox.values.toList();
  }

  static Patrimonio? getPatrimonioByNumero(String numeroPatrimonio) {
    return patrimonioBox.values
        .cast<Patrimonio?>()
        .firstWhere(
          (patrimonio) => patrimonio?.numeroPatrimonio == numeroPatrimonio,
          orElse: () => null,
        );
  }

  static List<Patrimonio> getPatrimoniosBySala(String sala) {
    return patrimonioBox.values
        .where((patrimonio) => patrimonio.sala == sala)
        .toList();
  }

  static Future<void> updatePatrimonio(Patrimonio patrimonio) async {
    final box = patrimonioBox;
    var key = patrimonio.key;

    // Se a chave for nula (objeto criado via copyWith), tentar encontrar pelo número
    if (key == null) {
      final existing = getPatrimonioByNumero(patrimonio.numeroPatrimonio);
      if (existing != null) {
        key = existing.key;
      }
    }

    if (key != null) {
      await box.put(key, patrimonio);
    } else {
      await box.add(patrimonio);
    }
  }

  static Future<void> deletePatrimonio(Patrimonio patrimonio) async {
    await patrimonio.delete();
  }

  // Importa dados de planilha: substitui tudo, preserva raw data
  static Future<void> importData(
    List<Patrimonio> patrimonios,
    List<Map<String, String>> rawRows,
  ) async {
    // Substituir todos os patricmônios
    final pBox = patrimonioBox;
    await pBox.clear();
    await pBox.addAll(patrimonios);

    // Substituir raw data
    final rBox = rawDataBox;
    await rBox.clear();
    for (final row in rawRows) {
      final numero = row['NUMERO'] ?? '';
      if (numero.isNotEmpty) {
        await rBox.put(numero, row);
      }
    }
  }

  // Verifica se há itens modificados pendentes de exportação
  static bool hasPendingModifications() {
    return patrimonioBox.values.any((p) => p.isModified);
  }

  // Métodos para configurações
  static T? getSetting<T>(String key, {T? defaultValue}) {
    return settingsBox.get(key, defaultValue: defaultValue);
  }

  static Future<void> setSetting<T>(String key, T value) async {
    await settingsBox.put(key, value);
  }

  // Método para verificar se os dados estão sincronizados
  static bool hasPatrimonioData() {
    return patrimonioBox.isNotEmpty;
  }

  // Método para limpar todos os dados
  static Future<void> clearAllData() async {
    await patrimonioBox.clear();
    await settingsBox.clear();
  }
}
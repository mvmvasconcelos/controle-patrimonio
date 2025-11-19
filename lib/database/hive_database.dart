import 'package:hive_flutter/hive_flutter.dart';
import '../models/patrimonio.dart';

class HiveDatabase {
  static const String patrimonioBoxName = 'patrimonio_box';
  static const String settingsBoxName = 'settings_box';

  static Future<void> init() async {
    // Inicializar Hive
    await Hive.initFlutter();

    // Registrar adaptadores
    Hive.registerAdapter(PatrimonioAdapter());

    // Abrir boxes
    await Hive.openBox<Patrimonio>(patrimonioBoxName);
    await Hive.openBox(settingsBoxName);
  }

  // Box para armazenar os dados do patrimônio
  static Box<Patrimonio> get patrimonioBox =>
      Hive.box<Patrimonio>(patrimonioBoxName);

  // Box para configurações do app
  static Box get settingsBox => Hive.box(settingsBoxName);

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
import 'package:flutter/material.dart';
import 'screens/web_app.dart';
import 'services/offline/offline_inventory_repository.dart';
import 'services/offline/offline_store.dart';
import 'services/web_inventory_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(webRepository: await _createWebRepository()));
}

/// Cache offline em IndexedDB (Hive); se o navegador negar o armazenamento
/// (ex.: modo privativo), o app segue online-only.
Future<WebInventoryRepository> _createWebRepository() async {
  final remote = WebInventoryRepository();
  try {
    await Hive.initFlutter();
    return await OfflineInventoryRepository.create(
      remote: remote,
      store: await HiveOfflineStore.open(),
    );
  } catch (error) {
    debugPrint('Cache offline indisponível: $error');
    return remote;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.webRepository});

  final WebInventoryRepository? webRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle Patrimonial',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: WebApp(repository: webRepository),
    );
  }
}

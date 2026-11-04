import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'database/hive_database.dart';
import 'database/photo_database.dart';
import 'providers/patrimonio_provider.dart';
import 'providers/update_provider.dart';
import 'services/photo_sync_service.dart';
import 'screens/home_page.dart';
import 'screens/about_page.dart';
import 'screens/report_page.dart';
import 'screens/data_management_page.dart';
import 'screens/cache_management_page.dart';
import 'screens/inventory_list_page.dart';
import 'screens/web_app.dart';
import 'services/offline/offline_inventory_repository.dart';
import 'services/offline/offline_store.dart';
import 'services/web_inventory_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  WebInventoryRepository? webRepository;
  if (kIsWeb) {
    webRepository = await _createWebRepository();
  } else {
    await HiveDatabase.init();
    await PhotoDatabase.init();
  }

  runApp(MyApp(webRepository: webRepository));
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
    if (kIsWeb) {
      return MaterialApp(
        title: 'Controle Patrimonial',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: WebApp(repository: webRepository),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PatrimonioProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
      ],
      child: MaterialApp(
        title: 'Controle Patrimônio',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const _StartupSyncWrapper(child: HomePage()),
        routes: {
          '/about': (context) => const AboutPage(),
          '/report': (context) => const ReportPage(),
          '/data': (context) => const DataManagementPage(),
          '/data-cache': (context) => const CacheManagementPage(),
          '/inventory': (context) => const InventoryListPage(),
        },
      ),
    );
  }
}

class _StartupSyncWrapper extends StatefulWidget {
  final Widget child;

  const _StartupSyncWrapper({required this.child});

  @override
  State<_StartupSyncWrapper> createState() => _StartupSyncWrapperState();
}

class _StartupSyncWrapperState extends State<_StartupSyncWrapper> {
  bool _syncStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncStarted) {
      return;
    }

    _syncStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      PhotoSyncService.syncAll(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

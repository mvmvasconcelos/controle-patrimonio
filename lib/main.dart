import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database/hive_database.dart';
import 'providers/patrimonio_provider.dart';
import 'providers/update_provider.dart';
import 'screens/home_page.dart';
import 'screens/about_page.dart';
import 'screens/report_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Hive
  await HiveDatabase.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
        home: const HomePage(),
        routes: {
          '/about': (context) => const AboutPage(),
          '/report': (context) => const ReportPage(),
        },
      ),
    );
  }
}

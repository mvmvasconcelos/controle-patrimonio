import 'package:flutter/material.dart';

import '../app_info.dart';
import '../theme.dart';

class WebAboutPage extends StatelessWidget {
  const WebAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre')),
      body: CenteredColumn(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.archive, size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              AppInfo.name,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'IFSUL',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            const Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.tag),
                    title: Text('Versão'),
                    subtitle: Text(AppInfo.version),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.event),
                    title: Text('Data do build'),
                    subtitle: Text(AppInfo.buildDate),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

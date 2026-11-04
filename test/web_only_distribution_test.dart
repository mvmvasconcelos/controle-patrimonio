import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('distribuição exclusivamente web', () {
    test('não mantém projeto, atualizador ou artefatos de APK', () {
      for (final path in [
        'android',
        'web/apk',
        'web/update.html',
        'web/version.json',
        'compila.sh',
        'share.sh',
        'emulador.sh',
        'docs/emulator_setup.md',
        'scripts/adb_proxy.py',
        'scripts/connect_emulator.sh',
        'scripts/test_adb_handshake.py',
        'lib/services/update_service.dart',
        'lib/providers/update_provider.dart',
      ]) {
        expect(
          FileSystemEntity.typeSync(path),
          FileSystemEntityType.notFound,
          reason: '$path não deve fazer parte da distribuição web',
        );
      }
    });

    test('remove dependências usadas somente pelo aplicativo Android', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final lockfile = File('pubspec.lock').readAsStringSync();

      for (final package in [
        'sqflite',
        'flutter_image_compress',
        'open_filex',
        'package_info_plus',
        'path_provider',
        'permission_handler',
        'provider',
      ]) {
        expect(
          RegExp('^  $package:', multiLine: true).hasMatch(pubspec),
          isFalse,
          reason: package,
        );
      }
      expect(pubspec, isNot(contains('flutter_plugin_android_lifecycle')));

      for (final package in [
        'sqflite',
        'flutter_image_compress',
        'open_filex',
        'package_info_plus',
        'permission_handler',
        'provider',
      ]) {
        expect(
          RegExp('^  $package:', multiLine: true).hasMatch(lockfile),
          isFalse,
          reason: package,
        );
      }
    });

    test('Compose e documentação ativa não anunciam distribuição Android', () {
      final compose = File('docker-compose.yml').readAsStringSync();
      expect(compose, isNot(contains('builder:')));
      expect(compose, isNot(contains('android_sdk')));
      expect(compose, isNot(contains('ANDROID_HOME')));

      for (final path in [
        'README.md',
        'docs/AGENT_INSTRUCTIONS.md',
        'docs/ROADMAP.md',
        'docs/context/tech_stack.md',
        'docs/implementacao_fotos.md',
        'start.sh',
        'update-deps.sh',
      ]) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('android')), reason: path);
        expect(content, isNot(contains('apk')), reason: path);
        expect(content, isNot(contains('sqflite')), reason: path);
      }
    });

    test('preserva o app web e o cache offline em IndexedDB via Hive', () {
      final main = File('lib/main.dart').readAsStringSync();
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(main, contains('WebApp'));
      expect(main, contains('OfflineInventoryRepository'));
      expect(main, contains('HiveOfflineStore'));
      expect(RegExp('^  mobile_scanner:', multiLine: true).hasMatch(pubspec),
          isTrue);
      expect(RegExp('^  image_picker:', multiLine: true).hasMatch(pubspec),
          isTrue);

      for (final path in [
        'lib/screens/web_app.dart',
        'lib/screens/web_batch_conferencia_page.dart',
        'lib/widgets/barcode_scanner_screen.dart',
        'lib/services/web_inventory_repository.dart',
        'lib/services/offline/offline_inventory_repository.dart',
        'lib/services/offline/offline_store.dart',
        'lib/services/web_photo_picker.dart',
        'test/web_app_test.dart',
        'test/offline_inventory_repository_test.dart',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });
  });
}

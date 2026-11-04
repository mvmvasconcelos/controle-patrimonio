import 'dart:async';

import 'package:controle_patrimonio/services/offline/sync_status.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';
import 'package:controle_patrimonio/widgets/sync_status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

class _Repository extends WebInventoryRepository {
  _Repository(this._status)
      : super(client: MockClient((_) async => throw StateError('no request')));

  SyncStatus _status;
  final controller = StreamController<SyncStatus>.broadcast();
  var syncs = 0;

  void emit(SyncStatus status) {
    _status = status;
    controller.add(status);
  }

  @override
  SyncStatus get syncStatus => _status;

  @override
  Stream<SyncStatus> get syncStatusChanges => controller.stream;

  @override
  Future<SyncStatus> synchronize() async {
    syncs++;
    return _status;
  }
}

Future<void> _pump(WidgetTester tester, _Repository repository,
    {VoidCallback? onSessionExpired}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SyncStatusBar(
          repository: repository, onSessionExpired: onSessionExpired),
    ),
  ));
}

void main() {
  testWidgets('shows online with no pending items', (tester) async {
    await _pump(tester, _Repository(const SyncStatus()));
    expect(find.text('Online'), findsOneWidget);
    expect(find.textContaining('pendência'), findsNothing);
  });

  testWidgets('shows offline and pending count, updating from the stream',
      (tester) async {
    final repository = _Repository(const SyncStatus());
    await _pump(tester, repository);
    repository.emit(const SyncStatus(online: false, pending: 3));
    await tester.pump();
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('3 pendências'), findsOneWidget);
    repository.emit(const SyncStatus(online: false, pending: 1));
    await tester.pump();
    expect(find.text('1 pendência'), findsOneWidget);
  });

  testWidgets('manual sync button calls synchronize', (tester) async {
    final repository = _Repository(const SyncStatus(pending: 2));
    await _pump(tester, repository);
    await tester.tap(find.byTooltip('Sincronizar agora'));
    expect(repository.syncs, 1);
  });

  testWidgets('shows syncing, rejected items and conflicts', (tester) async {
    final repository = _Repository(
        const SyncStatus(syncing: true, pending: 2, failed: 1, conflicts: 2));
    await _pump(tester, repository);
    expect(find.text('Sincronizando…'), findsOneWidget);
    expect(find.text('1 com erro'), findsOneWidget);
    expect(find.textContaining('2 edições'), findsOneWidget);
  });

  testWidgets('expired session offers re-login and keeps pending visible',
      (tester) async {
    var relogin = 0;
    await _pump(
        tester, _Repository(const SyncStatus(sessionExpired: true, pending: 4)),
        onSessionExpired: () => relogin++);
    expect(find.text('Sessão expirada'), findsOneWidget);
    expect(find.text('4 pendências'), findsOneWidget);
    await tester.tap(find.text('Entrar novamente'));
    expect(relogin, 1);
  });
}

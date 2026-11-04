import 'dart:io';
import 'dart:typed_data';

import 'package:controle_patrimonio/services/offline/connectivity_monitor.dart';
import 'package:controle_patrimonio/services/offline/offline_inventory_repository.dart';
import 'package:controle_patrimonio/services/offline/offline_store.dart';
import 'package:controle_patrimonio/services/offline/sync_status.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'support/fake_server.dart';

final _base = Uri.parse('https://t.test/api/v1/');

Uint8List _jpeg(int length) =>
    Uint8List.fromList([0xff, 0xd8, 0xff, ...List.filled(length, 1)]);

class _FaultInjectingStore implements OfflineStore {
  _FaultInjectingStore(this.delegate);

  final OfflineStore delegate;
  bool failNextEntryWrite = false;

  @override
  Future<List<InventoryEntry>> entries() => delegate.entries();

  @override
  Future<InventoryEntry?> entry(String number) => delegate.entry(number);

  @override
  Future<void> putEntries(Iterable<InventoryEntry> entries) async {
    if (failNextEntryWrite) {
      failNextEntryWrite = false;
      throw StateError('simulated cache write failure');
    }
    await delegate.putEntries(entries);
  }

  @override
  Future<void> removeEntries(Iterable<String> numbers) =>
      delegate.removeEntries(numbers);

  @override
  Future<List<CachedPhoto>> photos(String number) => delegate.photos(number);

  @override
  Future<Uint8List?> photoBytes(String number, int id) =>
      delegate.photoBytes(number, id);

  @override
  Future<bool> putPhoto(String number, int id, Uint8List bytes,
          {required bool pending}) =>
      delegate.putPhoto(number, id, bytes, pending: pending);

  @override
  Future<void> removePhoto(String number, int id) =>
      delegate.removePhoto(number, id);

  @override
  Future<void> promotePhoto(String number, int temporaryId, int realId) =>
      delegate.promotePhoto(number, temporaryId, realId);

  @override
  Future<int> photoBytesUsed() => delegate.photoBytesUsed();

  @override
  Future<int> nextTemporaryPhotoId() => delegate.nextTemporaryPhotoId();

  @override
  Future<List<PendingOperation>> pendingOperations() =>
      delegate.pendingOperations();

  @override
  Future<PendingOperation> enqueue(PendingOperation operation) =>
      delegate.enqueue(operation);

  @override
  Future<void> updateOperation(PendingOperation operation) =>
      delegate.updateOperation(operation);

  @override
  Future<void> removeOperation(int id) => delegate.removeOperation(id);

  @override
  Future<String?> readMeta(String key) => delegate.readMeta(key);

  @override
  Future<void> writeMeta(String key, String value) =>
      delegate.writeMeta(key, value);

  @override
  Future<void> deleteMeta(String key) => delegate.deleteMeta(key);

  @override
  Future<void> close() => delegate.close();
}

void main() {
  late Directory dir;
  late FakeServer server;
  late ManualConnectivity network;
  late DateTime now;
  late OfflineInventoryRepository repo;
  late OfflineStore store;
  late _FaultInjectingStore faultStore;

  Future<OfflineInventoryRepository> open({int? budget}) async {
    store = await HiveOfflineStore.open(
        photoBudgetBytes: budget ?? defaultPhotoBudgetBytes);
    faultStore = _FaultInjectingStore(store);
    return OfflineInventoryRepository.create(
      remote: WebInventoryRepository(client: server.client, apiBaseUrl: _base),
      store: faultStore,
      connectivity: network,
      clock: () => now,
      retryInterval: null,
    );
  }

  // Simula recarregar a página: fecha o Hive e reabre o cache do disco.
  Future<void> reload({int? budget}) async {
    repo.dispose();
    await Hive.close();
    repo = await open(budget: budget);
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 300));

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('offline_repo');
    Hive.init(dir.path);
    server = FakeServer();
    network = ManualConnectivity(online: true);
    now = DateTime.utc(2026, 3, 1, 10);
    repo = await open();
    await repo.login('admin', 'x');
    await repo.synchronize();
  });

  tearDown(() async {
    repo.dispose();
    network.dispose();
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('sync downloads the Inventário and it is readable offline after reload',
      () async {
    server.down = true;
    network.set(false);
    await reload();
    final session = await repo.restoreSession();
    expect(session?.username, 'admin');
    final page = await repo.fetchInventory(query: 'mesa 101');
    expect(page.items.map((e) => e.number), ['101']);
    expect((await repo.fetchEntry('102'))!.description, 'Mesa 102');
    expect((await repo.fetchFilters()).rooms, ['Sala A']);
    expect((await repo.fetchConferenceReport()).total, 3);
  });

  test('offline Conferência survives reload and is sent when network returns',
      () async {
    server.down = true;
    network.set(false);
    final result = await repo.markChecked('101');
    expect(result.repeated, isFalse);
    expect((await repo.fetchEntry('101'))!.checked, isTrue);
    expect(repo.syncStatus.pending, 1);
    expect(repo.syncStatus.online, isFalse);

    await reload();
    expect(repo.syncStatus.pending, 1);
    expect((await repo.fetchEntry('101'))!.checked, isTrue);

    server.down = false;
    network.set(true);
    await settle();
    expect(server.rows['101']!['conferido'], isTrue);
    expect(server.bodies['POST 101'], contains('2026-03-01T10:00:00'));
    expect(repo.syncStatus.pending, 0);
  });

  test('repeated offline Conferência is reported as repeated', () async {
    server.down = true;
    network.set(false);
    await repo.markChecked('100');
    expect((await repo.markChecked('100')).repeated, isTrue);
  });

  test('unknown Patrimônio offline is not found', () async {
    server.down = true;
    network.set(false);
    expect(repo.markChecked('999'), throwsA(isA<PatrimonyNotFoundException>()));
  });

  test('offline edit is queued with client time and applied locally', () async {
    server.down = true;
    network.set(false);
    final entry = await repo.updateEntry('100', {'sala': 'Sala Z'});
    expect(entry.room, 'Sala Z');
    expect((await repo.fetchInventory(room: 'Sala Z')).total, 1);
    now = now.add(const Duration(minutes: 5));
    server.down = false;
    network.set(true);
    await settle();
    expect(server.rows['100']!['sala'], 'Sala Z');
    expect(server.editedAt['100'], DateTime.utc(2026, 3, 1, 10));
  });

  test('offline edit remains queued if updating the cache fails', () async {
    server.down = true;
    network.set(false);
    faultStore.failNextEntryWrite = true;

    await expectLater(
      repo.updateEntry('100', {'sala': 'Sala Z'}),
      throwsA(isA<StateError>()),
    );

    final pending = await store.pendingOperations();
    expect(pending.single.type, 'update');
    expect(pending.single.payload['sala'], 'Sala Z');
  });

  test('last-write-wins: stale offline edit loses and cache takes server state',
      () async {
    server.down = true;
    network.set(false);
    await repo.updateEntry('100', {'sala': 'Offline'});
    // Outro usuário edita depois, direto no servidor.
    server.rows['100']!['sala'] = 'Outro usuário';
    server.editedAt['100'] = DateTime.utc(2026, 3, 1, 11);
    server.down = false;
    network.set(true);
    final status = await repo.synchronize();
    expect(status.pending, 0);
    expect(status.conflicts, 1);
    expect((await repo.fetchEntry('100'))!.room, 'Outro usuário');
  });

  test('last-write-wins: newer offline edit wins over older server edit',
      () async {
    server.editedAt['100'] = DateTime.utc(2026, 3, 1, 9);
    server.rows['100']!['sala'] = 'Antiga';
    server.down = true;
    network.set(false);
    await repo.updateEntry('100', {'sala': 'Nova'});
    server.down = false;
    network.set(true);
    final status = await repo.synchronize();
    expect(status.conflicts, 0);
    expect(server.rows['100']!['sala'], 'Nova');
  });

  test('sync receives changes made by other users but keeps local pending',
      () async {
    server.rows['101']!['descricao'] = 'Mesa nova';
    server.rows['102']!['descricao'] = 'Servidor 102';
    server.rows.remove('100');
    server.down = true;
    network.set(false);
    await repo.updateEntry('102', {'descricao': 'Local 102'});
    server.down = false;
    server.sessionValid = false;
    network.set(true);
    await repo.synchronize(); // 401: nada sincroniza, tudo preservado
    expect((await repo.fetchEntry('102'))!.description, 'Local 102');
    server.sessionValid = true;
    await repo.synchronize();
    expect((await repo.fetchEntry('101'))!.description, 'Mesa nova');
    expect(await repo.fetchEntry('100'), isNull);
    expect(server.rows['102']!['descricao'], 'Local 102');
  });

  group('sessão e falhas nunca descartam pendências', () {
    test('expired session while offline: queue survives logout and login',
        () async {
      server.down = true;
      network.set(false);
      await repo.markChecked('100');
      await repo.updateEntry('101', {'sala': 'Sala Q'});

      server.down = false;
      server.sessionValid = false;
      network.set(true);
      await settle();
      expect(repo.syncStatus.sessionExpired, isTrue);
      expect(repo.syncStatus.pending, 2);
      expect(await repo.restoreSession(), isNull);

      await repo.logout();
      await reload();
      expect(repo.syncStatus.pending, 2);
      expect(await repo.restoreSession(), isNull);

      await repo.login('admin', 'x');
      await settle();
      expect(repo.syncStatus.pending, 0);
      expect(repo.syncStatus.sessionExpired, isFalse);
      expect(server.rows['100']!['conferido'], isTrue);
      expect(server.rows['101']!['sala'], 'Sala Q');
    });

    test('logout offline revokes offline access but keeps the queue', () async {
      server.down = true;
      network.set(false);
      await repo.markChecked('100');
      await repo.logout();
      await reload();
      expect(await repo.restoreSession(), isNull);
      expect(repo.syncStatus.pending, 1);
    });

    test('server errors keep items queued for retry', () async {
      server.failWith = 503;
      await repo.markChecked('100');
      expect(repo.syncStatus.pending, 1);
      final status = await repo.synchronize();
      expect(status.pending, 1);
      expect(status.failed, 0);
      server.failWith = null;
      expect((await repo.synchronize()).pending, 0);
    });

    test('rejected items are kept, flagged and do not block the others',
        () async {
      server.down = true;
      network.set(false);
      await repo.createEntry(const NewInventoryEntry(
          number: '777',
          description: 'Novo',
          room: 'S',
          responsible: 'R',
          status: 'Ativo'));
      await repo.markChecked('100');
      server.rows['777'] = {...server.rows['100']!, 'numero_patrimonio': '777'};
      server.down = false;
      network.set(true);
      final status = await repo.synchronize();
      expect(server.rows['100']!['conferido'], isTrue);
      expect(status.failed, 1);
      expect(status.pending, 1);
    });

    test('no credential material is persisted in the store', () async {
      await repo.markChecked('100');
      for (final key in ['jwt', 'token', 'csrf', 'password', 'senha']) {
        for (final box in Hive.isBoxOpen('offline_meta')
            ? Hive.box<String>('offline_meta').keys
            : const []) {
          expect('$box'.toLowerCase(), isNot(contains(key)));
        }
      }
      for (final name in ['offline_meta', 'offline_queue', 'offline_entries']) {
        for (final value in Hive.box<String>(name).values) {
          expect(value.toLowerCase(), isNot(contains('csrf')));
          expect(value.toLowerCase(), isNot(contains('jwt')));
        }
      }
    });
  });

  group('fotos offline', () {
    test('upload offline is stored as bytes, survives reload and syncs',
        () async {
      server.down = true;
      network.set(false);
      final photo = await repo.uploadPhoto('100', _jpeg(2000));
      expect(photo.id, lessThan(0));
      await reload();
      final photos = await repo.fetchPhotos('100');
      expect(photos.single.id, photo.id);
      expect(await repo.fetchPhotoBytes('100', photo.id), _jpeg(2000));

      server.down = false;
      network.set(true);
      await settle();
      expect(repo.syncStatus.pending, 0);
      expect(server.photos['100']!.length, 1);
      final synced = await repo.fetchPhotos('100');
      expect(synced.single.id, greaterThan(0));
      expect(await repo.fetchPhotoBytes('100', synced.single.id), _jpeg(2000));
    });

    test('photos viewed online are available offline after reload', () async {
      final uploaded = await repo.uploadPhoto('101', _jpeg(500));
      await reload();
      server.down = true;
      network.set(false);
      expect((await repo.fetchPhotos('101')).single.id, uploaded.id);
      expect(await repo.fetchPhotoBytes('101', uploaded.id), _jpeg(500));
    });

    test('fetching a server photo caches it for offline use', () async {
      server.photos['102'] = {50: _jpeg(300)};
      expect((await repo.fetchPhotos('102')).single.id, 50);
      expect(await repo.fetchPhotoBytes('102', 50), _jpeg(300));
      server.down = true;
      network.set(false);
      expect(await repo.fetchPhotoBytes('102', 50), _jpeg(300));
      expect((await repo.fetchPhotos('102')).single.id, 50);
    });

    test('offline limit of 3 photos per Patrimônio is enforced', () async {
      server.down = true;
      network.set(false);
      for (var i = 0; i < 3; i++) {
        await repo.uploadPhoto('100', _jpeg(100));
      }
      expect(repo.uploadPhoto('100', _jpeg(100)), throwsException);
    });

    test('deleting a pending photo cancels its upload', () async {
      server.down = true;
      network.set(false);
      final photo = await repo.uploadPhoto('100', _jpeg(100));
      await repo.deletePhoto('100', photo.id);
      expect(repo.syncStatus.pending, 0);
      expect(await repo.fetchPhotos('100'), isEmpty);
    });

    test('deleting a synced photo offline queues the deletion', () async {
      final photo = await repo.uploadPhoto('100', _jpeg(100));
      server.down = true;
      network.set(false);
      await repo.deletePhoto('100', photo.id);
      expect(await repo.fetchPhotos('100'), isEmpty);
      expect(repo.syncStatus.pending, 1);
      server.down = false;
      network.set(true);
      await repo.synchronize();
      expect(server.photos['100'], isEmpty);
      expect(repo.syncStatus.pending, 0);
    });

    test('storage quota: offline photo that does not fit is refused cleanly',
        () async {
      await reload(budget: 700 * 1024);
      server.down = true;
      network.set(false);
      await repo.uploadPhoto('100', _jpeg(300 * 1024));
      await repo.uploadPhoto('100', _jpeg(300 * 1024));
      await expectLater(repo.uploadPhoto('100', _jpeg(300 * 1024)),
          throwsA(isA<StorageQuotaExceededException>()));
      expect(repo.syncStatus.pending, 2);
      expect((await repo.fetchPhotos('100')).length, 2);
    });
  });

  group('indicador de conexão e pendências', () {
    test('status stream reports connectivity and pending count', () async {
      final seen = <SyncStatus>[];
      final sub = repo.syncStatusChanges.listen(seen.add);
      server.down = true;
      network.set(false);
      await repo.markChecked('100');
      await settle();
      await sub.cancel();
      expect(seen.any((s) => !s.online), isTrue);
      expect(seen.last.pending, 1);
      expect(repo.syncStatus.online, isFalse);
    });

    test('manual sync while offline reports offline and keeps queue', () async {
      server.down = true;
      network.set(false);
      await repo.markChecked('100');
      final status = await repo.synchronize();
      expect(status.online, isFalse);
      expect(status.pending, 1);
    });
  });

  test('online mutations go straight to the server with the client time',
      () async {
    await repo.markChecked('102');
    expect(server.rows['102']!['conferido'], isTrue);
    expect(repo.syncStatus.pending, 0);
    final entry = await repo.updateEntry('100', {'sala': 'Direta'});
    expect(entry.room, 'Direta');
    expect(server.editedAt['100'], DateTime.utc(2026, 3, 1, 10));
  });
}

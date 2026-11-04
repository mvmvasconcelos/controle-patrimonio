import 'dart:io';
import 'dart:typed_data';

import 'package:controle_patrimonio/services/offline/offline_store.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Uint8List _bytes(int length, [int fill = 7]) =>
    Uint8List.fromList(List.filled(length, fill));

const _kb = 1024;

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('offline_store');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('entries, photos, queue and meta survive closing and reopening',
      () async {
    var store = await HiveOfflineStore.open();
    await store.putEntries([
      const InventoryEntry(
          number: '1',
          description: 'Mesa',
          room: 'A',
          responsible: 'Ana',
          status: 'Ativo',
          checked: true),
    ]);
    await store.putPhoto('1', 5, _bytes(10), pending: false);
    final op = await store.enqueue(PendingOperation(
        type: 'check', number: '1', editedAt: DateTime.utc(2026, 1, 1)));
    await store.writeMeta('k', 'v');
    await store.close();

    store = await HiveOfflineStore.open();
    expect((await store.entry('1'))!.checked, isTrue);
    expect(await store.photoBytes('1', 5), _bytes(10));
    final ops = await store.pendingOperations();
    expect(ops.single.id, op.id);
    expect(ops.single.editedAt, DateTime.utc(2026, 1, 1));
    expect(await store.readMeta('k'), 'v');
  });

  test('queue keeps FIFO order and temporary photo ids are unique negatives',
      () async {
    final store = await HiveOfflineStore.open();
    for (final n in ['a', 'b', 'c']) {
      await store.enqueue(PendingOperation(
          type: 'check', number: n, editedAt: DateTime.utc(2026)));
    }
    expect((await store.pendingOperations()).map((o) => o.number),
        ['a', 'b', 'c']);
    final first = await store.nextTemporaryPhotoId();
    final second = await store.nextTemporaryPhotoId();
    expect(first, lessThan(0));
    expect(second, isNot(first));
  });

  group('photo budget (realistic ~300 KB photos, 3 per Patrimônio)', () {
    test('evicts least recently used cached photos before refusing', () async {
      final store = await HiveOfflineStore.open(photoBudgetBytes: 1000 * _kb);
      for (var i = 1; i <= 3; i++) {
        expect(await store.putPhoto('1', i, _bytes(300 * _kb), pending: false),
            isTrue);
      }
      await store.photoBytes('1', 1); // photo 1 becomes most recently used
      expect(await store.putPhoto('1', 4, _bytes(300 * _kb), pending: false),
          isTrue);
      expect(await store.photoBytes('1', 2), isNull);
      expect(await store.photoBytes('1', 1), isNotNull);
      expect(await store.photoBytesUsed(), lessThanOrEqualTo(1000 * _kb));
    });

    test('never evicts pending photos and refuses new pending ones when full',
        () async {
      final store = await HiveOfflineStore.open(photoBudgetBytes: 700 * _kb);
      await store.putPhoto('1', -1, _bytes(300 * _kb), pending: true);
      await store.putPhoto('1', -2, _bytes(300 * _kb), pending: true);
      expect(await store.putPhoto('2', 9, _bytes(300 * _kb), pending: false),
          isFalse);
      await expectLater(
        store.putPhoto('1', -3, _bytes(300 * _kb), pending: true),
        throwsA(isA<StorageQuotaExceededException>()),
      );
      expect(await store.photoBytes('1', -1), isNotNull);
      expect(await store.photoBytes('1', -2), isNotNull);
      expect(await store.photoBytes('1', -3), isNull);
    });

    test('pending upload evicts synced cache to make room', () async {
      final store = await HiveOfflineStore.open(photoBudgetBytes: 700 * _kb);
      await store.putPhoto('1', 1, _bytes(300 * _kb), pending: false);
      await store.putPhoto('1', 2, _bytes(300 * _kb), pending: false);
      await store.putPhoto('1', -1, _bytes(300 * _kb), pending: true);
      expect(await store.photoBytes('1', -1), isNotNull);
      expect(await store.photoBytesUsed(), lessThanOrEqualTo(700 * _kb));
    });

    test('promotePhoto turns a pending photo into an evictable cached one',
        () async {
      final store = await HiveOfflineStore.open();
      await store.putPhoto('1', -1, _bytes(10), pending: true);
      await store.promotePhoto('1', -1, 42);
      expect(await store.photoBytes('1', -1), isNull);
      expect(await store.photoBytes('1', 42), _bytes(10));
      final photo = (await store.photos('1')).single;
      expect([photo.id, photo.pending], [42, false]);
    });
  });

  test('recognises browser quota errors', () {
    expect(
        HiveOfflineStore.isQuotaError(
            Exception('QuotaExceededError: The quota has been exceeded.')),
        isTrue);
    expect(
        HiveOfflineStore.isQuotaError(
            Exception('DOMException: NS_ERROR_DOM_QUOTA_REACHED')),
        isTrue);
    expect(HiveOfflineStore.isQuotaError(StateError('other')), isFalse);
  });
}

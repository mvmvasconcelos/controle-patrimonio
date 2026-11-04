import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';

import '../web_inventory_repository.dart';

/// Orçamento do cache de fotos, independente do limite do navegador (que varia
/// por navegador e por disco livre): o teto é nosso e conservador.
const defaultPhotoBudgetBytes = 100 * 1024 * 1024;

class StorageQuotaExceededException implements Exception {
  const StorageQuotaExceededException();

  @override
  String toString() =>
      'Armazenamento do navegador cheio. Sincronize as pendências ou libere '
      'espaço antes de adicionar novas fotos offline.';
}

class PendingOperation {
  PendingOperation({
    this.id,
    required this.type,
    required this.number,
    required this.editedAt,
    this.payload = const {},
    this.error,
    this.attempts = 0,
  });

  /// Tipos: `update`, `create`, `check`, `upload_photo`, `delete_photo`.
  final int? id;
  final String type;
  final String number;
  final DateTime editedAt;
  final Map<String, dynamic> payload;
  final String? error;
  final int attempts;

  PendingOperation copyWith({int? id, String? error, int? attempts}) =>
      PendingOperation(
        id: id ?? this.id,
        type: type,
        number: number,
        editedAt: editedAt,
        payload: payload,
        error: error,
        attempts: attempts ?? this.attempts,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'number': number,
        'edited_at': editedAt.toUtc().toIso8601String(),
        'payload': payload,
        'error': error,
        'attempts': attempts,
      };

  factory PendingOperation.fromJson(int id, Map<String, dynamic> json) =>
      PendingOperation(
        id: id,
        type: json['type'] as String,
        number: json['number'] as String,
        editedAt: DateTime.parse(json['edited_at'] as String),
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        error: json['error'] as String?,
        attempts: json['attempts'] as int? ?? 0,
      );
}

class CachedPhoto {
  const CachedPhoto({
    required this.number,
    required this.id,
    required this.pending,
    required this.size,
  });

  final String number;
  final int id;
  final bool pending;
  final int size;
}

abstract class OfflineStore {
  Future<List<InventoryEntry>> entries();
  Future<InventoryEntry?> entry(String number);
  Future<void> putEntries(Iterable<InventoryEntry> entries);
  Future<void> removeEntries(Iterable<String> numbers);

  Future<List<CachedPhoto>> photos(String number);
  Future<Uint8List?> photoBytes(String number, int id);

  /// Fotos pendentes nunca são descartadas: se não couberem, lança
  /// [StorageQuotaExceededException]. Fotos apenas em cache podem ser
  /// removidas (menos usadas primeiro) e, se não couberem, retorna `false`.
  Future<bool> putPhoto(String number, int id, Uint8List bytes,
      {required bool pending});
  Future<void> removePhoto(String number, int id);
  Future<void> promotePhoto(String number, int temporaryId, int realId);
  Future<int> photoBytesUsed();
  Future<int> nextTemporaryPhotoId();

  Future<List<PendingOperation>> pendingOperations();
  Future<PendingOperation> enqueue(PendingOperation operation);
  Future<void> updateOperation(PendingOperation operation);
  Future<void> removeOperation(int id);

  Future<String?> readMeta(String key);
  Future<void> writeMeta(String key, String value);
  Future<void> deleteMeta(String key);

  Future<void> close();
}

/// Cache persistente em Hive (IndexedDB no navegador). Nunca guarda JWT: a
/// sessão vive apenas no cookie HttpOnly.
class HiveOfflineStore implements OfflineStore {
  HiveOfflineStore._(this._entries, this._photos, this._index, this._queue,
      this._meta, this.photoBudgetBytes, this._tick);

  final Box<String> _entries;
  final Box<Uint8List> _photos;
  final Box<String> _index;
  final Box<String> _queue;
  final Box<String> _meta;
  final int photoBudgetBytes;
  int _tick;

  static Future<HiveOfflineStore> open({
    int photoBudgetBytes = defaultPhotoBudgetBytes,
  }) async {
    final entries = await Hive.openBox<String>('offline_entries');
    final photos = await Hive.openBox<Uint8List>('offline_photos');
    final index = await Hive.openBox<String>('offline_photo_index');
    final queue = await Hive.openBox<String>('offline_queue');
    final meta = await Hive.openBox<String>('offline_meta');
    var tick = 0;
    for (final raw in index.values) {
      final used = (jsonDecode(raw) as Map)['used'] as int? ?? 0;
      if (used > tick) tick = used;
    }
    return HiveOfflineStore._(
        entries, photos, index, queue, meta, photoBudgetBytes, tick);
  }

  static bool isQuotaError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('quota');
  }

  String _key(String number, int id) => '$number|$id';

  Map<String, dynamic> _indexJson(String key) =>
      Map<String, dynamic>.from(jsonDecode(_index.get(key)!) as Map);

  @override
  Future<List<InventoryEntry>> entries() async => _entries.values
      .map((raw) =>
          InventoryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>))
      .toList();

  @override
  Future<InventoryEntry?> entry(String number) async {
    final raw = _entries.get(number);
    return raw == null
        ? null
        : InventoryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> putEntries(Iterable<InventoryEntry> entries) => _entries.putAll({
        for (final e in entries) e.number: jsonEncode(e.toJson()),
      });

  @override
  Future<void> removeEntries(Iterable<String> numbers) =>
      _entries.deleteAll(numbers);

  @override
  Future<List<CachedPhoto>> photos(String number) async {
    final prefix = '$number|';
    return [
      for (final key in _index.keys.cast<String>())
        if (key.startsWith(prefix)) _cachedPhoto(key),
    ]..sort((a, b) => a.id.compareTo(b.id));
  }

  CachedPhoto _cachedPhoto(String key) {
    final json = _indexJson(key);
    final separator = key.lastIndexOf('|');
    return CachedPhoto(
      number: key.substring(0, separator),
      id: int.parse(key.substring(separator + 1)),
      pending: json['pending'] as bool,
      size: json['size'] as int,
    );
  }

  @override
  Future<Uint8List?> photoBytes(String number, int id) async {
    final key = _key(number, id);
    final bytes = _photos.get(key);
    if (bytes != null && _index.containsKey(key)) {
      final json = _indexJson(key)..['used'] = ++_tick;
      await _index.put(key, jsonEncode(json));
    }
    return bytes;
  }

  @override
  Future<int> photoBytesUsed() async {
    var total = 0;
    for (final key in _index.keys.cast<String>()) {
      total += _indexJson(key)['size'] as int;
    }
    return total;
  }

  @override
  Future<bool> putPhoto(String number, int id, Uint8List bytes,
      {required bool pending}) async {
    final key = _key(number, id);
    if (_index.containsKey(key)) await _dropPhoto(key);
    if (!await _makeRoom(bytes.length)) {
      if (pending) throw const StorageQuotaExceededException();
      return false;
    }
    try {
      await _photos.put(key, bytes);
      await _index.put(
        key,
        jsonEncode({'pending': pending, 'size': bytes.length, 'used': ++_tick}),
      );
    } catch (error) {
      await _dropPhoto(key);
      if (!isQuotaError(error)) rethrow;
      if (pending) throw const StorageQuotaExceededException();
      return false;
    }
    return true;
  }

  Future<bool> _makeRoom(int size) async {
    var used = await photoBytesUsed();
    if (used + size <= photoBudgetBytes) return true;
    final evictable = [
      for (final key in _index.keys.cast<String>())
        if (!(_indexJson(key)['pending'] as bool)) key,
    ]..sort((a, b) =>
        (_indexJson(a)['used'] as int).compareTo(_indexJson(b)['used'] as int));
    for (final key in evictable) {
      if (used + size <= photoBudgetBytes) break;
      used -= _indexJson(key)['size'] as int;
      await _dropPhoto(key);
    }
    return used + size <= photoBudgetBytes;
  }

  Future<void> _dropPhoto(String key) async {
    await _photos.delete(key);
    await _index.delete(key);
  }

  @override
  Future<void> removePhoto(String number, int id) =>
      _dropPhoto(_key(number, id));

  @override
  Future<void> promotePhoto(String number, int temporaryId, int realId) async {
    final from = _key(number, temporaryId);
    final bytes = _photos.get(from);
    if (bytes == null) return;
    final json = _indexJson(from)
      ..['pending'] = false
      ..['used'] = ++_tick;
    await _photos.put(_key(number, realId), bytes);
    await _index.put(_key(number, realId), jsonEncode(json));
    await _dropPhoto(from);
  }

  @override
  Future<int> nextTemporaryPhotoId() async {
    final next = (int.tryParse(_meta.get('photo_temp_counter') ?? '') ?? 0) + 1;
    await _meta.put('photo_temp_counter', '$next');
    return -next;
  }

  @override
  Future<List<PendingOperation>> pendingOperations() async {
    final keys = _queue.keys.cast<int>().toList()..sort();
    return [
      for (final key in keys)
        PendingOperation.fromJson(
            key, jsonDecode(_queue.get(key)!) as Map<String, dynamic>),
    ];
  }

  @override
  Future<PendingOperation> enqueue(PendingOperation operation) async {
    final id = await _queue.add(jsonEncode(operation.toJson()));
    return operation.copyWith(id: id);
  }

  @override
  Future<void> updateOperation(PendingOperation operation) =>
      _queue.put(operation.id!, jsonEncode(operation.toJson()));

  @override
  Future<void> removeOperation(int id) => _queue.delete(id);

  @override
  Future<String?> readMeta(String key) async => _meta.get(key);

  @override
  Future<void> writeMeta(String key, String value) => _meta.put(key, value);

  @override
  Future<void> deleteMeta(String key) => _meta.delete(key);

  @override
  Future<void> close() async {
    await _entries.close();
    await _photos.close();
    await _index.close();
    await _queue.close();
    await _meta.close();
  }
}

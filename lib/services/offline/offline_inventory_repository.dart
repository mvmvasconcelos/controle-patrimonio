import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../web_inventory_repository.dart';
import 'connectivity_monitor.dart';
import 'offline_store.dart';
import 'sync_status.dart';

const _pageSize = 200;
const _userKey = 'offline_user';
const _roleKey = 'offline_role';
const _lastSyncKey = 'last_sync_at';

/// Repositório offline-first: mesma interface do [WebInventoryRepository],
/// com cache local, fila de pendências e Sincronização.
///
/// Escritas vão direto ao servidor quando há rede e sessão verificada; se a
/// rede, o servidor ou a sessão falharem, a operação é aplicada ao cache e
/// enfileirada com o horário do cliente. A fila só é esvaziada por sucesso (ou
/// cancelamento explícito do usuário): falhas de rede, autenticação ou
/// servidor nunca descartam itens.
class OfflineInventoryRepository implements WebInventoryRepository {
  OfflineInventoryRepository._({
    required this.remote,
    required this.store,
    required this.connectivity,
    required DateTime Function() clock,
    Duration? retryInterval,
  }) : _clock = clock {
    _connectivitySub = connectivity.changes.listen(_onConnectivity);
    if (retryInterval != null) {
      _timer = Timer.periodic(retryInterval, (_) {
        if (_status.pending > 0 || !_reachable) unawaited(synchronize());
      });
    }
  }

  static Future<OfflineInventoryRepository> create({
    required WebInventoryRepository remote,
    required OfflineStore store,
    ConnectivityMonitor? connectivity,
    DateTime Function()? clock,
    Duration? retryInterval = const Duration(seconds: 60),
  }) async {
    final repository = OfflineInventoryRepository._(
      remote: remote,
      store: store,
      connectivity: connectivity ?? PlatformConnectivityMonitor(),
      clock: clock ?? DateTime.now,
      retryInterval: retryInterval,
    );
    final lastSync = await store.readMeta(_lastSyncKey);
    await repository._publish(
      lastSyncAt: lastSync == null ? null : DateTime.tryParse(lastSync),
    );
    return repository;
  }

  final WebInventoryRepository remote;
  final OfflineStore store;
  final ConnectivityMonitor connectivity;
  final DateTime Function() _clock;

  final _controller = StreamController<SyncStatus>.broadcast();
  late final StreamSubscription<bool> _connectivitySub;
  Timer? _timer;
  SyncStatus _status = const SyncStatus();
  Future<SyncStatus>? _running;
  bool _reachable = true;
  bool _sessionVerified = false;
  bool _disposed = false;

  @override
  SyncStatus get syncStatus => _status;

  @override
  Stream<SyncStatus> get syncStatusChanges => _controller.stream;

  bool get _online => connectivity.isOnline && _reachable;

  DateTime _now() => _clock().toUtc();

  Future<void> _publish({
    bool? syncing,
    bool? sessionExpired,
    int? conflicts,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearError = false,
  }) async {
    final ops = await store.pendingOperations();
    _status = _status.copyWith(
      online: _online,
      syncing: syncing,
      pending: ops.length,
      failed: ops.where((o) => o.error != null).length,
      conflicts: conflicts,
      sessionExpired: sessionExpired,
      lastSyncAt: lastSyncAt,
      lastError: lastError,
      clearError: clearError,
    );
    if (!_controller.isClosed) _controller.add(_status);
  }

  void _onConnectivity(bool online) {
    if (online) _reachable = true;
    unawaited(_publishThenSync(online));
  }

  Future<void> _publishThenSync(bool shouldSync) async {
    await _publish();
    if (shouldSync && !_disposed) await synchronize();
  }

  void _setReachable(bool reachable) {
    if (_reachable == reachable) return;
    _reachable = reachable;
    unawaited(_publishThenSync(reachable));
  }

  static bool _isUnavailable(Object error) =>
      error is http.ClientException ||
      error is TimeoutException ||
      (error is ApiException && error.statusCode >= 500);

  // ---- Sessão ----------------------------------------------------------

  @override
  Future<AdminSession?> restoreSession() async {
    if (connectivity.isOnline) {
      try {
        final session = await remote.restoreSession();
        _reachable = true;
        if (session == null) {
          _sessionVerified = false;
          await _publish(sessionExpired: true);
          return null;
        }
        await _rememberUser(session);
        return session;
      } catch (error) {
        if (!_isUnavailable(error)) rethrow;
        _reachable = false;
      }
    } else {
      _reachable = false;
    }
    _sessionVerified = false;
    await _publish();
    final username = await store.readMeta(_userKey);
    if (username == null) return null;
    // CSRF só existe com o servidor; a sincronização o renova ao reconectar.
    return AdminSession(
      username: username,
      role: await store.readMeta(_roleKey) ?? 'admin',
      csrfToken: '',
    );
  }

  @override
  Future<AdminSession> login(String username, String password) async {
    final session = await remote.login(username, password);
    _reachable = true;
    await _rememberUser(session);
    return session;
  }

  Future<void> _rememberUser(AdminSession session) async {
    await store.writeMeta(_userKey, session.username);
    await store.writeMeta(_roleKey, session.role);
    _sessionVerified = true;
    await _publish(sessionExpired: false);
    unawaited(synchronize());
  }

  @override
  Future<void> logout() async {
    try {
      await remote.logout();
    } catch (_) {
      // Sem rede ou sessão já expirada: o logout local basta.
    }
    await store.deleteMeta(_userKey);
    await store.deleteMeta(_roleKey);
    _sessionVerified = false;
    await _publish();
  }

  // ---- Leituras --------------------------------------------------------

  Future<T> _read<T>(
      Future<T> Function() fromServer, Future<T> Function() fromCache) async {
    if (_online) {
      try {
        final result = await fromServer();
        _setReachable(true);
        return result;
      } on SessionExpiredException {
        _sessionVerified = false;
        await _publish(sessionExpired: true);
        rethrow;
      } catch (error) {
        if (!_isUnavailable(error)) rethrow;
        _setReachable(false);
      }
    }
    return fromCache();
  }

  Future<Set<String>> _pendingNumbers() async =>
      (await store.pendingOperations()).map((o) => o.number).toSet();

  @override
  Future<LocalDataStats> localDataStats() async => LocalDataStats(
        total: (await store.entries()).length,
        modified: (await _pendingNumbers()).length,
      );

  /// Descarta a fila de alterações locais e baixa de novo o estado do
  /// servidor para os Patrimônios afetados.
  @override
  Future<void> resetLocalChanges() async {
    final ops = await store.pendingOperations();
    if (ops.isEmpty) return;
    if (!connectivity.isOnline) {
      throw StateError(
        'Não é possível resetar modificações sem conexão com o servidor.',
      );
    }
    final numbers = ops.map((o) => o.number).toSet();
    final restored = <String, InventoryEntry>{};
    for (final number in numbers) {
      final entry = await remote.fetchEntry(number);
      if (entry != null) restored[number] = entry;
    }
    await store.putEntries(restored.values);
    for (final op in ops) {
      await store.removeOperation(op.id!);
    }
    for (final number in numbers) {
      for (final photo in await store.photos(number)) {
        if (photo.pending) await store.removePhoto(number, photo.id);
      }
    }
    await store.removeEntries(numbers.difference(restored.keys.toSet()));
    await _publish();
    await synchronize();
  }

  /// Apaga Patrimônios, fotos e fila guardados no dispositivo; o servidor
  /// não é alterado.
  @override
  Future<void> clearLocalData() async {
    final ops = await store.pendingOperations();
    for (final op in ops) {
      await store.removeOperation(op.id!);
    }
    final numbers = {
      ...(await store.entries()).map((e) => e.number),
      ...ops.map((o) => o.number),
    };
    for (final number in numbers) {
      for (final photo in await store.photos(number)) {
        await store.removePhoto(number, photo.id);
      }
    }
    await store.removeEntries(numbers);
    await _publish();
  }

  @override
  Future<List<InventoryEntry>> loadInventory() => _read(
        remote.loadInventory,
        () async => _sorted(await store.entries()),
      );

  List<InventoryEntry> _sorted(List<InventoryEntry> entries) =>
      entries..sort((a, b) => a.number.compareTo(b.number));

  @override
  Future<InventoryPage> fetchInventory({
    String? query,
    String? room,
    String? status,
    bool? checked,
    int offset = 0,
    int limit = 50,
  }) =>
      _read(() async {
        final page = await remote.fetchInventory(
          query: query,
          room: room,
          status: status,
          checked: checked,
          offset: offset,
          limit: limit,
        );
        final pending = await _pendingNumbers();
        final items = <InventoryEntry>[];
        for (final item in page.items) {
          items.add(pending.contains(item.number)
              ? await store.entry(item.number) ?? item
              : item);
        }
        await store
            .putEntries(page.items.where((e) => !pending.contains(e.number)));
        return InventoryPage(total: page.total, items: items);
      }, () async {
        final needle = query?.trim().toLowerCase() ?? '';
        final matches = _sorted((await store.entries()).where((e) {
          if (needle.isNotEmpty &&
              !e.number.toLowerCase().contains(needle) &&
              !e.description.toLowerCase().contains(needle)) {
            return false;
          }
          if (room != null && room.isNotEmpty && e.room != room) return false;
          if (status != null && status.isNotEmpty && e.status != status) {
            return false;
          }
          return checked == null || e.checked == checked;
        }).toList());
        return InventoryPage(
          total: matches.length,
          items: matches.skip(offset).take(limit).toList(),
        );
      });

  @override
  Future<InventoryFilters> fetchFilters() =>
      _read(remote.fetchFilters, () async {
        final entries = await store.entries();
        return InventoryFilters(
          rooms: (entries.map((e) => e.room).toSet().toList()..sort()),
          statuses: (entries.map((e) => e.status).toSet().toList()..sort()),
        );
      });

  @override
  Future<ConferenceReport> fetchConferenceReport({
    String? room,
    String? situation,
  }) async {
    Future<ConferenceReport> local() async {
      final entries = (await store.entries()).where((e) =>
          (room == null || room.isEmpty || e.room == room) &&
          (situation == null || situation.isEmpty || e.status == situation));
      final groups = <(String, String), List<InventoryEntry>>{};
      for (final e in entries) {
        groups.putIfAbsent((e.room, e.status), () => []).add(e);
      }
      final keys = groups.keys.toList()
        ..sort((a, b) {
          final byRoom = a.$1.compareTo(b.$1);
          return byRoom != 0 ? byRoom : a.$2.compareTo(b.$2);
        });
      final reportGroups = [
        for (final key in keys)
          ConferenceReportGroup(
            room: key.$1,
            situation: key.$2,
            total: groups[key]!.length,
            checked: groups[key]!.where((e) => e.checked).length,
            pending: groups[key]!.where((e) => !e.checked).length,
          ),
      ];
      final total = reportGroups.fold<int>(0, (s, g) => s + g.total);
      final checkedCount = reportGroups.fold<int>(0, (s, g) => s + g.checked);
      return ConferenceReport(
        total: total,
        checked: checkedCount,
        pending: total - checkedCount,
        groups: reportGroups,
      );
    }

    // Com pendências locais o relatório do servidor estaria defasado.
    if (_status.pending > 0 && (await store.entries()).isNotEmpty) {
      return local();
    }
    return _read(
        () => remote.fetchConferenceReport(room: room, situation: situation),
        local);
  }

  @override
  Future<InventoryEntry?> fetchEntry(String number) async {
    final key = number.trim();
    if ((await _pendingNumbers()).contains(key)) return store.entry(key);
    return _read(() async {
      final entry = await remote.fetchEntry(key);
      if (entry == null) {
        await store.removeEntries([key]);
      } else {
        await store.putEntries([entry]);
      }
      return entry;
    }, () => store.entry(key));
  }

  // ---- Escritas --------------------------------------------------------

  Future<bool> _canGoDirect(String number) async =>
      _online &&
      _sessionVerified &&
      !(await _pendingNumbers()).contains(number);

  static const _writeTimeout = Duration(seconds: 20);

  /// Tenta o servidor; rede/servidor/sessão indisponíveis caem na fila.
  Future<T> _write<T>(
    String number,
    Future<T> Function() direct,
    Future<T> Function() queued,
  ) async {
    if (await _canGoDirect(number)) {
      try {
        // Sem timeout, uma requisição pendurada (rede caída sem erro) travaria
        // a UI em vez de cair na fila.
        final result = await direct().timeout(_writeTimeout);
        _setReachable(true);
        return result;
      } on SessionExpiredException {
        _sessionVerified = false;
        await _publish(sessionExpired: true);
      } catch (error) {
        if (!_isUnavailable(error)) rethrow;
        _setReachable(false);
      }
    }
    final result = await queued();
    await _publish();
    return result;
  }

  Future<InventoryEntry> _cachedOrThrow(String number) async =>
      await store.entry(number) ?? (throw PatrimonyNotFoundException(number));

  @override
  Future<InventoryEntry> updateEntry(
      String number, Map<String, String?> fields) {
    final key = number.trim();
    final editedAt = _now();
    return _write(key, () async {
      final entry = await remote.updateEntry(
          key, {...fields, 'editado_em': editedAt.toIso8601String()});
      await store.putEntries([entry]);
      return entry;
    }, () async {
      final local = _applyFields(await _cachedOrThrow(key), fields);
      await store.enqueue(PendingOperation(
        type: 'update',
        number: key,
        editedAt: editedAt,
        payload: Map<String, dynamic>.from(fields),
      ));
      try {
        await store.putEntries([local]);
      } catch (_) {
        await _publish();
        rethrow;
      }
      return local;
    });
  }

  InventoryEntry _applyFields(InventoryEntry entry, Map<String, String?> f) =>
      entry.copyWith(
        description: f['descricao'],
        room: f['sala'],
        responsible: f['responsavel'],
        status: f['situacao'],
        notes: f['observacoes'],
      );

  @override
  Future<InventoryEntry> createEntry(NewInventoryEntry entry) {
    final key = entry.number.trim();
    return _write(key, () async {
      final created = await remote.createEntry(entry);
      await store.putEntries([created]);
      return created;
    }, () async {
      if (await store.entry(key) != null) {
        throw ApiException(409, 'Patrimônio $key já existe no Inventário.');
      }
      final local = InventoryEntry(
        number: key,
        description: entry.description.trim(),
        room: entry.room.trim(),
        responsible: entry.responsible.trim(),
        status: entry.status.trim(),
        notes: entry.notes,
        checked: entry.checked,
      );
      await store.enqueue(PendingOperation(
        type: 'create',
        number: key,
        editedAt: _now(),
        payload: entry.toJson(),
      ));
      try {
        await store.putEntries([local]);
      } catch (_) {
        await _publish();
        rethrow;
      }
      return local;
    });
  }

  @override
  Future<ConferenciaResult> markChecked(String number) =>
      markCheckedAt(number, _now());

  @override
  Future<ConferenciaResult> markCheckedAt(String number, DateTime checkedAt) {
    final key = number.trim();
    return _write(key, () async {
      final result = await remote.markCheckedAt(key, checkedAt);
      final entry = await store.entry(key);
      if (entry != null) {
        await store.putEntries([entry.copyWith(checked: true)]);
      }
      return result;
    }, () async {
      final entry = await _cachedOrThrow(key);
      if (!entry.checked) {
        await store.enqueue(PendingOperation(
            type: 'check', number: key, editedAt: checkedAt.toUtc()));
        try {
          await store.putEntries([entry.copyWith(checked: true)]);
        } catch (_) {
          await _publish();
          rethrow;
        }
      }
      return ConferenciaResult(
        number: key,
        repeated: entry.checked,
        checkedAt: checkedAt,
      );
    });
  }

  // ---- Fotos -----------------------------------------------------------

  @override
  Future<List<PatrimonyPhoto>> fetchPhotos(String number) async {
    final key = number.trim();
    final ops = await store.pendingOperations();
    final deleted = {
      for (final o in ops)
        if (o.type == 'delete_photo' && o.number == key)
          o.payload['photo_id'] as int,
    };
    final photos = await _read(() async {
      final remotePhotos = await remote.fetchPhotos(key);
      final ids = remotePhotos.map((p) => p.id).toSet();
      for (final cached in await store.photos(key)) {
        if (!cached.pending && !ids.contains(cached.id)) {
          await store.removePhoto(key, cached.id);
        }
      }
      for (final photo in remotePhotos) {
        if (deleted.contains(photo.id) ||
            await store.photoBytes(key, photo.id) != null) {
          continue;
        }
        try {
          await store.putPhoto(
              key, photo.id, await remote.fetchPhotoBytes(key, photo.id),
              pending: false);
        } catch (_) {
          // Cache de fotos é oportunista; a lista continua válida.
        }
      }
      return remotePhotos.where((p) => !deleted.contains(p.id)).toList();
    },
        () async => [
              for (final p in await store.photos(key))
                if (!p.pending) PatrimonyPhoto(id: p.id, number: key),
            ]);
    return [
      ...photos,
      for (final p in await store.photos(key))
        if (p.pending) PatrimonyPhoto(id: p.id, number: key),
    ];
  }

  @override
  Future<Uint8List> fetchPhotoBytes(String number, int photoId) async {
    final key = number.trim();
    final cached = await store.photoBytes(key, photoId);
    if (cached != null) return cached;
    final bytes = await remote.fetchPhotoBytes(key, photoId);
    try {
      await store.putPhoto(key, photoId, bytes, pending: false);
    } catch (_) {
      // Sem espaço para cachear: ainda exibimos a foto.
    }
    return bytes;
  }

  @override
  Future<PatrimonyPhoto> uploadPhoto(String number, Uint8List bytes) {
    final key = number.trim();
    if (bytes.length > maxPhotoBytes) {
      throw Exception(
          'Foto maior que o limite de ${maxPhotoBytes ~/ (1024 * 1024)} MB');
    }
    return _write(key, () async {
      final photo = await remote.uploadPhoto(key, bytes);
      try {
        await store.putPhoto(key, photo.id, bytes, pending: false);
      } catch (_) {
        // Já está no servidor; cache é oportunista.
      }
      return photo;
    }, () async {
      if ((await store.photos(key)).length >= maxPhotosPerPatrimony) {
        throw const ApiException(409,
            'Limite de $maxPhotosPerPatrimony fotos por patrimônio atingido');
      }
      final id = await store.nextTemporaryPhotoId();
      await store.putPhoto(key, id, bytes, pending: true);
      try {
        await store.enqueue(PendingOperation(
          type: 'upload_photo',
          number: key,
          editedAt: _now(),
          payload: {'temp_id': id},
        ));
      } catch (_) {
        await store.removePhoto(key, id);
        rethrow;
      }
      return PatrimonyPhoto(id: id, number: key);
    });
  }

  @override
  Future<void> deletePhoto(String number, int photoId) async {
    final key = number.trim();
    if (photoId < 0) {
      for (final op in await store.pendingOperations()) {
        if (op.type == 'upload_photo' &&
            op.number == key &&
            op.payload['temp_id'] == photoId) {
          await store.removeOperation(op.id!);
        }
      }
      await store.removePhoto(key, photoId);
      await _publish();
      return;
    }
    await _write<void>(key, () async {
      try {
        await remote.deletePhoto(key, photoId);
      } on ApiException catch (error) {
        if (error.statusCode != 404) rethrow;
      }
      await store.removePhoto(key, photoId);
    }, () async {
      await store.enqueue(PendingOperation(
        type: 'delete_photo',
        number: key,
        editedAt: _now(),
        payload: {'photo_id': photoId},
      ));
      try {
        await store.removePhoto(key, photoId);
      } catch (_) {
        await _publish();
        rethrow;
      }
    });
  }

  // ---- Sincronização ---------------------------------------------------

  @override
  Future<SyncStatus> synchronize() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<SyncStatus> _sync() async {
    if (_disposed) return _status;
    if (!connectivity.isOnline) {
      await _publish(syncing: false);
      return _status;
    }
    await _publish(syncing: true, conflicts: 0);
    var conflicts = 0;
    try {
      final session = await remote.restoreSession();
      if (session == null) {
        _sessionVerified = false;
        await _publish(syncing: false, sessionExpired: true);
        return _status;
      }
      _reachable = true;
      _sessionVerified = true;
      conflicts = await _flushQueue();
      await _pullInventory();
      final syncedAt = _now();
      await store.writeMeta(_lastSyncKey, syncedAt.toIso8601String());
      await _publish(
        syncing: false,
        sessionExpired: false,
        conflicts: conflicts,
        lastSyncAt: syncedAt,
        clearError: true,
      );
    } on SessionExpiredException {
      _sessionVerified = false;
      await _publish(
          syncing: false, sessionExpired: true, conflicts: conflicts);
    } catch (error) {
      if (_isUnavailable(error)) _reachable = false;
      await _publish(
        syncing: false,
        conflicts: conflicts,
        lastError: error.toString().replaceFirst('Exception: ', ''),
      );
    }
    return _status;
  }

  /// Envia a fila em ordem. Retorna quantas edições perderam o last-write-wins.
  Future<int> _flushQueue() async {
    final ops = await store.pendingOperations();
    var conflicts = 0;
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final laterForSameNumber =
          ops.skip(i + 1).any((o) => o.number == op.number);
      try {
        if (await _apply(op, refreshCache: !laterForSameNumber)) conflicts++;
        await store.removeOperation(op.id!);
      } on SessionExpiredException {
        rethrow;
      } on PatrimonyNotFoundException catch (error) {
        await _flag(op, error.toString());
      } on ApiException catch (error) {
        if (error.statusCode >= 500 ||
            error.statusCode == 401 ||
            error.statusCode == 403) {
          rethrow;
        }
        await _flag(op, error.message);
      }
    }
    return conflicts;
  }

  Future<void> _flag(PendingOperation op, String message) => store
      .updateOperation(op.copyWith(error: message, attempts: op.attempts + 1));

  Future<bool> _apply(PendingOperation op, {required bool refreshCache}) async {
    switch (op.type) {
      case 'update':
        final entry = await remote.updateEntry(op.number, {
          for (final e in op.payload.entries) e.key: e.value as String?,
          'editado_em': op.editedAt.toIso8601String(),
        });
        if (refreshCache) await store.putEntries([entry]);
        return !entry.editApplied;
      case 'create':
        final p = op.payload;
        await remote.createEntry(NewInventoryEntry(
          number: p['numero_patrimonio'] as String,
          description: p['descricao'] as String,
          room: p['sala'] as String,
          responsible: p['responsavel'] as String,
          status: p['situacao'] as String,
          checked: p['conferido'] == true,
          notes: p['observacoes'] as String?,
        ));
        return false;
      case 'check':
        await remote.markCheckedAt(op.number, op.editedAt);
        return false;
      case 'upload_photo':
        final tempId = op.payload['temp_id'] as int;
        final bytes = await store.photoBytes(op.number, tempId);
        if (bytes == null) {
          throw const ApiException(410, 'Foto local não encontrada.');
        }
        final photo = await remote.uploadPhoto(op.number, bytes);
        await store.promotePhoto(op.number, tempId, photo.id);
        return false;
      case 'delete_photo':
        try {
          await remote.deletePhoto(op.number, op.payload['photo_id'] as int);
        } on ApiException catch (error) {
          if (error.statusCode != 404) rethrow;
        }
        return false;
    }
    throw ApiException(400, 'Operação desconhecida: ${op.type}');
  }

  /// Baixa o Inventário inteiro e só então troca o cache, preservando
  /// Patrimônios com pendências locais.
  Future<void> _pullInventory() async {
    final fetched = <InventoryEntry>[];
    var offset = 0;
    while (true) {
      final page =
          await remote.fetchInventory(offset: offset, limit: _pageSize);
      fetched.addAll(page.items);
      offset += page.items.length;
      if (page.items.isEmpty || offset >= page.total) break;
    }
    final pending = await _pendingNumbers();
    final serverNumbers = fetched.map((e) => e.number).toSet();
    final stale = (await store.entries())
        .map((e) => e.number)
        .where((n) => !serverNumbers.contains(n) && !pending.contains(n));
    await store.removeEntries(stale.toList());
    await store.putEntries(fetched.where((e) => !pending.contains(e.number)));
  }

  // ---- Online apenas ---------------------------------------------------

  @override
  Future<ImportSummary> importInventory(
      String filename, List<int> bytes) async {
    final summary = await remote.importInventory(filename, bytes);
    unawaited(synchronize());
    return summary;
  }

  @override
  Future<DownloadedFile> exportChanges() => remote.exportChanges();

  @override
  Future<DownloadedFile> exportReport() => remote.exportReport();

  @override
  Future<InventoryTotals> fetchTotals() => remote.fetchTotals();

  @override
  Future<List<ChangedItem>> fetchChanges() => remote.fetchChanges();

  @override
  Future<DownloadedFile> exportSpreadsheet({
    required ExportFormat format,
    required bool onlyModified,
    DateTime? now,
  }) =>
      remote.exportSpreadsheet(
        format: format,
        onlyModified: onlyModified,
        now: now ?? _clock(),
      );

  /// Baixa para o cache as fotos do servidor que ainda não estão nele.
  @override
  Future<int> restoreSyncedPhotos() async {
    var restored = 0;
    for (final entry in await store.entries()) {
      final before = (await store.photos(entry.number)).length;
      await fetchPhotos(entry.number);
      final after = (await store.photos(entry.number)).length;
      if (after > before) restored += after - before;
    }
    return restored;
  }

  /// Remove do cache as fotos de patrimônios que não estão mais no Inventário.
  @override
  Future<int> cleanOrphanPhotos() async {
    final known = {for (final e in await store.entries()) e.number};
    var removed = 0;
    for (final photo in await store.allPhotos()) {
      if (known.contains(photo.number)) continue;
      await store.removePhoto(photo.number, photo.id);
      removed++;
    }
    return removed;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _connectivitySub.cancel();
    _controller.close();
  }

  @override
  void close() {
    dispose();
    connectivity.dispose();
    remote.close();
  }
}

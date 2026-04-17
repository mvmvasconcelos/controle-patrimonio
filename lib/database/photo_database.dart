import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class PhotoDatabase {
  static const String dbName = 'fotos.db';
  static const String tableName = 'fotos_patrimonio';
  static const String deleteQueueTableName = 'fotos_patrimonio_delete_queue';
  static const int maxPhotos = 3;
  static const String syncPendingUpload = 'pending_upload';
  static const String syncSynced = 'synced';
  static const String syncOriginApp = 'app';
  static const String syncOriginServer = 'server';

  static Database? _db;

  static Future<void> init() async {
    if (_db != null) {
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(directory.path, dbName);

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            numero_patrimonio TEXT NOT NULL,
            imagem_blob BLOB NOT NULL,
            data_modificacao TEXT NOT NULL,
            server_photo_id INTEGER,
            sync_status TEXT NOT NULL DEFAULT '$syncPendingUpload',
            sync_origin TEXT NOT NULL DEFAULT '$syncOriginApp'
          )
        ''');

        await db.execute('''
          CREATE TABLE $deleteQueueTableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            numero_patrimonio TEXT NOT NULL,
            server_photo_id INTEGER NOT NULL,
            data_modificacao TEXT NOT NULL
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_fotos_numero ON $tableName(numero_patrimonio)',
        );
        await db.execute(
          'CREATE INDEX idx_fotos_sync_status ON $tableName(sync_status)',
        );
        await db.execute(
          'CREATE INDEX idx_delete_queue_numero ON '
          '$deleteQueueTableName(numero_patrimonio)',
        );
      },
    );
  }

  static Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }

    await init();
    return _db!;
  }

  static Future<List<PhotoRecord>> getPhotos(String numeroPatrimonio) async {
    final db = await database;
    final rows = await db.query(
      tableName,
      where: 'numero_patrimonio = ?',
      whereArgs: [numeroPatrimonio],
      orderBy: 'data_modificacao DESC, id DESC',
    );

    return rows.map(PhotoRecord.fromMap).toList();
  }

  static Future<PhotoRecord?> getPhotoById(int id) async {
    final db = await database;
    final rows = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return PhotoRecord.fromMap(rows.first);
  }

  static Future<bool> hasPhotos(String numeroPatrimonio) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableName WHERE numero_patrimonio = ?',
      [numeroPatrimonio],
    );

    return (rows.first['count'] as int? ?? 0) > 0;
  }

  static Future<Set<String>> getAllNumbersWithPhotos() async {
    final db = await database;
    final rows = await db.query(
      tableName,
      distinct: true,
      columns: ['numero_patrimonio'],
    );

    return rows
        .map((row) => row['numero_patrimonio'] as String)
        .where((numero) => numero.trim().isNotEmpty)
        .toSet();
  }

  static Future<Set<String>> getOrphanNumbers(Set<String> numerosAtuais) async {
    final numerosComFotos = await getAllNumbersWithPhotos();
    return numerosComFotos.where((numero) => !numerosAtuais.contains(numero)).toSet();
  }

  static Future<List<PhotoRecord>> getPendingUploads() async {
    final db = await database;
    final rows = await db.query(
      tableName,
      where: 'sync_status = ?',
      whereArgs: [syncPendingUpload],
      orderBy: 'data_modificacao ASC, id ASC',
    );

    return rows.map(PhotoRecord.fromMap).toList();
  }

  static Future<int> getPendingSyncCount() async {
    final db = await database;
    final pendingUploads = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $tableName WHERE sync_status = ?',
            [syncPendingUpload],
          ),
        ) ??
        0;
    final pendingDeletes = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $deleteQueueTableName'),
        ) ??
        0;
    return pendingUploads + pendingDeletes;
  }

  static Future<int> getPendingSyncCountForItem(String numeroPatrimonio) async {
    final db = await database;
    final normalized = numeroPatrimonio.trim();
    final pendingUploads = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $tableName '
            'WHERE numero_patrimonio = ? AND sync_status = ?',
            [normalized, syncPendingUpload],
          ),
        ) ??
        0;
    final pendingDeletes = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $deleteQueueTableName '
            'WHERE numero_patrimonio = ?',
            [normalized],
          ),
        ) ??
        0;
    return pendingUploads + pendingDeletes;
  }

  static Future<void> addPhoto(
    String numeroPatrimonio,
    Uint8List imageBytes,
  ) async {
    final db = await database;
    final normalized = numeroPatrimonio.trim();
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $tableName WHERE numero_patrimonio = ?',
        [normalized],
      ),
    );

    if ((count ?? 0) >= maxPhotos) {
      throw Exception('Limite de $maxPhotos fotos por item atingido.');
    }

    await db.insert(tableName, {
      'numero_patrimonio': normalized,
      'imagem_blob': imageBytes,
      'data_modificacao': DateTime.now().toIso8601String(),
      'sync_status': syncPendingUpload,
      'sync_origin': syncOriginApp,
    });
  }

  static Future<void> markPhotoAsSynced(
    int id, {
    required int serverPhotoId,
    String syncOrigin = syncOriginApp,
  }) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'server_photo_id': serverPhotoId,
        'sync_status': syncSynced,
        'sync_origin': syncOrigin,
        'data_modificacao': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> saveDownloadedPhoto(
    String numeroPatrimonio,
    Uint8List imageBytes, {
    required int serverPhotoId,
    DateTime? modifiedAt,
  }) async {
    final db = await database;
    final existing = await db.query(
      tableName,
      columns: ['id'],
      where: 'server_photo_id = ?',
      whereArgs: [serverPhotoId],
      limit: 1,
    );

    final values = {
      'numero_patrimonio': numeroPatrimonio.trim(),
      'imagem_blob': imageBytes,
      'data_modificacao': (modifiedAt ?? DateTime.now()).toIso8601String(),
      'server_photo_id': serverPhotoId,
      'sync_status': syncSynced,
      'sync_origin': syncOriginServer,
    };

    if (existing.isEmpty) {
      await db.insert(tableName, values);
      return;
    }

    await db.update(
      tableName,
      values,
      where: 'server_photo_id = ?',
      whereArgs: [serverPhotoId],
    );
  }

  static Future<void> deletePhoto(int id) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> enqueueRemoteDelete(PhotoRecord photo) async {
    if (photo.serverPhotoId == null) {
      return;
    }

    final db = await database;
    await db.insert(deleteQueueTableName, {
      'numero_patrimonio': photo.numeroPatrimonio,
      'server_photo_id': photo.serverPhotoId,
      'data_modificacao': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<PhotoDeleteRecord>> getPendingDeletes() async {
    final db = await database;
    final rows = await db.query(
      deleteQueueTableName,
      orderBy: 'data_modificacao ASC, id ASC',
    );

    return rows.map(PhotoDeleteRecord.fromMap).toList();
  }

  static Future<void> removePendingDelete(int id) async {
    final db = await database;
    await db.delete(
      deleteQueueTableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteAllPhotos(String numeroPatrimonio) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'numero_patrimonio = ?',
      whereArgs: [numeroPatrimonio],
    );
  }

  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete(deleteQueueTableName);
    await db.delete(tableName);
  }

  static Future<int> deletePhotosByNumbers(Set<String> numerosPatrimonio) async {
    if (numerosPatrimonio.isEmpty) {
      return 0;
    }

    final db = await database;
    final args = numerosPatrimonio.toList(growable: false);
    final placeholders = List.filled(args.length, '?').join(', ');

    final deletedPhotos = await db.delete(
      tableName,
      where: 'numero_patrimonio IN ($placeholders)',
      whereArgs: args,
    );

    await db.delete(
      deleteQueueTableName,
      where: 'numero_patrimonio IN ($placeholders)',
      whereArgs: args,
    );

    return deletedPhotos;
  }
}

class PhotoRecord {
  final int id;
  final String numeroPatrimonio;
  final Uint8List imageBytes;
  final DateTime dataModificacao;
  final int? serverPhotoId;
  final String syncStatus;
  final String syncOrigin;

  const PhotoRecord({
    required this.id,
    required this.numeroPatrimonio,
    required this.imageBytes,
    required this.dataModificacao,
    required this.serverPhotoId,
    required this.syncStatus,
    required this.syncOrigin,
  });

  factory PhotoRecord.fromMap(Map<String, Object?> map) {
    return PhotoRecord(
      id: map['id'] as int,
      numeroPatrimonio: map['numero_patrimonio'] as String,
      imageBytes: map['imagem_blob'] as Uint8List,
      dataModificacao: DateTime.parse(map['data_modificacao'] as String),
      serverPhotoId: map['server_photo_id'] as int?,
      syncStatus: map['sync_status'] as String? ?? PhotoDatabase.syncPendingUpload,
      syncOrigin: map['sync_origin'] as String? ?? PhotoDatabase.syncOriginApp,
    );
  }
}

class PhotoDeleteRecord {
  final int id;
  final String numeroPatrimonio;
  final int serverPhotoId;
  final DateTime dataModificacao;

  const PhotoDeleteRecord({
    required this.id,
    required this.numeroPatrimonio,
    required this.serverPhotoId,
    required this.dataModificacao,
  });

  factory PhotoDeleteRecord.fromMap(Map<String, Object?> map) {
    return PhotoDeleteRecord(
      id: map['id'] as int,
      numeroPatrimonio: map['numero_patrimonio'] as String,
      serverPhotoId: map['server_photo_id'] as int,
      dataModificacao: DateTime.parse(map['data_modificacao'] as String),
    );
  }
}
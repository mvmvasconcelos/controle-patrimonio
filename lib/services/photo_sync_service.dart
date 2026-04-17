import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../database/photo_database.dart';

class PhotoSyncService {
  static const List<String> _apiBaseCandidates = [
    'http://128.1.1.49:6090/api/v1',
    'https://ifva.duckdns.org/api/v1',
  ];
  static String? _lastError;

  static String? get lastError => _lastError;

  static Future<bool> syncAll(BuildContext context) async {
    _lastError = null;
    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity.contains(ConnectivityResult.none);
    final pendingUploads = await PhotoDatabase.getPendingUploads();
    final pendingDeletes = await PhotoDatabase.getPendingDeletes();

    if (isOffline) {
      final pendingCount = pendingUploads.length + pendingDeletes.length;
      if (pendingCount > 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$pendingCount foto(s) pendentes de sincronização com o servidor.'),
          ),
        );
      }
      _lastError = 'Sem conexão com a internet.';
      return false;
    }

    var hadSuccess = false;
    var hadFailure = false;
    for (final photo in pendingUploads) {
      try {
        await _uploadPhoto(photo);
        hadSuccess = true;
      } catch (e) {
        _lastError = e.toString();
        hadFailure = true;
        // Mantém pendente para a próxima tentativa.
      }
    }

    for (final deleteRecord in pendingDeletes) {
      try {
        await _deleteRemotePhoto(deleteRecord);
        hadSuccess = true;
      } catch (e) {
        _lastError = e.toString();
        hadFailure = true;
        // Mantém pendente para a próxima tentativa.
      }
    }

    if (hadFailure && !hadSuccess && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao sincronizar fotos: ${_lastError ?? 'erro desconhecido'}'),
          backgroundColor: Colors.red,
        ),
      );
    }

    return hadSuccess;
  }

  static Future<void> downloadPhotos(List<String> numeros) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      _lastError = 'Sem conexão com a internet.';
      return;
    }

    for (final numero in numeros) {
      final response = await _requestWithFallback((baseApi) {
        final uri = Uri.parse('$baseApi/patrimonio/$numero/fotos');
        return http.get(uri);
      });
      if (response.statusCode != 200) {
        continue;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (body['items'] as List<dynamic>? ?? const []);
      for (final item in items.cast<Map<String, dynamic>>()) {
        final photoId = item['id'] as int?;
        if (photoId == null) {
          continue;
        }

        final bytes = await _downloadPhotoBytes(numero, photoId);
        if (bytes == null) {
          continue;
        }

        await PhotoDatabase.saveDownloadedPhoto(
          numero,
          bytes,
          serverPhotoId: photoId,
          modifiedAt: DateTime.tryParse(item['data_modificacao']?.toString() ?? ''),
        );
      }
    }
  }

  static Future<void> _uploadPhoto(PhotoRecord photo) async {
    final response = await _multipartWithFallback(
      photo.numeroPatrimonio,
      photo,
    );
    if (response.statusCode == 201) {
      final body = await response.stream.bytesToString();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      await PhotoDatabase.markPhotoAsSynced(
        photo.id,
        serverPhotoId: decoded['id'] as int,
      );
      return;
    }

    if (response.statusCode == 409) {
      throw Exception('Conflito ao sincronizar foto ${photo.id}');
    }

    throw Exception('Falha no upload da foto ${photo.id}: ${response.statusCode}');
  }

  static Future<void> _deleteRemotePhoto(PhotoDeleteRecord deleteRecord) async {
    final response = await _requestWithFallback((baseApi) {
      final uri = Uri.parse(
        '$baseApi/patrimonio/${deleteRecord.numeroPatrimonio}/fotos/${deleteRecord.serverPhotoId}',
      );
      return http.delete(uri);
    });
    if (response.statusCode == 204 || response.statusCode == 404) {
      await PhotoDatabase.removePendingDelete(deleteRecord.id);
      return;
    }

    throw Exception('Falha ao remover foto remota ${deleteRecord.serverPhotoId}');
  }

  static Future<Uint8List?> _downloadPhotoBytes(String numero, int photoId) async {
    final response = await _requestWithFallback((baseApi) {
      final uri = Uri.parse('$baseApi/patrimonio/$numero/fotos/$photoId');
      return http.get(uri);
    });
    if (response.statusCode != 200) {
      return null;
    }

    return response.bodyBytes;
  }

  static Future<http.Response> _requestWithFallback(
    Future<http.Response> Function(String baseApi) call,
  ) async {
    Object? lastError;
    for (final baseApi in _apiBaseCandidates) {
      try {
        final response = await call(baseApi);
        if (response.statusCode < 500) {
          return response;
        }
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Servidor indisponível para sincronização de fotos: ${lastError ?? 'sem resposta'}');
  }

  static Future<http.StreamedResponse> _multipartWithFallback(
    String numeroPatrimonio,
    PhotoRecord photo,
  ) async {
    Object? lastError;
    for (final baseApi in _apiBaseCandidates) {
      try {
        final uri = Uri.parse('$baseApi/patrimonio/$numeroPatrimonio/fotos');
        final request = http.MultipartRequest('POST', uri)
          ..files.add(
            http.MultipartFile.fromBytes(
              'foto',
              photo.imageBytes,
              filename: 'foto_${photo.id}.jpg',
            ),
          );
        final response = await request.send();
        if (response.statusCode < 500) {
          return response;
        }
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Servidor indisponível para upload de fotos: ${lastError ?? 'sem resposta'}');
  }
}
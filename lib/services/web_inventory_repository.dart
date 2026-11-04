import 'dart:convert';

import 'package:http/http.dart' as http;

import 'file_download.dart';
import 'web_http_client.dart';

export 'file_download.dart' show DownloadedFile;

class AdminSession {
  const AdminSession({
    required this.username,
    required this.role,
    required this.csrfToken,
  });

  final String username;
  final String role;
  final String csrfToken;

  factory AdminSession.fromJson(Map<String, dynamic> json) => AdminSession(
        username: json['username'] as String,
        role: json['role'] as String,
        csrfToken: json['csrf_token'] as String,
      );
}

class InventoryEntry {
  const InventoryEntry({
    required this.number,
    required this.description,
    required this.room,
    required this.responsible,
    required this.status,
  });

  final String number;
  final String description;
  final String room;
  final String responsible;
  final String status;

  factory InventoryEntry.fromJson(Map<String, dynamic> json) => InventoryEntry(
        number: json['numero_patrimonio'] as String,
        description: json['descricao'] as String,
        room: json['sala'] as String,
        responsible: json['responsavel'] as String,
        status: json['situacao'] as String,
      );
}

class ImportRowError {
  const ImportRowError({required this.line, required this.message});

  final int line;
  final String message;

  factory ImportRowError.fromJson(Map<String, dynamic> json) => ImportRowError(
        line: json['linha'] as int,
        message: json['mensagem'] as String,
      );
}

class ImportSummary {
  const ImportSummary({
    required this.created,
    required this.updated,
    required this.unchanged,
    required this.errors,
  });

  final int created;
  final int updated;
  final int unchanged;
  final List<ImportRowError> errors;

  factory ImportSummary.fromJson(Map<String, dynamic> json) => ImportSummary(
        created: json['novos'] as int,
        updated: json['atualizados'] as int,
        unchanged: json['inalterados'] as int,
        errors: (json['erros'] as List<dynamic>)
            .map((e) => ImportRowError.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class WebInventoryRepository {
  WebInventoryRepository({http.Client? client, Uri? apiBaseUrl})
      : _client = client ?? createWebHttpClient(),
        _apiBaseUrl = apiBaseUrl ?? Uri.base.resolve('api/v1/');

  final http.Client _client;
  final Uri _apiBaseUrl;
  String? _csrfToken;

  Future<AdminSession?> restoreSession() async {
    final response = await _client.get(_uri('auth/me'));
    if (response.statusCode == 401) {
      _csrfToken = null;
      return null;
    }
    if (response.statusCode != 200) {
      throw _requestError(response);
    }
    final session = AdminSession.fromJson(_decode(response));
    _csrfToken = session.csrfToken;
    return session;
  }

  Future<AdminSession> login(String username, String password) async {
    final response = await _client.post(
      _uri('auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw _requestError(response);
    }
    final session = AdminSession.fromJson(_decode(response));
    _csrfToken = session.csrfToken;
    return session;
  }

  Future<List<InventoryEntry>> loadInventory() async {
    final response = await _client.get(_uri('patrimonio'));
    if (response.statusCode != 200) {
      throw _requestError(response);
    }
    final items = _decode(response)['items'] as List<dynamic>;
    return items
        .map((item) => InventoryEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ImportSummary> importInventory(
      String filename, List<int> bytes) async {
    final request = http.MultipartRequest('POST', _uri('inventario/importar'))
      ..headers['X-CSRF-Token'] = _csrfToken ?? ''
      ..files.add(http.MultipartFile.fromBytes(
        'arquivo',
        bytes,
        filename: filename,
      ));
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode != 200) {
      throw _requestError(response);
    }
    return ImportSummary.fromJson(_decode(response));
  }

  Future<DownloadedFile> exportChanges() =>
      _download('inventario/exportar/alteracoes', 'alteracoes.csv');

  Future<DownloadedFile> exportReport() =>
      _download('inventario/exportar/relatorio', 'relatorio.csv');

  Future<DownloadedFile> _download(String path, String filename) async {
    final response = await _client.get(_uri(path));
    if (response.statusCode != 200) {
      throw _requestError(response);
    }
    return DownloadedFile(filename, response.bodyBytes);
  }

  Future<void> logout() async {
    final response = await _client.post(
      _uri('auth/logout'),
      headers: {
        'X-CSRF-Token': _csrfToken ?? '',
      },
    );
    if (response.statusCode != 204) {
      throw _requestError(response);
    }
    _csrfToken = null;
  }

  Uri _uri(String path) => _apiBaseUrl.resolve(path);

  Map<String, dynamic> _decode(http.Response response) =>
      jsonDecode(response.body) as Map<String, dynamic>;

  Exception _requestError(http.Response response) {
    String message = 'Falha ao comunicar com o servidor.';
    try {
      final body = _decode(response);
      message = body['detail']?.toString() ?? message;
    } on FormatException {
      // Use the generic message for non-JSON responses.
    }
    return Exception(message);
  }

  void close() => _client.close();
}

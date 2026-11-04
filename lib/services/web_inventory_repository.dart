import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

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
    this.notes,
    this.checked = false,
  });

  final String number;
  final String description;
  final String room;
  final String responsible;
  final String status;
  final String? notes;
  final bool checked;

  factory InventoryEntry.fromJson(Map<String, dynamic> json) => InventoryEntry(
        number: json['numero_patrimonio'] as String,
        description: json['descricao'] as String,
        room: json['sala'] as String,
        responsible: json['responsavel'] as String,
        status: json['situacao'] as String,
        notes: json['observacoes'] as String?,
        checked: json['conferido'] as bool? ?? false,
      );
}

class NewInventoryEntry {
  const NewInventoryEntry({
    required this.number,
    required this.description,
    required this.room,
    required this.responsible,
    required this.status,
    this.checked = false,
    this.notes,
  });

  final String number;
  final String description;
  final String room;
  final String responsible;
  final String status;
  final bool checked;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'numero_patrimonio': number,
        'descricao': description,
        'sala': room,
        'responsavel': responsible,
        'situacao': status,
        if (checked) 'conferido': true,
        if (notes != null && notes!.trim().isNotEmpty) 'observacoes': notes,
      };
}

const maxPhotoBytes = 5 * 1024 * 1024;
const maxPhotosPerPatrimony = 3;

class PatrimonyPhoto {
  const PatrimonyPhoto({required this.id, required this.number});

  final int id;
  final String number;

  factory PatrimonyPhoto.fromJson(Map<String, dynamic> json) => PatrimonyPhoto(
        id: json['id'] as int,
        number: json['numero_patrimonio'] as String,
      );
}

class InventoryPage {
  const InventoryPage({required this.total, required this.items});

  final int total;
  final List<InventoryEntry> items;
}

class InventoryFilters {
  const InventoryFilters({required this.rooms, required this.statuses});

  final List<String> rooms;
  final List<String> statuses;
}

class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => 'Sessão expirada. Entre novamente para continuar.';
}

class PatrimonyNotFoundException implements Exception {
  const PatrimonyNotFoundException(this.number);

  final String number;

  @override
  String toString() => 'Patrimônio $number não encontrado no Inventário.';
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

  Future<InventoryPage> fetchInventory({
    String? query,
    String? room,
    String? status,
    bool? checked,
    int offset = 0,
    int limit = 50,
  }) async {
    final params = <String, String>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (room != null && room.isNotEmpty) 'sala': room,
      if (status != null && status.isNotEmpty) 'situacao': status,
      if (checked != null) 'conferido': checked.toString(),
      'offset': '$offset',
      'limit': '$limit',
    };
    final response =
        await _client.get(_uri('patrimonio').replace(queryParameters: params));
    _ensureData(response);
    final body = _decode(response);
    return InventoryPage(
      total: body['total'] as int,
      items: (body['items'] as List<dynamic>)
          .map((item) => InventoryEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<InventoryFilters> fetchFilters() async {
    final response = await _client.get(_uri('patrimonio/filtros'));
    _ensureData(response);
    final body = _decode(response);
    return InventoryFilters(
      rooms: (body['salas'] as List<dynamic>).cast<String>(),
      statuses: (body['situacoes'] as List<dynamic>).cast<String>(),
    );
  }

  Future<InventoryEntry?> fetchEntry(String number) async {
    final response = await _client.get(_patrimonyUri(number));
    if (response.statusCode == 404) return null;
    _ensureData(response);
    return InventoryEntry.fromJson(_decode(response));
  }

  Future<InventoryEntry> updateEntry(
      String number, Map<String, String?> fields) async {
    final response = await _client.patch(
      _patrimonyUri(number),
      headers: _mutationHeaders,
      body: jsonEncode(fields),
    );
    if (response.statusCode == 404) throw PatrimonyNotFoundException(number);
    _ensureData(response);
    return InventoryEntry.fromJson(_decode(response));
  }

  Future<InventoryEntry> createEntry(NewInventoryEntry entry) async {
    final response = await _client.post(
      _uri('patrimonio'),
      headers: _mutationHeaders,
      body: jsonEncode(entry.toJson()),
    );
    _ensureData(response, expected: 201);
    return InventoryEntry.fromJson(_decode(response));
  }

  Future<void> markChecked(String number) async {
    final response = await _client.post(
      _patrimonyUri(number, suffix: '/conferencia'),
      headers: _mutationHeaders,
    );
    if (response.statusCode == 404) {
      throw PatrimonyNotFoundException(number.trim());
    }
    _ensureData(response);
  }

  Future<List<PatrimonyPhoto>> fetchPhotos(String number) async {
    final response = await _client.get(_patrimonyUri(number, suffix: '/fotos'));
    _ensureData(response);
    return (_decode(response)['items'] as List<dynamic>)
        .map((item) => PatrimonyPhoto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Uint8List> fetchPhotoBytes(String number, int photoId) async {
    final response =
        await _client.get(_patrimonyUri(number, suffix: '/fotos/$photoId'));
    _ensureData(response);
    return response.bodyBytes;
  }

  Future<PatrimonyPhoto> uploadPhoto(String number, Uint8List bytes) async {
    if (bytes.length > maxPhotoBytes) {
      throw Exception(
          'Foto maior que o limite de ${maxPhotoBytes ~/ (1024 * 1024)} MB');
    }
    final request = http.MultipartRequest(
        'POST', _patrimonyUri(number, suffix: '/fotos'))
      ..headers['X-CSRF-Token'] = _csrfToken ?? ''
      ..files.add(http.MultipartFile.fromBytes(
        'foto',
        bytes,
        filename: 'foto.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    _ensureData(response, expected: 201);
    return PatrimonyPhoto.fromJson(_decode(response));
  }

  Future<void> deletePhoto(String number, int photoId) async {
    final response = await _client.delete(
      _patrimonyUri(number, suffix: '/fotos/$photoId'),
      headers: {'X-CSRF-Token': _csrfToken ?? ''},
    );
    _ensureData(response, expected: 204);
  }

  Map<String, String> get _mutationHeaders => {
        'Content-Type': 'application/json',
        'X-CSRF-Token': _csrfToken ?? '',
      };

  Uri _patrimonyUri(String number, {String suffix = ''}) => _apiBaseUrl
      .resolve('patrimonio/${Uri.encodeComponent(number.trim())}$suffix');

  void _ensureData(http.Response response, {int expected = 200}) {
    if (response.statusCode == 401) throw const SessionExpiredException();
    if (response.statusCode != expected) throw _requestError(response);
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

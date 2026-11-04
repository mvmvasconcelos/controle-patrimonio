import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Servidor em memória que imita a API (inclusive last-write-wins).
class FakeServer {
  FakeServer() {
    for (final n in ['100', '101', '102']) {
      rows[n] = {
        'numero_patrimonio': n,
        'descricao': 'Mesa $n',
        'sala': 'Sala A',
        'responsavel': 'Ana',
        'situacao': 'Ativo',
        'observacoes': null,
        'conferido': false,
      };
    }
  }

  final rows = <String, Map<String, dynamic>>{};
  final editedAt = <String, DateTime>{};
  final photos = <String, Map<int, Uint8List>>{};
  final log = <String>[];
  final bodies = <String, Object?>{};
  bool down = false;
  bool sessionValid = true;
  int? failWith;
  var _nextPhoto = 1;

  late final client = MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    if (down) throw http.ClientException('offline');
    final path = request.url.path.replaceFirst('/api/v1/', '');
    log.add('${request.method} $path');
    if (path == 'auth/login') {
      sessionValid = true;
      return _json({'username': 'admin', 'role': 'admin', 'csrf_token': 'c'});
    }
    if (!sessionValid) return _json({'detail': 'expirada'}, 401);
    if (failWith != null) return _json({'detail': 'falha'}, failWith!);
    if (path == 'auth/me') {
      return _json({'username': 'admin', 'role': 'admin', 'csrf_token': 'c'});
    }
    if (path == 'auth/logout') return http.Response('', 204);
    if (path == 'patrimonio' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final number = body['numero_patrimonio'] as String;
      if (rows.containsKey(number)) {
        return _json({'detail': 'já existe'}, 409);
      }
      rows[number] = {...body, 'conferido': body['conferido'] == true};
      return _json(rows[number], 201);
    }
    if (path == 'patrimonio') {
      final all = rows.values.toList()
        ..sort((a, b) => (a['numero_patrimonio'] as String)
            .compareTo(b['numero_patrimonio'] as String));
      final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
      final limit = int.parse(request.url.queryParameters['limit'] ?? '50');
      return _json({
        'total': all.length,
        'items': all.skip(offset).take(limit).toList(),
      });
    }
    final parts = path.split('/');
    final number = Uri.decodeComponent(parts[1]);
    if (!rows.containsKey(number))
      return _json({'detail': 'não encontrado'}, 404);
    final suffix = parts.length > 2 ? parts.sublist(2).join('/') : '';
    switch ('${request.method} $suffix') {
      case 'GET ':
        return _json(rows[number]);
      case 'PATCH ':
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        bodies['PATCH $number'] = body;
        final at = DateTime.parse(body.remove('editado_em') as String);
        final current = editedAt[number];
        final applied = current == null || !at.isBefore(current);
        if (applied) {
          rows[number]!.addAll(body);
          editedAt[number] = at;
        }
        return _json({...rows[number]!, 'edicao_aplicada': applied});
      case 'POST conferencia':
        bodies['POST $number'] = request.body;
        final repeated = rows[number]!['conferido'] == true;
        rows[number]!['conferido'] = true;
        return _json({
          'numero_patrimonio': number,
          'conferido_em': DateTime.now().toUtc().toIso8601String(),
          'repetida': repeated,
        });
      case 'GET fotos':
        return _json({
          'total': (photos[number] ?? {}).length,
          'items': [
            for (final id in (photos[number] ?? {}).keys)
              {'id': id, 'numero_patrimonio': number},
          ],
        });
      case 'POST fotos':
        final id = _nextPhoto++;
        (photos[number] ??= {})[id] = request.bodyBytes;
        return _json({'id': id, 'numero_patrimonio': number}, 201);
    }
    if (parts.length == 4 && parts[2] == 'fotos') {
      final id = int.parse(parts[3]);
      final bytes = photos[number]?[id];
      if (request.method == 'GET') {
        return bytes == null
            ? _json({'detail': 'sem foto'}, 404)
            : http.Response.bytes(bytes, 200);
      }
      if (request.method == 'DELETE') {
        if (bytes == null) return _json({'detail': 'sem foto'}, 404);
        photos[number]!.remove(id);
        return http.Response('', 204);
      }
    }
    return _json({'detail': 'rota desconhecida'}, 400);
  }

  http.Response _json(Object? body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );
}

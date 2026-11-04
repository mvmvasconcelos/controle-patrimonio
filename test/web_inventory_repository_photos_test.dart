import 'dart:convert';
import 'dart:typed_data';

import 'package:controle_patrimonio/services/web_inventory_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

Future<(WebInventoryRepository, List<http.BaseRequest>)> _logged(
  Future<http.StreamedResponse> Function(http.BaseRequest) handler,
) async {
  final requests = <http.BaseRequest>[];
  final client = _StreamClient((request) async {
    if (request.url.path.endsWith('/auth/login')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'username': 'u',
          'role': 'administrador',
          'csrf_token': 'csrf-1'
        }))),
        200,
      );
    }
    requests.add(request);
    return handler(request);
  });
  final repository = WebInventoryRepository(
    client: client,
    apiBaseUrl: Uri.parse('https://host/api/v1/'),
  );
  await repository.login('u', 'p');
  return (repository, requests);
}

class _StreamClient extends http.BaseClient {
  _StreamClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}

http.StreamedResponse _json(Object body, int status) =>
    http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), status);

void main() {
  test('fetchPhotos lists the photos of one Patrimônio', () async {
    final (repository, requests) = await _logged((_) async => _json({
          'total': 1,
          'items': [
            {
              'id': 7,
              'numero_patrimonio': '10/A',
              'data_modificacao': '2026-04-13T14:30:00',
              'sync_origin': 'app',
            }
          ],
        }, 200));

    final photos = await repository.fetchPhotos(' 10/A ');

    expect(photos.single.id, 7);
    expect(photos.single.number, '10/A');
    expect(requests.single.method, 'GET');
    expect(requests.single.url.toString(),
        'https://host/api/v1/patrimonio/10%2FA/fotos');
  });

  test('fetchPhotoBytes returns the image bytes', () async {
    final (repository, requests) = await _logged(
        (_) async => http.StreamedResponse(Stream.value([1, 2, 3]), 200));

    final bytes = await repository.fetchPhotoBytes('10', 7);

    expect(bytes, [1, 2, 3]);
    expect(requests.single.url.path, '/api/v1/patrimonio/10/fotos/7');
  });

  test('uploadPhoto sends multipart JPEG with CSRF and returns metadata',
      () async {
    late http.MultipartRequest sent;
    final (repository, _) = await _logged((request) async {
      sent = request as http.MultipartRequest;
      return _json({
        'id': 8,
        'numero_patrimonio': '10',
        'data_modificacao': '2026-04-13T14:30:00',
        'sync_origin': 'app',
      }, 201);
    });

    final photo =
        await repository.uploadPhoto('10', Uint8List.fromList([0xff, 0xd8, 1]));

    expect(photo.id, 8);
    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/v1/patrimonio/10/fotos');
    expect(sent.headers['X-CSRF-Token'], 'csrf-1');
    final file = sent.files.single;
    expect(file.field, 'foto');
    expect(file.contentType.mimeType, 'image/jpeg');
  });

  test('uploadPhoto surfaces the server error message', () async {
    final (repository, _) = await _logged((_) async =>
        _json({'detail': 'Limite de 3 fotos por patrimônio atingido'}, 409));

    expect(
      () => repository.uploadPhoto('10', Uint8List.fromList([0xff, 0xd8, 1])),
      throwsA(predicate((e) => e.toString().contains('Limite de 3 fotos'))),
    );
  });

  test('uploadPhoto rejects photos above the size limit before sending',
      () async {
    final (repository, requests) =
        await _logged((_) async => _json({}, 201));

    await expectLater(
      repository.uploadPhoto('10', Uint8List(maxPhotoBytes + 1)),
      throwsA(predicate((e) => e.toString().contains('5 MB'))),
    );
    expect(requests, isEmpty);
  });

  test('deletePhoto sends DELETE with CSRF', () async {
    final (repository, requests) =
        await _logged((_) async => http.StreamedResponse(const Stream.empty(), 204));

    await repository.deletePhoto('10', 7);

    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.path, '/api/v1/patrimonio/10/fotos/7');
    expect(requests.single.headers['X-CSRF-Token'], 'csrf-1');
  });

  test('photo calls report an expired session', () async {
    final (repository, _) = await _logged(
        (_) async => _json({'detail': 'Não autenticado'}, 401));

    expect(() => repository.fetchPhotos('10'),
        throwsA(isA<SessionExpiredException>()));
    expect(() => repository.deletePhoto('10', 1),
        throwsA(isA<SessionExpiredException>()));
  });

  test('deletePhoto fails visibly on server error', () async {
    final (repository, _) =
        await _logged((_) async => _json({'detail': 'Falhou'}, 500));

    expect(() => repository.deletePhoto('10', 1),
        throwsA(predicate((e) => e.toString().contains('Falhou'))));
  });
}

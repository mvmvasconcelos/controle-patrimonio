import 'dart:convert';

import 'package:controle_patrimonio/services/web_inventory_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _item(String number, {bool checked = false}) => {
      'numero_patrimonio': number,
      'descricao': 'Mesa $number',
      'sala': 'Sala A',
      'responsavel': 'Ana',
      'situacao': 'Ativo',
      'observacoes': null,
      'conferido': checked,
    };

Future<(WebInventoryRepository, List<http.Request>)> _logged(
  http.Response Function(http.Request) handler,
) async {
  final requests = <http.Request>[];
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/auth/login')) {
      return http.Response(
        jsonEncode(
            {'username': 'u', 'role': 'administrador', 'csrf_token': 'csrf-1'}),
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

void main() {
  test('fetchInventory sends paging, search and filters and parses the page',
      () async {
    final (repository, requests) = await _logged((_) => http.Response(
          jsonEncode({
            'total': 120,
            'items': [_item('1'), _item('2', checked: true)],
          }),
          200,
        ));

    final page = await repository.fetchInventory(
      query: 'mesa',
      room: 'Sala A',
      status: 'Ativo',
      checked: false,
      offset: 50,
      limit: 25,
    );

    expect(page.total, 120);
    expect(page.items.map((e) => e.number), ['1', '2']);
    expect(page.items.last.checked, isTrue);
    expect(requests.single.url.queryParameters, {
      'q': 'mesa',
      'sala': 'Sala A',
      'situacao': 'Ativo',
      'conferido': 'false',
      'offset': '50',
      'limit': '25',
    });
    expect(requests.single.headers.containsKey('X-CSRF-Token'), isFalse);
  });

  test('fetchInventory omits empty filters', () async {
    final (repository, requests) = await _logged(
        (_) => http.Response(jsonEncode({'total': 0, 'items': []}), 200));
    await repository.fetchInventory(query: '  ');
    expect(requests.single.url.queryParameters.keys,
        unorderedEquals(['offset', 'limit']));
  });

  test('fetchFilters parses rooms and statuses', () async {
    final (repository, requests) = await _logged((_) => http.Response(
        jsonEncode({
          'salas': ['A', 'B'],
          'situacoes': ['Ativo']
        }),
        200));
    final filters = await repository.fetchFilters();
    expect(filters.rooms, ['A', 'B']);
    expect(filters.statuses, ['Ativo']);
    expect(requests.single.url.path, '/api/v1/patrimonio/filtros');
  });

  test('markChecked posts with CSRF and number is path-encoded', () async {
    final (repository, requests) = await _logged((_) => http.Response(
        jsonEncode({
          'numero_patrimonio': 'a/b',
          'conferido_em': '2026-01-01T00:00:00',
          'repetida': false,
        }),
        200));
    final result = await repository.markChecked(' a/b ');
    final request = requests.single;
    expect(result.repeated, isFalse);
    expect(request.method, 'POST');
    expect(request.url.toString(),
        'https://host/api/v1/patrimonio/a%2Fb/conferencia');
    expect(request.headers['X-CSRF-Token'], 'csrf-1');
  });

  test('markChecked reports an idempotent repetition from the API', () async {
    final (repository, _) = await _logged((_) => http.Response(
        jsonEncode({
          'numero_patrimonio': '100',
          'conferido_em': '2026-01-01T00:00:00',
          'repetida': true,
        }),
        200));

    final result = await repository.markChecked('100');

    expect(result.repeated, isTrue);
  });

  test('markChecked of unknown number throws PatrimonyNotFoundException',
      () async {
    final (repository, _) = await _logged(
        (_) => http.Response(jsonEncode({'detail': 'não encontrado'}), 404));
    expect(
      repository.markChecked('x'),
      throwsA(isA<PatrimonyNotFoundException>()),
    );
  });

  test('updateEntry sends PATCH with CSRF and only changed fields', () async {
    final (repository, requests) =
        await _logged((_) => http.Response(jsonEncode(_item('1')), 200));
    final entry = await repository.updateEntry('1', {'sala': 'Sala Z'});
    expect(entry.number, '1');
    expect(requests.single.method, 'PATCH');
    expect(requests.single.headers['X-CSRF-Token'], 'csrf-1');
    expect(jsonDecode(requests.single.body), {'sala': 'Sala Z'});
  });

  test('createEntry posts the new Patrimônio with CSRF', () async {
    final (repository, requests) =
        await _logged((_) => http.Response(jsonEncode(_item('9')), 201));
    final entry = await repository.createEntry(const NewInventoryEntry(
      number: '9',
      description: 'Mesa 9',
      room: 'Sala A',
      responsible: 'Ana',
      status: 'Ativo',
    ));
    expect(entry.number, '9');
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/patrimonio');
    expect(requests.single.headers['X-CSRF-Token'], 'csrf-1');
    expect(jsonDecode(requests.single.body)['numero_patrimonio'], '9');
  });

  test('createEntry can atomically register an unknown scanned Patrimônio',
      () async {
    final (repository, requests) = await _logged(
        (_) => http.Response(jsonEncode(_item('9', checked: true)), 201));
    final entry = await repository.createEntry(const NewInventoryEntry(
      number: '9',
      description: 'Mesa 9',
      room: 'Sala A',
      responsible: 'Ana',
      status: 'Ativo',
      checked: true,
    ));

    expect(entry.checked, isTrue);
    expect(jsonDecode(requests.single.body)['conferido'], isTrue);
  });

  test('createEntry surfaces the validation/duplicate message', () async {
    final (repository, _) = await _logged((_) =>
        http.Response(jsonEncode({'detail': 'Patrimônio 9 já existe'}), 409));
    await expectLater(
      repository.createEntry(const NewInventoryEntry(
          number: '9',
          description: 'd',
          room: 's',
          responsible: 'r',
          status: 'a')),
      throwsA(predicate((e) => e.toString().contains('já existe'))),
    );
  });

  test('expired session on data calls gives a clear message', () async {
    final (repository, _) = await _logged((_) =>
        http.Response(jsonEncode({'detail': 'Autenticação necessária'}), 401));
    await expectLater(
      repository.fetchInventory(),
      throwsA(isA<SessionExpiredException>()
          .having((e) => e.toString(), 'message', contains('Sessão expirada'))),
    );
    await expectLater(
        repository.markChecked('1'), throwsA(isA<SessionExpiredException>()));
  });

  test('fetchEntry returns null for 404', () async {
    final (repository, _) =
        await _logged((_) => http.Response(jsonEncode({'detail': 'x'}), 404));
    expect(await repository.fetchEntry('1'), isNull);
  });
}

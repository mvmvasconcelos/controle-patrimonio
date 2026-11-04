import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';

void main() {
  test('uses the same-origin API and sends CSRF proof only on logout',
      () async {
    final random = Random.secure();
    final username =
        List.generate(20, (_) => random.nextInt(256).toRadixString(16)).join();
    final password =
        List.generate(32, (_) => random.nextInt(256).toRadixString(16)).join();
    final csrf = base64Url.encode(
      List.generate(32, (_) => random.nextInt(256)),
    );
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/auth/login')) {
        expect(jsonDecode(request.body), {
          'username': username,
          'password': password,
        });
        return http.Response(
          jsonEncode({
            'username': username,
            'role': 'administrador',
            'csrf_token': csrf,
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/patrimonio')) {
        return http.Response(
          jsonEncode({
            'total': 1,
            'items': [
              {
                'numero_patrimonio': 'test-item',
                'descricao': 'Item de teste',
                'sala': 'Sala de teste',
                'responsavel': 'Administrador',
                'situacao': 'Ativo',
              },
            ],
          }),
          200,
        );
      }
      return http.Response('', 204);
    });
    final repository = WebInventoryRepository(
      client: client,
      apiBaseUrl: Uri.parse('https://host/controle-patrimonio/api/v1/'),
    );

    final session = await repository.login(username, password);
    final inventory = await repository.loadInventory();
    await repository.logout();

    expect(session.username, username);
    expect(inventory.single.number, 'test-item');
    expect(requests.map((request) => request.url.path), [
      '/controle-patrimonio/api/v1/auth/login',
      '/controle-patrimonio/api/v1/patrimonio',
      '/controle-patrimonio/api/v1/auth/logout',
    ]);
    expect(requests[1].headers.containsKey('X-CSRF-Token'), isFalse);
    expect(requests[2].headers['X-CSRF-Token'], csrf);
  });

  test('imports with CSRF multipart and downloads exports with cookies auth',
      () async {
    final requests = <http.BaseRequest>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({
            'username': 'u',
            'role': 'administrador',
            'csrf_token': 'csrf-test',
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/inventario/importar')) {
        if (request.headers['X-CSRF-Token'] != 'csrf-test') {
          return http.Response(jsonEncode({'detail': 'csrf'}), 403);
        }
        expect(
            request.headers['content-type'], startsWith('multipart/form-data'));
        expect(request.body, contains('filename="inv.csv"'));
        return http.Response(
          jsonEncode({
            'novos': 2,
            'atualizados': 1,
            'inalterados': 0,
            'erros': [
              {'linha': 4, 'mensagem': 'Número do patrimônio ausente'},
            ],
          }),
          200,
        );
      }
      return http.Response.bytes(utf8.encode('numero_patrimonio\n1\n'), 200);
    });
    final repository = WebInventoryRepository(
      client: client,
      apiBaseUrl: Uri.parse('https://host/api/v1/'),
    );
    await repository.login('u', 'p');

    final summary =
        await repository.importInventory('inv.csv', utf8.encode('x'));
    final changes = await repository.exportChanges();
    final report = await repository.exportReport();

    expect(summary.created, 2);
    expect(summary.updated, 1);
    expect(summary.unchanged, 0);
    expect(summary.errors.single.line, 4);
    expect(changes.filename, 'alteracoes.csv');
    expect(report.filename, 'relatorio.csv');
    expect(utf8.decode(report.bytes), contains('numero_patrimonio'));
    expect(requests.map((r) => r.url.path), [
      '/api/v1/auth/login',
      '/api/v1/inventario/importar',
      '/api/v1/inventario/exportar/alteracoes',
      '/api/v1/inventario/exportar/relatorio',
    ]);
    expect(requests[2].headers.containsKey('X-CSRF-Token'), isFalse);
  });

  test('loads server-aggregated conference report with filters', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'total': 4,
          'conferidos': 1,
          'pendentes': 3,
          'grupos': [
            {
              'sala': 'Sala A',
              'situacao': 'Ativo',
              'total': 4,
              'conferidos': 1,
              'pendentes': 3,
            },
          ],
        }),
        200,
      );
    });
    final repository = WebInventoryRepository(
      client: client,
      apiBaseUrl: Uri.parse('https://host/api/v1/'),
    );

    final report = await repository.fetchConferenceReport(
      room: 'Sala A',
      situation: 'Ativo',
    );

    expect(
        requests.single.url.path, '/api/v1/patrimonio/relatorio/conferencia');
    expect(requests.single.url.queryParameters, {
      'sala': 'Sala A',
      'situacao': 'Ativo',
    });
    expect(report.total, 4);
    expect(report.checked, 1);
    expect(report.pending, 3);
    expect(report.groups.single.room, 'Sala A');
    expect(report.groups.single.situation, 'Ativo');
    expect(report.groups.single.checked, 1);
    expect(report.groups.single.pending, 3);
  });

  test('import surfaces the server error without a false success', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode(
              {'username': 'u', 'role': 'administrador', 'csrf_token': 'c'}),
          200,
        );
      }
      return http.Response(
        jsonEncode({'detail': 'O arquivo está vazio'}),
        400,
      );
    });
    final repository = WebInventoryRepository(
      client: client,
      apiBaseUrl: Uri.parse('https://host/api/v1/'),
    );
    await repository.login('u', 'p');

    expect(
      () => repository.importInventory('inv.csv', const [1]),
      throwsA(predicate((e) => e.toString().contains('O arquivo está vazio'))),
    );
  });
}

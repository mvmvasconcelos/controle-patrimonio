import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';

void main() {
  test('uses the same-origin API and sends CSRF proof only on logout', () async {
    final random = Random.secure();
    final username = List.generate(20, (_) => random.nextInt(256).toRadixString(16))
        .join();
    final password = List.generate(32, (_) => random.nextInt(256).toRadixString(16))
        .join();
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
}

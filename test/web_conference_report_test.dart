import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:controle_patrimonio/screens/web_conference_report.dart';
import 'package:controle_patrimonio/services/web_inventory_repository.dart';

void main() {
  testWidgets('shows server totals and grouped conference states',
      (tester) async {
    final requests = <http.Request>[];
    final repository = WebInventoryRepository(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/patrimonio/filtros')) {
          return http.Response(
            jsonEncode({
              'salas': ['Sala A', 'Sala B'],
              'situacoes': ['Ativo', 'Baixado'],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/patrimonio/relatorio/conferencia')) {
          return http.Response(
            jsonEncode({
              'total': 5,
              'conferidos': 2,
              'pendentes': 3,
              'grupos': [
                {
                  'sala': 'Sala A',
                  'situacao': 'Ativo',
                  'total': 3,
                  'conferidos': 1,
                  'pendentes': 2,
                },
                {
                  'sala': 'Sala B',
                  'situacao': 'Baixado',
                  'total': 2,
                  'conferidos': 1,
                  'pendentes': 1,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/exportar/alteracoes')) {
          return http.Response(
              'numero_patrimonio,descricao,sala,responsavel,situacao,'
              'observacoes,conferido,fotos\r\n'
              '101,Mesa,Sala C,Ana,Ativo,,Sim,1\r\n',
              200);
        }
        return http.Response('', 404);
      }),
      apiBaseUrl: Uri.parse('https://host/api/v1/'),
    );

    await tester.pumpWidget(
      MaterialApp(home: WebConferenceReportPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Relatório de alterações'), findsOneWidget);
    final stats = find.byType(Card).first;
    for (final text in ['Total', '5', 'Conferidos', '2', 'Pendentes', '3']) {
      expect(
          find.descendant(of: stats, matching: find.text(text)), findsOneWidget,
          reason: text);
    }
    expect(find.text('Itens modificados'), findsOneWidget);
    expect(find.text('101 · Mesa'), findsOneWidget);
    expect(find.text('Sala A'), findsOneWidget);
    expect(find.text('Ativo'), findsOneWidget);
    expect(find.text('Baixado'), findsOneWidget);
    expect(find.text('Todas as salas'), findsOneWidget);
    expect(find.text('Todas as situações'), findsOneWidget);
    expect(
      requests.any((request) =>
          request.url.path == '/api/v1/patrimonio' &&
          !request.url.path.endsWith('/filtros')),
      isFalse,
    );

    await tester.tap(find.text('Todas as salas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sala A').last);
    await tester.pumpAndSettle();

    final reportRequests = requests
        .where((request) =>
            request.url.path == '/api/v1/patrimonio/relatorio/conferencia')
        .toList();
    expect(reportRequests.last.url.queryParameters, {'sala': 'Sala A'});
  });
}

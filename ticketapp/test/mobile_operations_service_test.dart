import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ticketapp/api_client.dart';
import 'package:ticketapp/auth_token_storage.dart';
import 'package:ticketapp/mobile_operations_service.dart';
import 'package:ticketapp/mobile_support_page.dart';

class _Tokens implements TokenStore {
  @override
  Future<String?> accessToken() async => 'test-access';
  @override
  Future<String?> refreshToken() async => null;
  @override
  Future<void> clear() async {}
  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {}
}

void main() {
  const eventId = '11111111-1111-4111-8111-111111111111';
  const caseId = '22222222-2222-4222-8222-222222222222';

  test(
    'event creation derives ownership on the server and preserves caller input',
    () async {
      late http.Request request;
      final client = ApiClient(
        baseUrl: 'https://fixture.invalid/api/v1',
        storage: _Tokens(),
        transport: MockClient((value) async {
          request = value;
          return http.Response(jsonEncode({'id': eventId}), 201);
        }),
      );
      addTearDown(client.dispose);
      final input = <String, dynamic>{
        'title': 'Presentation',
        'organizer_profile_id': caseId,
        'capacity': 20,
      };
      await MobileOperationsService(client: client).createEvent(input);
      expect(request.url.path, '/api/v1/events/');
      expect(request.headers['Authorization'], 'Bearer test-access');
      expect(jsonDecode(request.body), {
        'title': 'Presentation',
        'capacity': 20,
      });
      expect(input['organizer_profile_id'], caseId);
    },
  );

  test('support uses actual context and message contracts with authenticated requests', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://fixture.invalid/api/v1',
      storage: _Tokens(),
      transport: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(request.method == 'GET' ? [] : {'id': caseId}),
          200,
        );
      }),
    );
    addTearDown(client.dispose);
    final service = MobileOperationsService(client: client);
    await service.cases(scope: 'requested');
    await service.createCase({
      'audience': 'attendee',
      'category': 'check_in',
      'subject': 'Entry help',
      'message': 'Where is the entrance?',
      'event_id': eventId,
    });
    await service.reply(caseId, ' Thank you ');
    await service.updateCase(caseId, {
      'status': 'waiting_for_customer',
      'assignee_user_id': null,
    });
    await service.escalateCase(caseId, ' Need platform help ');
    expect(requests[0].url.path, '/api/v1/support/cases');
    expect(requests[0].url.queryParameters, {'scope': 'requested'});
    expect(jsonDecode(requests[1].body)['event_id'], eventId);
    expect(requests[2].url.path, '/api/v1/support/cases/$caseId/messages');
    expect(jsonDecode(requests[2].body), {'body': 'Thank you'});
    expect(requests[3].method, 'PATCH');
    expect(jsonDecode(requests[3].body), {
      'status': 'waiting_for_customer',
      'assignee_user_id': null,
    });
    expect(requests[4].url.path, '/api/v1/support/cases/$caseId/escalate');
    expect(jsonDecode(requests[4].body), {'reason': 'Need platform help'});
    expect(
      requests.every(
        (request) => request.headers['Authorization'] == 'Bearer test-access',
      ),
      isTrue,
    );
  });

  test('unsupported actions and invalid IDs never issue requests', () async {
    var calls = 0;
    final client = ApiClient(
      storage: _Tokens(),
      transport: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.dispose);
    final service = MobileOperationsService(client: client);
    await expectLater(
      service.eventAction(eventId, '../staff'),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 400),
      ),
    );
    await expectLater(
      service.caseDetail('../users/me'),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 400),
      ),
    );
    expect(calls, 0);
  });

  test(
    'malformed data and failed creation remain errors without automatic replay',
    () async {
      var calls = 0;
      final client = ApiClient(
        storage: _Tokens(),
        transport: MockClient((request) async {
          calls++;
          if (request.method == 'GET') return http.Response('{}', 200);
          return http.Response(
            jsonEncode({'detail': 'Context is required'}),
            400,
          );
        }),
      );
      addTearDown(client.dispose);
      final service = MobileOperationsService(client: client);
      await expectLater(
        service.cases(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            502,
          ),
        ),
      );
      await expectLater(
        service.createCase({'subject': 'Help'}),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Context is required',
          ),
        ),
      );
      expect(calls, 2);
    },
  );

  testWidgets(
    'a failed support request keeps the entered subject and message',
    (tester) async {
      final previous = ApiClient.instance;
      var creates = 0;
      final client = ApiClient(
        baseUrl: 'https://fixture.invalid/api/v1',
        storage: _Tokens(),
        transport: MockClient((request) async {
          if (request.method == 'GET') return http.Response('[]', 200);
          creates++;
          return http.Response(
            jsonEncode({'detail': 'Please check the request context'}),
            400,
          );
        }),
      );
      ApiClient.instance = client;
      addTearDown(() {
        ApiClient.instance = previous;
        client.dispose();
      });
      await tester.pumpWidget(
        const MaterialApp(home: MobileSupportPage(eventId: eventId)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New request'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Entry assistance',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Please help me find the entrance.',
      );
      await tester.ensureVisible(find.text('Send request'));
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(creates, 1);
      expect(find.text('Entry assistance'), findsOneWidget);
      expect(find.text('Please help me find the entrance.'), findsOneWidget);
      expect(find.text('Please check the request context'), findsOneWidget);
    },
  );
}

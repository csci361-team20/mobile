import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ticketapp/api_client.dart';
import 'package:ticketapp/checkin_service.dart';

import 'api_client_test.dart' show MemoryTokens;

const eventId = '287ba5f0-41da-45f8-8b87-7d22e9983d23';
const ticketId = '4f26d826-7d3b-46d7-b21f-3c6e60c4fe68';

void main() {
  test('assigned events union own, managed and checkin-only records without duplicates', () async {
    final client = ApiClient(
      storage: MemoryTokens('access'),
      transport: MockClient((request) async {
        final staff = request.url.queryParameters['role'] == 'checkin_staff';
        return http.Response(
          jsonEncode(
            staff
                ? [
                    {
                      'id': eventId,
                      'my_role': 'checkin_staff',
                      'start_at': '2026-12-01T10:00:00Z',
                    },
                    {
                      'id': ticketId,
                      'my_role': 'support_staff',
                      'start_at': '2026-12-01T10:00:00Z',
                    },
                  ]
                : [
                    {
                      'id': eventId,
                      'my_role': 'owner',
                      'start_at': '2026-12-01T10:00:00Z',
                    },
                  ],
          ),
          200,
        );
      }),
    );
    expect(
      (await CheckinService(
        client: client,
      ).assignedEvents()).map((row) => row['id']),
      [eventId],
    );
    client.dispose();
  });

  test('campaign links and raw identifiers are refused before any admission request', () async {
    var calls = 0;
    final client = ApiClient(
      storage: MemoryTokens('access'),
      transport: MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    final service = CheckinService(client: client);
    for (final input in [
      'https://biletflow.test/events/1?promo=test',
      ticketId,
      'BFT1.invalid',
      '',
    ]) {
      await expectLater(
        service.scan(eventId, input),
        throwsA(isA<ApiException>()),
      );
    }
    expect(calls, 0);
    client.dispose();
  });

  test('scan and undo retain exact credential, event context, admission state and reason', () async {
    final calls = <http.Request>[];
    final client = ApiClient(
      storage: MemoryTokens('access'),
      transport: MockClient((request) async {
        calls.add(request);
        return http.Response(
          '{"result":"valid","admitted":true,"message":"Admitted","ticket":{"id":"$ticketId","status":"checked_in"}}',
          200,
        );
      }),
    );
    final service = CheckinService(client: client);
    final result = await service.scan(eventId, 'BFT1.opaque-secret.signature');
    expect(result['admitted'], true);
    expect(calls.first.url.path, '/api/v1/events/$eventId/check-in/scan');
    expect(jsonDecode(calls.first.body), {
      'qr_payload': 'BFT1.opaque-secret.signature',
    });
    await service.undo(eventId, ticketId, '  Accidental scan  ');
    expect(
      calls.last.url.path,
      '/api/v1/events/$eventId/check-in/tickets/$ticketId/undo',
    );
    expect(jsonDecode(calls.last.body), {'reason': 'Accidental scan'});
    await expectLater(
      service.undo(eventId, ticketId, 'no'),
      throwsA(isA<ApiException>()),
    );
    expect(calls.length, 2);
    client.dispose();
  });
}

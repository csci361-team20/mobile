import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ticketapp/api_client.dart';
import 'package:ticketapp/auth_token_storage.dart';
import 'package:ticketapp/current_user.dart';
import 'package:ticketapp/homepage.dart';

class _Tokens implements TokenStore {
  @override
  Future<String?> accessToken() async => 'access-token';
  @override
  Future<String?> refreshToken() async => 'refresh-token';
  @override
  Future<void> clear() async {}
  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {}
}

void main() {
  late ApiClient previous;
  late MockClient transport;
  setUp(() => previous = ApiClient.instance);
  tearDown(() {
    ApiClient.instance = previous;
    transport.close();
  });

  testWidgets(
    'managed events come from the API and manager cancellation remains hidden',
    (tester) async {
      const eventId = '287ba5f0-41da-45f8-8b87-7d22e9983d23';
      final event = <String, dynamic>{
        'id': eventId,
        'title': 'Real managed event',
        'status': 'draft',
        'lifecycle': 'upcoming',
        'my_role': 'manager',
        'capacity': 100,
        'start_at': '2027-01-01T14:00:00Z',
        'end_at': '2027-01-01T16:00:00Z',
        'seating_type': 'general_admission',
      };
      final calls = <String>[];
      transport = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        final Object payload;
        if (request.url.path.endsWith('/events/mine')) {
          payload = [event];
        } else if (request.url.path.endsWith('/ticket-types')) {
          payload = [];
        } else if (request.url.path.endsWith('/publish')) {
          payload = {...event, 'status': 'published'};
        } else {
          return http.Response('{"detail":"Unexpected test request"}', 404);
        }
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiClient.instance = ApiClient(
        transport: transport,
        storage: _Tokens(),
        baseUrl: 'https://fixture.invalid/api/v1',
      );
      final user = CurrentUser(
        id: 'user',
        email: 'manager@example.com',
        fullName: 'Event Manager',
        createdAt: DateTime(2026),
        isEmailVerified: true,
        isPlatformAdmin: false,
        preferredLanguage: 'en',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizersTab(user: user, onRefresh: () async => user),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Real managed event'), findsOneWidget);
      expect(find.text('Astana Jazz Night'), findsNothing);
      await tester.tap(find.text('Real managed event'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel event'), findsNothing);
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(calls, contains('POST /api/v1/events/$eventId/publish'));
      expect(find.text('Unpublish'), findsOneWidget);
    },
  );

  testWidgets('ticket details render the exact backend QR payload', (
    tester,
  ) async {
    const payload = 'BF1.signed-ticket-payload';
    transport = MockClient(
      (request) async => http.Response(
        jsonEncode([
          {
            'id': 'ticket-1',
            'order_id': 'order-1',
            'status': 'valid',
            'event': {
              'title': 'Real ticket show',
              'start_at': '2030-12-01T14:00:00Z',
              'venue_name': 'Arena',
              'city': 'Almaty',
            },
            'ticket_type_name': 'General',
            'attendee_name': 'Dulat',
            'attendee_email': 'dulat@example.com',
            'qr_payload': payload,
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    ApiClient.instance = ApiClient(
      transport: transport,
      storage: _Tokens(),
      baseUrl: 'https://fixture.invalid/api/v1',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TicketsTab(accessToken: 'legacy')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Real ticket show'));
    await tester.pumpAndSettle();
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.size, 220);
    expect(qr.backgroundColor, Colors.white);
    expect(find.text('ticket-1'), findsOneWidget);
  });
}

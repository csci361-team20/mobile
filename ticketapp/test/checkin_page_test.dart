import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticketapp/checkin_page.dart';
import 'package:ticketapp/checkin_service.dart';

const eventId = '00000000-0000-4000-8000-000000000001';
const ticketId = '00000000-0000-4000-8000-000000000002';

class FakeCheckinService extends CheckinService {
  int scanCalls = 0;
  int verifyCalls = 0;
  int statsCalls = 0;
  int historyCalls = 0;
  int admitCalls = 0;
  int undoCalls = 0;
  String? undoReason;
  String lastQuery = '';
  Future<Map<String, dynamic>> Function()? scanAction;
  String result = 'already_used';
  bool published = true;

  Map<String, dynamic> response(String value) => {
    'result': value,
    'admitted': false,
    'message': 'Canonical server response: $value',
    'ticket': value == 'wrong_event' || value == 'invalid'
        ? null
        : {
            'id': ticketId,
            'attendee_name': 'Әлия Ғалымқызы',
            'ticket_type_name': 'Standard',
            'status': value == 'already_used' ? 'checked_in' : value,
            'checked_in_at': value == 'already_used'
                ? DateTime.now().toUtc().toIso8601String()
                : null,
            'checked_in_by_name': 'Door team',
            'seat': 'A12',
          },
  };

  @override
  Future<List<Map<String, dynamic>>> assignedEvents() async => [
    {
      'id': eventId,
      'title': 'Almaty concert',
      'start_at': '2026-12-10T14:00:00Z',
      'venue_name': 'Republic Palace',
      'my_role': 'checkin_staff',
      'status': published ? 'published' : 'cancelled',
    },
  ];

  @override
  Future<Map<String, dynamic>> stats(String eventId) async {
    statsCalls++;
    return {
      'event_id': eventId,
      'registered': 12,
      'checked_in': 3,
      'remaining': 9,
      'checked_in_percent': 25,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> attendees(
    String eventId, {
    String query = '',
  }) async {
    lastQuery = query;
    return query.isEmpty
        ? []
        : [
            {
              'ticket_id': ticketId,
              'attendee_name': 'Әлия Ғалымқызы',
              'attendee_email': 'aliya@example.com',
              'ticket_type_name': 'Standard',
              'status': 'valid',
              'seat': 'A12',
            },
          ];
  }

  @override
  Future<List<Map<String, dynamic>>> history(String eventId) async {
    historyCalls++;
    return [];
  }

  @override
  Future<Map<String, dynamic>> scan(String eventId, String qrPayload) {
    scanCalls++;
    return scanAction?.call() ?? Future.value(response(result));
  }

  @override
  Future<Map<String, dynamic>> verify(String eventId, String qrPayload) async {
    verifyCalls++;
    return response(result);
  }

  @override
  Future<Map<String, dynamic>> admit(String eventId, String ticketId) async {
    admitCalls++;
    return response('already_used');
  }

  @override
  Future<void> undo(String eventId, String ticketId, String reason) async {
    undoCalls++;
    undoReason = reason;
  }
}

Future<void> openEvent(WidgetTester tester, FakeCheckinService service) async {
  tester.view.physicalSize = const Size(420, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: CheckinPage(service: service)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('checkin-event-$eventId')));
  await tester.pumpAndSettle();
}

Future<void> submitQr(WidgetTester tester, String payload) async {
  await tester.enterText(find.byKey(const ValueKey('qr-payload')), payload);
  await tester.ensureVisible(find.byKey(const ValueKey('submit-qr')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('submit-qr')));
  await tester.pump();
}

void main() {
  for (final pair in [
    ('cancelled', 'Cancelled ticket'),
    ('refunded', 'Refunded ticket'),
    ('invalid', 'Invalid code'),
  ]) {
    testWidgets('server ${pair.$1} result cannot show admission success', (
      tester,
    ) async {
      final service = FakeCheckinService()..result = pair.$1;
      await openEvent(tester, service);
      await submitQr(tester, 'BFT1.opaque.signature');
      await tester.pumpAndSettle();
      expect(find.text(pair.$2), findsOneWidget);
      expect(find.text('Admission confirmed'), findsNothing);
      expect(service.admitCalls, 0);
    });
  }

  testWidgets('a confirmed admission can be undone with a mandatory reason', (
    tester,
  ) async {
    final service = FakeCheckinService();
    service.scanAction = () async => {
      ...service.response('already_used'),
      'result': 'valid',
      'admitted': true,
    };
    await openEvent(tester, service);
    await submitQr(tester, 'BFT1.opaque.signature');
    await tester.pumpAndSettle();
    expect(find.text('Admission confirmed'), findsOneWidget);
    await tester.ensureVisible(find.text('Undo check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm undo'));
    await tester.pumpAndSettle();
    expect(service.undoCalls, 0);
    expect(find.text('Use 3 to 500 characters.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('undo-reason')),
      'Accidental admission',
    );
    await tester.tap(find.text('Confirm undo'));
    await tester.pumpAndSettle();
    expect(service.undoCalls, 1);
    expect(service.undoReason, 'Accidental admission');
    expect(
      find.text('Check-in undone. The server record has been updated.'),
      findsOneWidget,
    );
    expect(find.text('Admission confirmed'), findsNothing);
  });

  testWidgets('promotional links never reach verification or admission', (
    tester,
  ) async {
    final service = FakeCheckinService();
    await openEvent(tester, service);
    await submitQr(tester, 'https://biletflow.example/campaign/summer');
    expect(
      find.text(
        'This is a web or promotional link, not a ticket QR code. Ask for the attendee ticket.',
      ),
      findsOneWidget,
    );
    expect(service.scanCalls, 0);
    expect(service.verifyCalls, 0);
    expect(service.admitCalls, 0);
  });

  testWidgets(
    'one scan stays in flight and server already-used result does not admit again',
    (tester) async {
      final service = FakeCheckinService();
      final pending = Completer<Map<String, dynamic>>();
      service.scanAction = () => pending.future;
      await openEvent(tester, service);
      await submitQr(tester, 'BFT1.opaque.signature');
      await tester.tap(find.byKey(const ValueKey('submit-qr')));
      await tester.pump();
      expect(service.scanCalls, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('submit-qr')))
            .onPressed,
        isNull,
      );
      pending.complete(service.response('already_used'));
      await tester.pumpAndSettle();
      expect(find.text('Already checked in'), findsOneWidget);
      expect(find.text('Admission confirmed'), findsNothing);
      expect(find.text('Әлия Ғалымқызы'), findsOneWidget);
      expect(service.admitCalls, 0);
    },
  );

  testWidgets(
    'unknown write outcome blocks retries until explicit server reconciliation',
    (tester) async {
      final service = FakeCheckinService();
      service.scanAction = () async => throw TimeoutException('Response lost');
      await openEvent(tester, service);
      await submitQr(tester, 'BFT1.opaque.signature');
      await tester.pumpAndSettle();
      expect(find.text('Result unknown'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('submit-qr')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Reconcile server records'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reconcile server records'));
      await tester.pumpAndSettle();
      expect(service.scanCalls, 1);
      expect(service.verifyCalls, 1);
      expect(service.statsCalls, 2);
      expect(service.historyCalls, 2);
      expect(find.text('Already checked in'), findsOneWidget);
      expect(find.text('Admission confirmed'), findsNothing);
    },
  );

  testWidgets('wrong-event scan exposes no attendee and no success state', (
    tester,
  ) async {
    final service = FakeCheckinService()..result = 'wrong_event';
    await openEvent(tester, service);
    await submitQr(tester, 'BFT1.foreign.signature');
    await tester.pumpAndSettle();
    expect(find.text('Wrong event'), findsOneWidget);
    expect(find.text('Әлия Ғалымқызы'), findsNothing);
    expect(find.text('Admission confirmed'), findsNothing);
  });

  testWidgets(
    'manual search uses the server query and canonical attendee result',
    (tester) async {
      final service = FakeCheckinService();
      await openEvent(tester, service);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Attendees'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('attendee-search')),
        'Әлия',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(service.lastQuery, 'Әлия');
      expect(find.text('Әлия Ғалымқызы'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Check in'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
      await tester.pumpAndSettle();
      expect(service.admitCalls, 1);
      expect(find.text('Already checked in'), findsOneWidget);
    },
  );

  testWidgets(
    'cancelled event keeps server records readable and disables admission',
    (tester) async {
      final service = FakeCheckinService()..published = false;
      await openEvent(tester, service);
      expect(
        find.text('Check-in is available only while this event is published.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('start-camera')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('submit-qr')))
            .onPressed,
        isNull,
      );
      expect(find.text('12'), findsOneWidget);
      expect(service.scanCalls, 0);
    },
  );

  testWidgets('Kazakh labels follow the selected application locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('kk'),
        supportedLocales: const [Locale('en'), Locale('kk'), Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: CheckinPage(service: FakeCheckinService()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Кіруді тіркеу'), findsOneWidget);
    expect(find.text('Тағайындалған іс-шаралар'), findsOneWidget);
  });
}

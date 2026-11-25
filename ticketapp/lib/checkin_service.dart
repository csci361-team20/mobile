import 'api_client.dart';

class CheckinService {
  final ApiClient client;

  CheckinService({ApiClient? client}) : client = client ?? ApiClient.instance;

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List || value.any((row) => row is! Map<String, dynamic>)) {
      throw const ApiException(502, 'The server returned an invalid list.');
    }
    return value.cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const ApiException(502, 'The server returned an invalid result.');
    }
    return value;
  }

  String _id(String id) {
    if (!RegExp(
      r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
    ).hasMatch(id)) {
      throw const ApiException(400, 'Choose a valid event or ticket.');
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> assignedEvents() async {
    final lists = await Future.wait([
      client.get('/events/mine'),
      client.get('/events/mine', query: {'role': 'checkin_staff'}),
    ]);
    final records = <String, Map<String, dynamic>>{};
    for (final data in lists) {
      for (final event in _list(data)) {
        if (event['id'] is String &&
            ['owner', 'manager', 'checkin_staff'].contains(event['my_role'])) {
          records[event['id'] as String] = event;
        }
      }
    }
    return records.values.toList()..sort(
      (a, b) => a['start_at'].toString().compareTo(b['start_at'].toString()),
    );
  }

  Future<List<Map<String, dynamic>>> attendees(
    String eventId, {
    String query = '',
  }) async => _list(
    await client.get(
      '/events/${_id(eventId)}/attendees',
      query: query.trim().isEmpty ? null : {'q': query.trim()},
    ),
  );

  Future<Map<String, dynamic>> stats(String eventId) async =>
      _map(await client.get('/events/${_id(eventId)}/check-in/stats'));

  Future<Map<String, dynamic>> _qr(
    String eventId,
    String payload,
    String action,
  ) async {
    if (!RegExp(r'^BFT1\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$').hasMatch(payload) ||
        payload.length > 500) {
      throw const ApiException(
        400,
        'Use an admission ticket QR code. Event links and campaign QR codes cannot admit a guest.',
      );
    }
    return _map(
      await client.post(
        '/events/${_id(eventId)}/check-in/$action',
        body: {'qr_payload': payload},
      ),
    );
  }

  Future<Map<String, dynamic>> verify(String eventId, String qrPayload) =>
      _qr(eventId, qrPayload, 'verify');
  Future<Map<String, dynamic>> scan(String eventId, String qrPayload) =>
      _qr(eventId, qrPayload, 'scan');
  Future<Map<String, dynamic>> admit(String eventId, String ticketId) async =>
      _map(
        await client.post(
          '/events/${_id(eventId)}/check-in/tickets/${_id(ticketId)}',
        ),
      );
  Future<void> undo(String eventId, String ticketId, String reason) async {
    final text = reason.trim();
    if (text.length < 3 || text.length > 500) {
      throw const ApiException(
        400,
        'Use 3–500 characters to explain the reversal.',
      );
    }
    await client.post(
      '/events/${_id(eventId)}/check-in/tickets/${_id(ticketId)}/undo',
      body: {'reason': text},
    );
  }

  Future<List<Map<String, dynamic>>> history(String eventId) async =>
      _list(await client.get('/events/${_id(eventId)}/check-in/history'));

  Future<String?> get currentUserId async =>
      client.currentUserId ?? (await client.currentUser())['id'] as String?;
}

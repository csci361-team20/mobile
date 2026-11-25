import 'api_client.dart';

class MobileOperationsService {
  final ApiClient client;

  MobileOperationsService({ApiClient? client})
    : client = client ?? ApiClient.instance;

  Map<String, dynamic> _map(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const ApiException(502, 'The server returned an invalid record.');
    }
    return value;
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List || value.any((item) => item is! Map<String, dynamic>)) {
      throw const ApiException(502, 'The server returned an invalid list.');
    }
    return value.cast<Map<String, dynamic>>();
  }

  String _id(String value) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw const ApiException(400, 'Choose a valid record.');
    }
    return value.toLowerCase();
  }

  Future<List<Map<String, dynamic>>> managedEvents() async =>
      _list(await client.get('/events/mine'));

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> body) async {
    final payload = Map<String, dynamic>.from(body)
      ..remove('organizer_profile_id');
    return _map(await client.post('/events/', body: payload));
  }

  Future<Map<String, dynamic>> updateEvent(
    String id,
    Map<String, dynamic> body,
  ) async => _map(await client.patch('/events/${_id(id)}', body: body));

  Future<Map<String, dynamic>> eventAction(String id, String action) async {
    if (!['publish', 'unpublish', 'cancel', 'duplicate'].contains(action)) {
      throw const ApiException(400, 'Choose a supported event action.');
    }
    return _map(await client.post('/events/${_id(id)}/$action'));
  }

  Future<List<Map<String, dynamic>>> ticketTypes(String eventId) async => _list(
    await client.get(
      '/events/${_id(eventId)}/ticket-types',
      query: {'include_hidden': 'true'},
    ),
  );

  Future<Map<String, dynamic>> createTicketType(
    String eventId,
    Map<String, dynamic> body,
  ) async => _map(
    await client.post('/events/${_id(eventId)}/ticket-types', body: body),
  );

  Future<Map<String, dynamic>> ownOrganizer() async =>
      _map(await client.get('/organizers/me'));

  Future<Map<String, dynamic>> createOrganizer(String name) async => _map(
    await client.post('/organizers/', body: {'display_name': name.trim()}),
  );

  Future<List<Map<String, dynamic>>> cases({String scope = 'all'}) async =>
      _list(await client.get('/support/cases', query: {'scope': scope}));

  Future<Map<String, dynamic>> createCase(Map<String, dynamic> body) async =>
      _map(await client.post('/support/cases', body: body));

  Future<Map<String, dynamic>> caseDetail(String id) async =>
      _map(await client.get('/support/cases/${_id(id)}'));

  Future<Map<String, dynamic>> reply(String id, String text) async => _map(
    await client.post(
      '/support/cases/${_id(id)}/messages',
      body: {'body': text.trim()},
    ),
  );

  Future<Map<String, dynamic>> updateCase(
    String id,
    Map<String, dynamic> body,
  ) async => _map(await client.patch('/support/cases/${_id(id)}', body: body));

  Future<List<Map<String, dynamic>>> caseAssignees(String id) async =>
      _list(await client.get('/support/cases/${_id(id)}/assignees'));

  Future<Map<String, dynamic>> escalateCase(String id, String reason) async =>
      _map(
        await client.post(
          '/support/cases/${_id(id)}/escalate',
          body: {'reason': reason.trim()},
        ),
      );

  Future<List<Map<String, dynamic>>> myOrders() async =>
      _list(await client.get('/orders/mine'));

  Future<List<Map<String, dynamic>>> publicEvents() async => _list(
    await client.get('/events/', query: {'limit': '200'}, authenticated: false),
  );
}

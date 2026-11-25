import 'api_client.dart';
import 'event_model.dart';
import 'ticket_model.dart';
import 'ticket_type_model.dart';

class EventService {
  final ApiClient client;

  EventService({ApiClient? client}) : client = client ?? ApiClient.instance;

  Future<List<ApiEvent>> fetchEvents() async {
    final events = <ApiEvent>[];
    var skip = 0;
    while (true) {
      final data = await client.get(
        '/events/',
        query: {'skip': '$skip', 'limit': '100'},
        authenticated: false,
      );
      if (data is! List) {
        throw const ApiException(502, 'The event list is invalid.');
      }
      events.addAll(
        data.map((item) => ApiEvent.fromJson(item as Map<String, dynamic>)),
      );
      if (data.length < 100) break;
      skip += data.length;
      if (skip >= 1000) break;
    }
    return events;
  }

  Future<List<TicketType>> fetchTicketTypes(String eventId) async {
    final data = await client.get(
      '/events/${Uri.encodeComponent(eventId)}/ticket-types',
    );
    if (data is! List) {
      throw const ApiException(502, 'The ticket type list is invalid.');
    }
    return data
        .map((item) => TicketType.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> createOrder({
    required String eventId,
    required String ticketTypeId,
    required int quantity,
    required String accessToken,
  }) async {
    if (quantity < 1 || quantity > 50) {
      throw const ApiException(400, 'Choose 1–50 tickets.');
    }
    return Map<String, dynamic>.from(
      await client.post(
        '/events/${Uri.encodeComponent(eventId)}/orders',
        body: {
          'items': [
            {'ticket_type_id': ticketTypeId, 'quantity': quantity},
          ],
        },
      ) as Map,
    );
  }

  Future<Map<String, dynamic>> payOrder({
    required String orderId,
    required String accessToken,
  }) async => Map<String, dynamic>.from(
    await client.post(
      '/orders/${Uri.encodeComponent(orderId)}/pay',
      body: {'outcome': 'success'},
    ) as Map,
  );

  Future<List<ApiTicket>> fetchMyTickets(String accessToken) async {
    final data = await client.get('/tickets/mine');
    if (data is! List) {
      throw const ApiException(502, 'The ticket list is invalid.');
    }
    return data
        .map((item) => ApiTicket.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

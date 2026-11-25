
import 'dart:convert';
import 'ticket_type_model.dart';
import 'package:http/http.dart' as http;

import 'ticket_model.dart';
import 'event_model.dart';

class EventService {
  static const String _baseUrl =
      'https://biletflow-api.vercel.app/api/v1';

  Future<List<ApiEvent>> fetchEvents() async {
    final uri = Uri.parse('$_baseUrl/events/');

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception(
          'Event download failed: ${response.statusCode}',
        );
      }

      final List<dynamic> data =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;

      return data
          .map(
            (event) => ApiEvent.fromJson(
              event as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      throw Exception('Event download error: $e');
    }
  }
  
Future<List<TicketType>> fetchTicketTypes(String eventId) async {
  final uri = Uri.parse('$_baseUrl/events/$eventId/ticket-types');

  try {
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load ticket types: ${response.statusCode}',
      );
    }

    final List<dynamic> data =
        jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;

    return data
        .map(
          (item) => TicketType.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  } catch (e) {
    throw Exception('Error loading ticket types: $e');
  }
}

Future<Map<String, dynamic>> createOrder({
  required String eventId,
  required String ticketTypeId,
  required int quantity,
  required String accessToken,
}) async {
  final uri = Uri.parse('$_baseUrl/events/$eventId/orders');

  final response = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
    body: jsonEncode({
      'items': [
        {
          'ticket_type_id': ticketTypeId,
          'quantity': quantity,
        }
      ],
    }),
  );

  if (response.statusCode != 201) {
    throw Exception(
      'Failed to create order: ${response.statusCode} ${response.body}',
    );
  }

  return jsonDecode(
    utf8.decode(response.bodyBytes),
  ) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> payOrder({
  required String orderId,
  required String accessToken,
}) async {
  final uri = Uri.parse('$_baseUrl/orders/$orderId/pay');

  final response = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
    body: jsonEncode({
      'outcome': 'success',
    }),
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Payment failed: ${response.statusCode} ${response.body}',
    );
  }

  return jsonDecode(
    utf8.decode(response.bodyBytes),
  ) as Map<String, dynamic>;
}

Future<List<ApiTicket>> fetchMyTickets(String accessToken) async {
  final uri = Uri.parse('$_baseUrl/tickets/mine');

  final response = await http.get(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
    },
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Failed to load tickets: ${response.statusCode} ${response.body}',
    );
  }

  final List<dynamic> data = jsonDecode(
    utf8.decode(response.bodyBytes),
  ) as List<dynamic>;

  return data
      .map(
        (item) => ApiTicket.fromJson(
          item as Map<String, dynamic>,
        ),
      )
      .toList();
}

}

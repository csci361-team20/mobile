
class ApiTicket {
  final String id;
  final String orderId;
  final String status;
  final String eventTitle;
  final DateTime eventStartAt;
  final String venueName;
  final String city;
  final String ticketTypeName;
  final String attendeeName;
  final String attendeeEmail;
  final String? qrPayload;

  ApiTicket({
    required this.id,
    required this.orderId,
    required this.status,
    required this.eventTitle,
    required this.eventStartAt,
    required this.venueName,
    required this.city,
    required this.ticketTypeName,
    required this.attendeeName,
    required this.attendeeEmail,
    this.qrPayload,
  });

  factory ApiTicket.fromJson(Map<String, dynamic> json) {
    final event = json['event'] as Map<String, dynamic>;

    return ApiTicket(
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      status: json['status']?.toString() ?? '',
      eventTitle: event['title']?.toString() ?? '',
      eventStartAt: DateTime.parse(
        event['start_at'].toString(),
      ).toLocal(),
      venueName: event['venue_name']?.toString() ?? '',
      city: event['city']?.toString() ?? '',
      ticketTypeName: json['ticket_type_name']?.toString() ?? '',
      attendeeName: json['attendee_name']?.toString() ?? '',
      attendeeEmail: json['attendee_email']?.toString() ?? '',
      qrPayload: json['qr_payload']?.toString(),
    );
  }
}

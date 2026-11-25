
class TicketType {
  final String id;
  final String eventId;
  final String name;
  final String? description;
  final int priceKzt;
  final int available;
  final int maxPerOrder;
  final String saleStatus;

  TicketType({
    required this.id,
    required this.eventId,
    required this.name,
    this.description,
    required this.priceKzt,
    required this.available,
    required this.maxPerOrder,
    required this.saleStatus,
  });

  factory TicketType.fromJson(Map<String, dynamic> json) {
    return TicketType(
      id: json['id'].toString(),
      eventId: json['event_id'].toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      priceKzt: (json['price_kzt'] as num?)?.toInt() ?? 0,
      available: (json['available'] as num?)?.toInt() ?? 0,
      maxPerOrder: (json['max_per_order'] as num?)?.toInt() ?? 1,
      saleStatus: json['sale_status']?.toString() ?? '',
    );
  }

  bool get isAvailable => saleStatus == 'on_sale' && available > 0;

  bool get isFree => priceKzt == 0;
}

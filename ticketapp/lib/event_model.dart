
class ApiEvent {
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? coverImageUrl;
  final DateTime startAt;
  final String venueName;
  final String city;
  final String category;
  final int priceFromKzt;
  final int ticketsAvailable;
  final String saleState;

  ApiEvent({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    this.coverImageUrl,
    required this.startAt,
    required this.venueName,
    required this.city,
    required this.category,
    required this.priceFromKzt,
    required this.ticketsAvailable,
    required this.saleState,
  });

  factory ApiEvent.fromJson(Map<String, dynamic> json) {
    return ApiEvent(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      coverImageUrl: json['cover_image_url']?.toString(),
      startAt: DateTime.parse(json['start_at'].toString()).toLocal(),
      venueName: json['venue_name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      priceFromKzt: (json['price_from_kzt'] as num?)?.toInt() ?? 0,
      ticketsAvailable: (json['tickets_available'] as num?)?.toInt() ?? 0,
      saleState: json['sale_state']?.toString() ?? '',
    );
  }
}

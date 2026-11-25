import 'api_client.dart';

class CurrentUser {
  final String id;
  final String email;
  final String fullName;
  final DateTime createdAt;
  final bool isEmailVerified;
  final bool isPlatformAdmin;
  final String preferredLanguage; // kk / ru / en

  CurrentUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.createdAt,
    required this.isEmailVerified,
    required this.isPlatformAdmin,
    required this.preferredLanguage,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'].toString(),
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      isPlatformAdmin: json['is_platform_admin'] as bool? ?? false,
      preferredLanguage: json['preferred_language'] as String? ?? 'en',
    );
  }
}

Future<CurrentUser> fetchCurrentUser(String accessToken) async {
  return CurrentUser.fromJson(await ApiClient.instance.currentUser());
}

class UnauthorizedException implements Exception {
  @override
  String toString() => 'Session expired';
}

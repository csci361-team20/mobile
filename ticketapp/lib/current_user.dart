import 'dart:convert';

import 'package:http/http.dart' as http;

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
  final response = await http.get(
    Uri.parse('https://biletflow-api.vercel.app/api/v1/users/me'),
    headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
  );
    if (response.statusCode == 401) throw UnauthorizedException();

  if (response.statusCode != 200) {
    throw Exception('Failed to load profile (${response.statusCode})');
  }

  final data = jsonDecode(utf8.decode(response.bodyBytes))
      as Map<String, dynamic>;

  return CurrentUser.fromJson(data);
}

class UnauthorizedException implements Exception {
  @override
  String toString() => 'Session expired';
}
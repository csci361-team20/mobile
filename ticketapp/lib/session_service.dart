import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_token_storage.dart';

Future<String?> refreshSession() async {
  final storage = AuthTokenStorage();
  final refreshToken = await storage.refreshToken();
  if (refreshToken == null) return null;

  final response = await http.post(
    Uri.parse('https://biletflow-api.vercel.app/api/v1/auth/refresh'),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({'refresh_token': refreshToken}),
  );

  if (response.statusCode != 200) return null;

  final data =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

  final newAccess = data['access_token'] as String?;
  final newRefresh = data['refresh_token'] as String? ?? refreshToken;

  if (newAccess == null) return null;

  await storage.save(accessToken: newAccess, refreshToken: newRefresh);
  return newAccess;
}
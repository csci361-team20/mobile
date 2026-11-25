import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_token_storage.dart';

Future<void> logoutSession() async {
  final storage = AuthTokenStorage();
  final refresh = await storage.refreshToken(); // читаем ДО очистки

  try {
    if (refresh != null) {
      await http.post(
        Uri.parse('https://biletflow-api.vercel.app/api/v1/auth/logout-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refresh}),
      );
    }
  } catch (_) {
  } finally {
    await storage.clear();
  }
}
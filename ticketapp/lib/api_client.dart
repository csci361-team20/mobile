import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_token_storage.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static ApiClient instance = ApiClient();
  static const defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://biletflow-api.vercel.app/api/v1',
  );

  final http.Client _transport;
  final TokenStore _storage;
  final String baseUrl;
  final Duration timeout;
  final ValueNotifier<bool> authenticated = ValueNotifier(false);
  Future<String?>? _refreshing;
  Map<String, dynamic>? _user;
  int _generation = 0;

  ApiClient({
    http.Client? transport,
    TokenStore? storage,
    String? baseUrl,
    this.timeout = const Duration(seconds: 15),
  }) : _transport = transport ?? http.Client(),
       _storage = storage ?? AuthTokenStorage(),
       baseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(RegExp(r'/+$'), '');

  String? get currentUserId => _user?['id'] as String?;

  void _checkGeneration(int generation) {
    if (generation != _generation) {
      throw const ApiException(
        401,
        'The account session changed. Sign in again.',
      );
    }
  }

  int _changeGeneration() {
    _refreshing = null;
    return ++_generation;
  }

  Uri _uri(String path, Map<String, String>? query) {
    final base = Uri.parse(baseUrl);
    if (!['http', 'https'].contains(base.scheme) ||
        base.host.isEmpty ||
        !path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains('..') ||
        path.contains('?') ||
        path.contains('#')) {
      throw const ApiException(400, 'Invalid API address.');
    }
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    String? token,
    bool form = false,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      if (form) {
        request.bodyFields = Map<String, String>.from(body as Map);
      } else {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
    }
    try {
      return await (() async {
        final streamed = await _transport.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        0,
        method == 'GET' ? 'The server took too long to respond. Try again.' : 'The request outcome is unknown. Check the saved records before trying again.',
      );
    } on http.ClientException {
      throw ApiException(
        0,
        method == 'GET'
            ? 'Could not connect. Check your internet connection and try again.'
            : 'The request could not be confirmed. Check the saved records before trying again.',
      );
    }
  }

  dynamic _decode(http.Response response) {
    dynamic data;
    if (response.bodyBytes.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        if (response.statusCode < 400) {
          throw const ApiException(
            502,
            'The server returned an unreadable response.',
          );
        }
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    if (response.statusCode >= 500) {
      throw ApiException(
        response.statusCode,
        'The server is unavailable. Please try again later.',
      );
    }
    final detail = data is Map ? data['detail'] : null;
    String message;
    if (detail is String && detail.isNotEmpty) {
      message = detail;
    } else if (detail is List) {
      message = detail
          .whereType<Map>()
          .map((item) {
            final location = item['loc'];
            final field = location is List
                ? location
                      .where((v) => v != 'body')
                      .join(' ')
                      .replaceAll('_', ' ')
                : '';
            return '${field.isEmpty ? '' : '$field: '}${item['msg'] ?? 'Invalid value'}';
          })
          .join('. ');
    } else {
      message = response.statusCode == 401
          ? 'Your session expired. Sign in again.'
          : response.statusCode == 403
          ? 'You are not allowed to perform this action.'
          : 'The request could not be completed (${response.statusCode}).';
    }
    throw ApiException(response.statusCode, message);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    final generation = _generation;
    final token = authenticated ? await _storage.accessToken() : null;
    if (authenticated) _checkGeneration(generation);
    var response = await _send(
      method,
      path,
      body: body,
      query: query,
      token: token,
    );
    if (authenticated) _checkGeneration(generation);
    if (authenticated &&
        response.statusCode == 401 &&
        generation == _generation) {
      final current = await _storage.accessToken();
      _checkGeneration(generation);
      final renewed = current != null && current != token
          ? current
          : await refresh();
      _checkGeneration(generation);
      if (renewed != null && generation == _generation) {
        response = await _send(
          method,
          path,
          body: body,
          query: query,
          token: renewed,
        );
      }
      if (response.statusCode == 401 && generation == _generation) {
        await clearSession();
      }
    }
    if (authenticated) _checkGeneration(generation);
    return _decode(response);
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) => _request('GET', path, query: query, authenticated: authenticated);
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _request('POST', path, body: body, authenticated: authenticated);
  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _request('PATCH', path, body: body, authenticated: authenticated);
  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _request('DELETE', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final generation = _changeGeneration();
    final response = await _send(
      'POST',
      '/auth/login',
      body: {'username': email.trim(), 'password': password},
      form: true,
    );
    _checkGeneration(generation);
    final tokens = _tokens(_decode(response));
    await _storage.save(accessToken: tokens.$1, refreshToken: tokens.$2);
    _checkGeneration(generation);
    _user = null;
    final user = await currentUser();
    _checkGeneration(generation);
    return user;
  }

  (String, String) _tokens(dynamic data) {
    if (data is! Map ||
        data['access_token'] is! String ||
        data['refresh_token'] is! String ||
        (data['access_token'] as String).isEmpty ||
        (data['refresh_token'] as String).isEmpty ||
        data['token_type']?.toString().toLowerCase() != 'bearer') {
      throw const ApiException(502, 'The server returned an invalid session.');
    }
    return (data['access_token'] as String, data['refresh_token'] as String);
  }

  Future<String?> refresh() async {
    if (_refreshing != null) return _refreshing;
    final task = _renew(_generation);
    _refreshing = task;
    try {
      return await task;
    } finally {
      if (identical(_refreshing, task)) _refreshing = null;
    }
  }

  Future<String?> _renew(int generation) async {
    final token = await _storage.refreshToken();
    if (generation != _generation) return null;
    if (token == null || token.isEmpty) return null;
    final response = await _send(
      'POST',
      '/auth/refresh',
      body: {'refresh_token': token},
    );
    if (generation != _generation) return null;
    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearSession();
      return null;
    }
    final tokens = _tokens(_decode(response));
    if (generation != _generation) return null;
    await _storage.save(accessToken: tokens.$1, refreshToken: tokens.$2);
    if (generation != _generation) return null;
    authenticated.value = true;
    return tokens.$1;
  }

  Future<Map<String, dynamic>> currentUser() async {
    final generation = _generation;
    final data = await get('/users/me');
    _checkGeneration(generation);
    if (data is! Map<String, dynamic> || data['id'] is! String) {
      throw const ApiException(502, 'The account response is invalid.');
    }
    _user = data;
    authenticated.value = true;
    _checkGeneration(generation);
    return data;
  }

  Future<void> clearSession() async {
    _changeGeneration();
    _user = null;
    authenticated.value = false;
    await _storage.clear();
  }

  Future<void> logout() async {
    final generation = _generation;
    final refreshToken = await _storage.refreshToken();
    if (generation != _generation) return;
    await clearSession();
    if (refreshToken == null) return;
    try {
      _decode(
        await _send(
          'POST',
          '/auth/logout-session',
          body: {'refresh_token': refreshToken},
        ),
      );
    } on ApiException {
      return;
    }
  }

  void dispose() {
    _transport.close();
    authenticated.dispose();
  }
}

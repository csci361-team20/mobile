import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStore {
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  });
  Future<String?> accessToken();
  Future<String?> refreshToken();
  Future<void> clear();
}

class AuthTokenStorage implements TokenStore {
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static Future<void> _pending = Future.value();

  Future<void> _write(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _write(() async {
      await _storage.write(key: _refreshKey, value: refreshToken);
      await _storage.write(key: _accessKey, value: accessToken);
    });
  }

  @override
  Future<String?> accessToken() async {
    await _pending;
    return _storage.read(key: _accessKey);
  }

  @override
  Future<String?> refreshToken() async {
    await _pending;
    return _storage.read(key: _refreshKey);
  }

  @override
  Future<void> clear() => _write(() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  });
}

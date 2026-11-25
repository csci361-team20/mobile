import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ticketapp/api_client.dart';
import 'package:ticketapp/auth_token_storage.dart';

class MemoryTokens implements TokenStore {
  String? access;
  String? refresh;
  MemoryTokens([this.access, this.refresh]);
  @override
  Future<String?> accessToken() async => access;
  @override
  Future<String?> refreshToken() async => refresh;
  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

class DelayedAccessTokens extends MemoryTokens {
  final int pauseAt;
  final started = Completer<void>();
  final result = Completer<String?>();
  int reads = 0;

  DelayedAccessTokens(this.pauseAt) : super('account-a', 'refresh-a');

  @override
  Future<String?> accessToken() async {
    if (++reads == pauseAt) {
      started.complete();
      return result.future;
    }
    return super.accessToken();
  }
}

class DelayedSaveTokens extends MemoryTokens {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await super.save(accessToken: accessToken, refreshToken: refreshToken);
    started.complete();
    await release.future;
  }
}

class DelayedRefreshTokens extends MemoryTokens {
  final started = Completer<void>();
  final result = Completer<String?>();

  DelayedRefreshTokens() : super('account-a', 'refresh-a');

  @override
  Future<String?> refreshToken() async {
    started.complete();
    return result.future;
  }
}

http.Response json(dynamic body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('login uses OAuth form, stores both tokens, and loads the canonical identity', () async {
    final storage = MemoryTokens();
    final client = ApiClient(
      baseUrl: 'https://fixture.test/api/v1',
      storage: storage,
      transport: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          expect(
            request.headers['content-type'],
            contains('application/x-www-form-urlencoded'),
          );
          expect(request.bodyFields, {
            'username': 'dulat@example.test',
            'password': 'not-a-real-password&=',
          });
          return json({
            'access_token': 'access-new',
            'refresh_token': 'refresh-new',
            'token_type': 'bearer',
          });
        }
        expect(request.url.path, '/api/v1/users/me');
        expect(request.headers['Authorization'], 'Bearer access-new');
        return json({'id': 'account-id', 'full_name': 'Dulat'});
      }),
    );
    expect(
      (await client.login(
        ' dulat@example.test ',
        'not-a-real-password&=',
      ))['id'],
      'account-id',
    );
    expect(storage.access, 'access-new');
    expect(storage.refresh, 'refresh-new');
    expect(client.currentUserId, 'account-id');
    client.dispose();
  });

  test(
    'concurrent unauthorized reads share one refresh and use the renewed token',
    () async {
      final storage = MemoryTokens('expired', 'refresh-old');
      var refreshes = 0;
      final client = ApiClient(
        storage: storage,
        transport: MockClient((request) async {
          if (request.url.path.endsWith('/refresh')) {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return json({
              'access_token': 'access-new',
              'refresh_token': 'refresh-new',
              'token_type': 'bearer',
            });
          }
          return request.headers['Authorization'] == 'Bearer access-new'
              ? json([])
              : json({'detail': 'Expired'}, 401);
        }),
      );
      await Future.wait([
        client.get('/events/mine'),
        client.get('/tickets/mine'),
      ]);
      expect(refreshes, 1);
      expect(storage.refresh, 'refresh-new');
      client.dispose();
    },
  );

  test('network/server write failures are never replayed', () async {
    var calls = 0;
    final client = ApiClient(
      storage: MemoryTokens('valid'),
      transport: MockClient((request) async {
        calls++;
        return http.Response('<html>secret server context</html>', 503);
      }),
    );
    await expectLater(
      client.post('/events/event/check-in/scan', body: {'qr_payload': 'test'}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 503)
            .having(
              (e) => e.message,
              'safe message',
              isNot(contains('secret')),
            ),
      ),
    );
    expect(calls, 1);
    client.dispose();
  });

  test(
    'logout clears local credentials even when revocation is unreachable',
    () async {
      final storage = MemoryTokens('valid', 'refresh');
      final client = ApiClient(
        storage: storage,
        transport: MockClient(
          (request) async => throw http.ClientException('offline'),
        ),
      );
      await client.logout();
      expect(storage.access, isNull);
      expect(storage.refresh, isNull);
      expect(client.authenticated.value, false);
      client.dispose();
    },
  );

  test('a late refresh cannot resurrect a signed-out session', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final storage = MemoryTokens('old', 'refresh-old');
    final client = ApiClient(
      storage: storage,
      transport: MockClient((request) async {
        started.complete();
        return response.future;
      }),
    );
    final renewing = client.refresh();
    await started.future;
    await client.clearSession();
    response.complete(
      json({
        'access_token': 'late-access',
        'refresh_token': 'late-refresh',
        'token_type': 'bearer',
      }),
    );
    expect(await renewing, isNull);
    expect(storage.access, isNull);
    expect(client.authenticated.value, false);
    client.dispose();
  });

  test('validation errors omit submitted values and invalid refresh tokens clear identity', () async {
    final storage = MemoryTokens('old', 'invalid');
    final client = ApiClient(
      storage: storage,
      transport: MockClient(
        (request) async => json({'detail': 'Expired'}, 401),
      ),
    );
    await expectLater(
      client.get('/users/me'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(storage.refresh, isNull);
    client.dispose();
    final validationClient = ApiClient(
      storage: MemoryTokens(),
      transport: MockClient(
        (request) async => json({
          'detail': [
            {
              'loc': ['body', 'password'],
              'msg': 'Too short',
              'input': 'super-secret',
            },
          ],
        }, 422),
      ),
    );
    await expectLater(
      validationClient.post(
        '/users/',
        body: {'password': 'super-secret'},
        authenticated: false,
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'safe message',
          'password: Too short',
        ),
      ),
    );
    validationClient.dispose();
  });

  for (final pauseAt in [1, 2]) {
    test(
      'account switching during credential read $pauseAt cannot send or replay an old-screen write',
      () async {
        final storage = DelayedAccessTokens(pauseAt);
        var writes = 0;
        final client = ApiClient(
          storage: storage,
          transport: MockClient((request) async {
            if (request.url.path.endsWith('/auth/login')) {
              return json({
                'access_token': 'account-b',
                'refresh_token': 'refresh-b',
                'token_type': 'bearer',
              });
            }
            if (request.url.path.endsWith('/users/me')) {
              return json({'id': 'user-b'});
            }
            writes++;
            return json({'detail': 'Expired'}, 401);
          }),
        );
        addTearDown(client.dispose);
        final request = client.post(
          '/events/',
          body: {'title': 'Old screen draft'},
        );
        final failure = expectLater(
          request,
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'status',
              401,
            ),
          ),
        );
        await storage.started.future;
        await client.clearSession();
        await client.login('b@example.test', 'password-b');
        storage.result.complete(pauseAt == 1 ? 'account-b' : 'account-a');
        await failure;
        expect(writes, pauseAt == 1 ? 0 : 1);
        expect(storage.access, 'account-b');
        expect(client.currentUserId, 'user-b');
        expect(client.authenticated.value, isTrue);
      },
    );
  }

  test(
    'a previous-account refresh is never reused by the next account',
    () async {
      final oldResponse = Completer<http.Response>();
      final newResponse = Completer<http.Response>();
      final oldStarted = Completer<void>();
      final newStarted = Completer<void>();
      final storage = MemoryTokens('account-a', 'refresh-a');
      final client = ApiClient(
        storage: storage,
        transport: MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return json({
              'access_token': 'account-b',
              'refresh_token': 'refresh-b',
              'token_type': 'bearer',
            });
          }
          if (request.url.path.endsWith('/users/me')) {
            return json({'id': 'user-b'});
          }
          if (request.url.path.endsWith('/auth/refresh')) {
            final token = jsonDecode(request.body)['refresh_token'];
            if (token == 'refresh-a') {
              oldStarted.complete();
              return oldResponse.future;
            }
            expect(token, 'refresh-b');
            newStarted.complete();
            return newResponse.future;
          }
          return request.headers['Authorization'] == 'Bearer renewed-b'
              ? json([])
              : json({'detail': 'Expired'}, 401);
        }),
      );
      addTearDown(client.dispose);
      final oldRefresh = client.refresh();
      await oldStarted.future;
      await client.login('b@example.test', 'password-b');
      final newRead = client.get('/events/mine');
      await newStarted.future.timeout(const Duration(seconds: 2));
      oldResponse.complete(json({'detail': 'Expired old session'}, 401));
      expect(await oldRefresh, isNull);
      newResponse.complete(
        json({
          'access_token': 'renewed-b',
          'refresh_token': 'renewed-refresh-b',
          'token_type': 'bearer',
        }),
      );
      expect(await newRead, isEmpty);
      expect(storage.access, 'renewed-b');
      expect(storage.refresh, 'renewed-refresh-b');
      expect(client.currentUserId, 'user-b');
      expect(client.authenticated.value, isTrue);
    },
  );

  test(
    'a sign-in waiting for secure storage cannot restore a signed-out identity',
    () async {
      final storage = DelayedSaveTokens();
      var profileReads = 0;
      final client = ApiClient(
        storage: storage,
        transport: MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return json({
              'access_token': 'late-access',
              'refresh_token': 'late-refresh',
              'token_type': 'bearer',
            });
          }
          profileReads++;
          return json({'id': 'late-user'});
        }),
      );
      addTearDown(client.dispose);
      final login = client.login('a@example.test', 'password-a');
      final failure = expectLater(
        login,
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
      await storage.started.future;
      await client.clearSession();
      storage.release.complete();
      await failure;
      expect(profileReads, 0);
      expect(storage.access, isNull);
      expect(client.currentUserId, isNull);
      expect(client.authenticated.value, isFalse);
    },
  );

  test('a delayed sign-out cannot clear a newer account', () async {
    final storage = DelayedRefreshTokens();
    var revocations = 0;
    final client = ApiClient(
      storage: storage,
      transport: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return json({
            'access_token': 'account-b',
            'refresh_token': 'refresh-b',
            'token_type': 'bearer',
          });
        }
        if (request.url.path.endsWith('/users/me')) {
          return json({'id': 'user-b'});
        }
        revocations++;
        return http.Response('', 204);
      }),
    );
    addTearDown(client.dispose);
    final leaving = client.logout();
    await storage.started.future;
    await client.login('b@example.test', 'password-b');
    storage.result.complete('refresh-a');
    await leaving;
    expect(revocations, 0);
    expect(storage.access, 'account-b');
    expect(client.currentUserId, 'user-b');
    expect(client.authenticated.value, isTrue);
  });

  test('sign-out triggered when identity loads cannot leave a successful stale profile result', () async {
    final client = ApiClient(
      storage: MemoryTokens('account-a'),
      transport: MockClient((_) async => json({'id': 'user-a'})),
    );
    addTearDown(client.dispose);
    Future<void>? leaving;
    client.authenticated.addListener(() {
      if (client.authenticated.value) leaving = client.clearSession();
    });
    await expectLater(
      client.currentUser(),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 401),
      ),
    );
    await leaving;
    expect(client.currentUserId, isNull);
    expect(client.authenticated.value, isFalse);
  });
}
